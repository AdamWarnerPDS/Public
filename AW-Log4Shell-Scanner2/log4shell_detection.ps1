param (
    [string]$search_root = "",
    [string]$output_filepath = "",
    [string]$log_filepath = ""
)

# Constants

# set to $false to disable loggin
$LOGGING = $true

#
# String Functions
#

function Escape-JSON($s) {
  return $s.replace('\','\\').replace('"','\"')
}

function Escape-FilePath($s) {
  return $s -replace "[^a-zA-Z0-9.-]", "_"
}

#
# IMPORTS, PARAMs
#

# clear all errors, add compression
$error.Clear()
Add-Type -AssemblyName "System.IO.Compression"

# globals
$scan_ts = $(Get-Date -format 'o')
$hostname = [System.Net.Dns]::GetHostName()
$vulnerable_java_apps = @()
$unreadable_java_apps = @()
$Mutex = New-Object System.Threading.Mutex

# default output_path and validate 
if (!$output_filepath) {
  $output_filepath = "log4shell_detection.output.$(Escape-FilePath $hostname).$(Escape-FilePath $scan_ts).json"
}
if (Test-Path $output_filepath) {
  Write-Output "ERROR: output file exists. Please delete $output_filepath or specify an alternate output filepath."
  exit 0
}

# default log_path and validate 
if (!$log_filepath) {
  $log_filepath = $output_filepath -replace "\.json$", ".log"
}
if (Test-Path $log_filepath) {
  Write-Output "ERROR: log file exists. Please delete $log_filepath or specify an alternate log filepath."
  exit 0
}

# default search_root, ensure it is an array
if ($search_root) {
  $search_roots = @($search_root)
} else {
  $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object {$_.DriveType -eq 'Fixed' } | Select-Object RootDirectory
  $search_root = ($drives | Select-Object -ExpandProperty RootDirectory)
  $search_roots = @($drives | Select-Object -ExpandProperty RootDirectory)
}
$search_root_escaped = Escape-JSON "$search_root"

#
# Functions
#

function Write-Log($Level, $Message) {
  if ($LOGGING) {
    $Temp = "{0} - {1} - {2}" -f $(Get-Date -format 'o'), $Level, $Message
    try {
      while(!$script:Mutex.WaitOne()) {
        Start-Sleep -m 100
      }
      try {
        $Temp | Out-File $log_filepath -Append
      } finally {
        $script:Mutex.ReleaseMutex()
      }
    } catch {
      Write-Warning $("Failed to write message {0} to log file: {1}" -f $Temp, $_.Exception.Message)
    }
  }
}

function Check-Archive {
  param (
    [String]$Path=$(throw "Mandatory parameter -Path"),
    [System.IO.Stream]$Stream=$(throw "Mandatory parameter -Stream")
  )
  Write-Log 'INFO' "checking $Path"
  $Archive = New-Object System.IO.Compression.ZipArchive $Stream
  try {
    # iterate over jar contents
    $found_jndilookup_class = $false
    $found_patched_indicator = $false
    foreach ($Entry in $Archive.Entries) {
      if ($Entry.Name -eq "JndiLookup.class") {
        # jar contains JndiLookup.class which is the source of vulnerabilitiess
        $found_jndilookup_class = $true
      } elseif ($Entry.Name -eq "JndiManager.class") {
        # read JndiManager.class and search for log4j2.enableJndi
        try {
          $reader = New-Object System.IO.StreamReader $Entry.Open()
          $found_patched_indicator = $($reader.ReadToEnd() | Select-String -Pattern "log4j2.enableJndi" -Quiet) -eq $True
        } catch {
          $script:unreadable_java_apps += $Path
          Write-Log 'WARN' $("failed to read: {0}!{1}: {2}" -f $Path, $Entry.Name, $_.Exception.Message)
        } finally {
          # Need the checks since we don't know where the try statements might fail
          if ($reader){
              $reader.Close()
          }
        }
      } elseif ($Entry.Name -match "\.(war|ear|jar)$") {
        # nested .war/ear/jar, recurse inside this entry
        Check-Archive -Path $("{0}!{1}" -f $Path, $Entry.Name) -Stream $Entry.Open()
      }
    }
    # is jar vulnerable?
    if ($found_jndilookup_class -and ($found_patched_indicator -eq $null -or !$found_patched_indicator)) {
      Write-Log 'WARN' $("Vulnerable JAR: {0}" -f $Path)
      $script:vulnerable_java_apps += $Path
    }
  } catch {
    $script:unreadable_java_apps += $Path
    Write-Log 'WARN' $("failed to read {0}: {1}" -f $Path, $_.Exception.Message)
  } finally {
    $Stream.Close()
    if ($Archive) {
      $Archive.Dispose()
    }
  }
}

#
# Write Header
#

Write-Output  @"
------------------------------------------------------------------------------
Log4Shell (CVE-2021-44228, CVE-2021-45046) Vulnerability Detection Script v0.2
------------------------------------------------------------------------------
This script searches the system for Java applications that contain the Log4J
class JndiLookup.class which is the source of the Log4Shell vulnerabilities. If
this class is found within an application, the script looks for updates to the
to Log4J that indicate the application has been updated to use Log4J 2.16+ or
Log4J 2.12.2+. If the application contains JndiLookup.class but does not appear
to have been updated, the application is vulnerable.

For additional information and usage please see the readme.txt.
------------------------------------------------------------------------------

Finding all JAR files under $search_roots and scanning each.
This can take several minutes. Ctrl-c to abort.

"@

#
# SCAN search_roots and analyze jars
#

try {
  # log start
  Write-Log 'INFO' "scanning $search_roots on $hostname"
  Write-Log 'INFO' "Powershell Version: $($PSVersionTable.PSVersion.ToString())"
  Write-Log 'INFO' "Windows $([System.Environment]::OSVersion.Version.ToString())"

  # iterate across search roots, calling Check-Archive for each java app
  $search_roots | 
  ForEach-Object {Get-ChildItem -Path $_ -ErrorAction SilentlyContinue -Force -Recurse} | 
  Where-Object {!$_.PSIsContainer -and $_.extension -in (".jar",".war",".ear") } | 
  ForEach-Object {
    # we found a jar/war/ear, let's check it!
    try {
      $Path = $_.FullName
      $Stream = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open)
      Check-Archive -Path $Path -Stream $Stream
    } catch {
      if (-Not ($Path -match '\\\$Recycle\.Bin\\')) {
        $script:unreadable_java_apps += $Path
        Write-Log 'WARN' $("failed to read {0}: {1}" -f $Path, $_.Exception.Message)
      }
    }
  }
} catch {
  Write-Log 'ERROR' $_
  Write-Output $_
  Write-Output "Result: ERROR"  
  exit 1
}

#
# Output Results
#

if ($vulnerable_java_apps.Length -gt 0) {
  # fail

  Write-Log 'INFO' 'Result: FAIL'
  Write-Output @"

Result: FAIL
The following Java applications contain Log4j JndiLookup, do not appear to have
been updated to Log4J 2.16+ or Log4J 2.12.2+, and are likely subject to 
Log4Shell (CVE-2021-44228, CVE-2021-45046).

"@    

  $i = 0
  $json_string = "["
  foreach ($jndi_jar in $vulnerable_java_apps) {
      $i += 1
      Write-Output "- $jndi_jar"
      $jndi_jar_escaped = Escape-JSON $jndi_jar
      $json_string += "`n  { `"hostname`":`"$hostname`", `"scan_ts`":`"$scan_ts`", `"scan_v`":`"0.2`", `"search_root`":`"$search_root_escaped`", `"result`":`"FAIL`", `"vulnerable_jar`":`"$jndi_jar_escaped`" }"
      if ($i -lt $vulnerable_java_apps.length) {
          $json_string += ','
      }
  }

  if ($unreadable_java_apps) {
    Write-Output "`nWARNING`nThe following applications were not readable by this detection script:`n"
    $json_string += ','
    $i = 0
    foreach ($unreadable_jar in $unreadable_java_apps) {
      $i += 1
      Write-Output "- $unreadable_jar"
      $unreadable_jar_escaped = Escape-JSON $unreadable_jar
      $json_string += "`n  { `"hostname`":`"$hostname`", `"scan_ts`":`"$scan_ts`", `"scan_v`":`"0.2`", `"search_root`":`"$search_root_escaped`", `"result`":`"UNKNOWN`", `"unscanned_jar`":`"$unreadable_jar_escaped`" }"
      if ($i -lt $unreadable_java_apps.length) {
          $json_string += ','
      }
    }
  }

  $json_string += "`n]"
  $json_string | Out-File "$output_filepath"

  Write-Output ""
  Write-Output "For remediation steps, contact the vendor of each affected application."
  exit 1

} elseif ($unreadable_java_apps) {
  Write-Log 'INFO' 'Result: UNKNOWN'
  Write-Output @"
Result: UNKNOWN
No Java applications containing unpatched Log4j were found, but the following
applications were not readable by this detection script:

"@

  $i = 0
  $json_string = "["
  foreach ($unreadable_jar in $unreadable_java_apps) {
    $i += 1
    Write-Output "- $unreadable_jar"
    $unreadable_jar_escaped = Escape-JSON $unreadable_jar
    $json_string += "`n  { `"hostname`":`"$hostname`", `"scan_ts`":`"$scan_ts`", `"scan_v`":`"0.2`", `"search_root`":`"$search_root_escaped`", `"result`":`"UNKNOWN`", `"unscanned_jar`":`"$unreadable_jar_escaped`" }"
    if ($i -lt $unreadable_java_apps.length) {
        $json_string += ','
    }
  }
  $json_string += "`n]"
  $json_string | Out-File "$output_filepath"

  exit 1
} else {
  Write-Log 'INFO' 'Result: PASS'
  Write-Output @"

Result: PASS
No Java applications containing unpatched Log4j were found.

"@

  "[`n  { `"hostname`":`"$hostname`", `"scan_ts`":`"$scan_ts`", `"scan_v`":`"0.2`", `"search_root`":`"$search_root_escaped`", `"result`":`"PASS`", `"vulnerable_jar`":false } `n]" | Out-File "$output_filepath"

  if ($unreadable_java_apps) {
    Write-Output "WARNING`nThe following applications were not readable by this detection script:`n`n"
    foreach ($unreadable_jar in $unreadable_java_apps) {
      Write-Output "- $unreadable_jar"
    }
  }
  exit 0
}

# SIG # Begin signature block
# MIIdcQYJKoZIhvcNAQcCoIIdYjCCHV4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAJ5NVJOdqKWNP/
# N9VXZ6zgunTGZHDTbm0pt49sirm4B6CCF+0wggT+MIID5qADAgECAhANQkrgvjqI
# /2BAIc4UAPDdMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNV
# BAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0EwHhcN
# MjEwMTAxMDAwMDAwWhcNMzEwMTA2MDAwMDAwWjBIMQswCQYDVQQGEwJVUzEXMBUG
# A1UEChMORGlnaUNlcnQsIEluYy4xIDAeBgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFt
# cCAyMDIxMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwuZhhGfFivUN
# CKRFymNrUdc6EUK9CnV1TZS0DFC1JhD+HchvkWsMlucaXEjvROW/m2HNFZFiWrj/
# ZwucY/02aoH6KfjdK3CF3gIY83htvH35x20JPb5qdofpir34hF0edsnkxnZ2OlPR
# 0dNaNo/Go+EvGzq3YdZz7E5tM4p8XUUtS7FQ5kE6N1aG3JMjjfdQJehk5t3Tjy9X
# tYcg6w6OLNUj2vRNeEbjA4MxKUpcDDGKSoyIxfcwWvkUrxVfbENJCf0mI1P2jWPo
# GqtbsR0wwptpgrTb/FZUvB+hh6u+elsKIC9LCcmVp42y+tZji06lchzun3oBc/gZ
# 1v4NSYS9AQIDAQABo4IBuDCCAbQwDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQC
# MAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwQQYDVR0gBDowODA2BglghkgBhv1s
# BwEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5jb20vQ1BTMB8G
# A1UdIwQYMBaAFPS24SAd/imu0uRhpbKiJbLIFzVuMB0GA1UdDgQWBBQ2RIaOpLqw
# Zr68KC0dRDbd42p6vDBxBgNVHR8EajBoMDKgMKAuhixodHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vc2hhMi1hc3N1cmVkLXRzLmNybDAyoDCgLoYsaHR0cDovL2NybDQu
# ZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC10cy5jcmwwgYUGCCsGAQUFBwEBBHkw
# dzAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME8GCCsGAQUF
# BzAChkNodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEyQXNz
# dXJlZElEVGltZXN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3DQEBCwUAA4IBAQBIHNy1
# 6ZojvOca5yAOjmdG/UJyUXQKI0ejq5LSJcRwWb4UoOUngaVNFBUZB3nw0QTDhtk7
# vf5EAmZN7WmkD/a4cM9i6PVRSnh5Nnont/PnUp+Tp+1DnnvntN1BIon7h6JGA078
# 9P63ZHdjXyNSaYOC+hpT7ZDMjaEXcw3082U5cEvznNZ6e9oMvD0y0BvL9WH8dQgA
# dryBDvjA4VzPxBFy5xtkSdgimnUVQvUtMjiB2vRgorq0Uvtc4GEkJU+y38kpqHND
# Udq9Y9YfW5v3LhtPEx33Sg1xfpe39D+E68Hjo0mh+s6nv1bPull2YYlffqe0jmd4
# +TaY4cso2luHpoovMIIFMTCCBBmgAwIBAgIQCqEl1tYyG35B5AXaNpfCFTANBgkq
# hkiG9w0BAQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
# MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBB
# c3N1cmVkIElEIFJvb3QgQ0EwHhcNMTYwMTA3MTIwMDAwWhcNMzEwMTA3MTIwMDAw
# WjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQL
# ExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3Vy
# ZWQgSUQgVGltZXN0YW1waW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAvdAy7kvNj3/dqbqCmcU5VChXtiNKxA4HRTNREH3Q+X1NaH7ntqD0jbOI
# 5Je/YyGQmL8TvFfTw+F+CNZqFAA49y4eO+7MpvYyWf5fZT/gm+vjRkcGGlV+Cyd+
# wKL1oODeIj8O/36V+/OjuiI+GKwR5PCZA207hXwJ0+5dyJoLVOOoCXFr4M8iEA91
# z3FyTgqt30A6XLdR4aF5FMZNJCMwXbzsPGBqrC8HzP3w6kfZiFBe/WZuVmEnKYmE
# UeaC50ZQ/ZQqLKfkdT66mA+Ef58xFNat1fJky3seBdCEGXIX8RcG7z3N1k3vBkL9
# olMqT4UdxB08r8/arBD13ays6Vb/kwIDAQABo4IBzjCCAcowHQYDVR0OBBYEFPS2
# 4SAd/imu0uRhpbKiJbLIFzVuMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3z
# bcgPMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8E
# ejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMFAGA1UdIARJMEcwOAYKYIZIAYb9
# bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAQEAcZUS6VGHVmnN793afKpj
# erN4zwY3QITvS4S/ys8DAv3Fp8MOIEIsr3fzKx8MIVoqtwU0HWqumfgnoma/Capg
# 33akOpMP+LLR2HwZYuhegiUexLoceywh4tZbLBQ1QwRostt1AuByx5jWPGTlH0gQ
# GF+JOGFNYkYkh2OMkVIsrymJ5Xgf1gsUpYDXEkdws3XVk4WTfraSZ/tTYYmo9WuW
# wPRYaQ18yAGxuSh1t5ljhSKMYcp5lH5Z/IwP42+1ASa2bKXuh1Eh5Fhgm7oMLStt
# osR+u8QlK0cCCHxJrhO24XxCQijGGFbPQTS2Zl22dHv1VjMiLyI2skuiSpXY9aaO
# UjCCBrAwggSYoAMCAQICEAitQLJg0pxMn17Nqb2TrtkwDQYJKoZIhvcNAQEMBQAw
# YjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290
# IEc0MB4XDTIxMDQyOTAwMDAwMFoXDTM2MDQyODIzNTk1OVowaTELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBU
# cnVzdGVkIEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENBMTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANW0L0LQKK14t13VOVkbsYhC
# 9TOM6z2Bl3DFu8SFJjCfpI5o2Fz16zQkB+FLT9N4Q/QX1x7a+dLVZxpSTw6hV/yI
# mcGRzIEDPk1wJGSzjeIIfTR9TIBXEmtDmpnyxTsf8u/LR1oTpkyzASAl8xDTi7L7
# CPCK4J0JwGWn+piASTWHPVEZ6JAheEUuoZ8s4RjCGszF7pNJcEIyj/vG6hzzZWiR
# ok1MghFIUmjeEL0UV13oGBNlxX+yT4UsSKRWhDXW+S6cqgAV0Tf+GgaUwnzI6hsy
# 5srC9KejAw50pa85tqtgEuPo1rn3MeHcreQYoNjBI0dHs6EPbqOrbZgGgxu3amct
# 0r1EGpIQgY+wOwnXx5syWsL/amBUi0nBk+3htFzgb+sm+YzVsvk4EObqzpH1vtP7
# b5NhNFy8k0UogzYqZihfsHPOiyYlBrKD1Fz2FRlM7WLgXjPy6OjsCqewAyuRsjZ5
# vvetCB51pmXMu+NIUPN3kRr+21CiRshhWJj1fAIWPIMorTmG7NS3DVPQ+EfmdTCN
# 7DCTdhSmW0tddGFNPxKRdt6/WMtyEClB8NXFbSZ2aBFBE1ia3CYrAfSJTVnbeM+B
# Sj5AR1/JgVBzhRAjIVlgimRUwcwhGug4GXxmHM14OEUwmU//Y09Mu6oNCFNBfFg9
# R7P6tuyMMgkCzGw8DFYRAgMBAAGjggFZMIIBVTASBgNVHRMBAf8ECDAGAQH/AgEA
# MB0GA1UdDgQWBBRoN+Drtjv4XxGG+/5hewiIZfROQjAfBgNVHSMEGDAWgBTs1+OC
# 0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5k
# aWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSG
# Mmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQu
# Y3JsMBwGA1UdIAQVMBMwBwYFZ4EMAQMwCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUA
# A4ICAQA6I0Q9jQh27o+8OpnTVuACGqX4SDTzLLbmdGb3lHKxAMqvbDAnExKekESf
# S/2eo3wm1Te8Ol1IbZXVP0n0J7sWgUVQ/Zy9toXgdn43ccsi91qqkM/1k2rj6yDR
# 1VB5iJqKisG2vaFIGH7c2IAaERkYzWGZgVb2yeN258TkG19D+D6U/3Y5PZ7Umc9K
# 3SjrXyahlVhI1Rr+1yc//ZDRdobdHLBgXPMNqO7giaG9OeE4Ttpuuzad++UhU1rD
# yulq8aI+20O4M8hPOBSSmfXdzlRt2V0CFB9AM3wD4pWywiF1c1LLRtjENByipUuN
# zW92NyyFPxrOJukYvpAHsEN/lYgggnDwzMrv/Sk1XB+JOFX3N4qLCaHLC+kxGv8u
# GVw5ceG+nKcKBtYmZ7eS5k5f3nqsSc8upHSSrds8pJyGH+PBVhsrI/+PteqIe3Br
# 5qC6/To/RabE6BaRUotBwEiES5ZNq0RA443wFSjO7fEYVgcqLxDEDAhkPDOPriiM
# PMuPiAsNvzv0zh57ju+168u38HcT5ucoP6wSrqUvImxB+YJcFWbMbA7KxYbD9iYz
# DAdLoNMHAmpqQDBISzSoUSC7rRuFCOJZDW3KBVAr6kocnqX9oKcfBnTn8tZSkP2v
# hUgh+Vc7tJwD7YZF9LRhbr9o4iZghurIr6n+lB3nYxs6hlZ4TjCCBv4wggTmoAMC
# AQICEA2phvsCpuIeAnZlyV6O+GcwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBU
# cnVzdGVkIEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENBMTAe
# Fw0yMTA5MTQwMDAwMDBaFw0yNDExMDYyMzU5NTlaMIGCMQswCQYDVQQGEwJVUzES
# MBAGA1UECBMJTWlubmVzb3RhMRUwEwYDVQQHEwxFZGVuIFByYWlyaWUxIzAhBgNV
# BAoTGkFyY3RpYyBXb2xmIE5ldHdvcmtzLCBJbmMuMSMwIQYDVQQDExpBcmN0aWMg
# V29sZiBOZXR3b3JrcywgSW5jLjCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoC
# ggGBAMY21ltx/5xqGjd26nmDcDMJTHxV/P5Eh+1U7RjOBlW6/WXxmy4OBwhBa6Nm
# 7KMunHm1fqdJRRt4c4M+Qp4webjozcvzYcykJrPYmZvEFEKHQB3LcMrRVZRUXwJ2
# 9QJF2u0zgTS7oCI6iFXC4pHXxod6ophjrxvK0sFy+f0A5u0GOxBKrtaSyKNFF+ke
# LUkmwAtKjgKdN/1B8sn54/mondoT28ajSwDtI/TdS06kk2GjOyUItyo0XDfpJgm/
# A9RLwhiQLqus4bK8SFCQhjpE63Ihe/QkUeejZIQtWgd1fL7Fal54szIox2bQcTU8
# 7mC6EMXBh4TFWbz6g8wY6nGNi0H+zbNPvvfhDZ91/EotEmUfKsX6N5AqJS5MywhI
# hQxxsuxvd2X3xaITZLA8EklffUaZjERzGvzgL+hPyua0g116DRVv5QWGkSODIXRw
# dnET6Bo4molSp29S2RoyeJDN6lk30tOy4sIaz/aoNm/J9r4q+oNNQmTaPOZgX616
# b+O0GQIDAQABo4ICBjCCAgIwHwYDVR0jBBgwFoAUaDfg67Y7+F8Rhvv+YXsIiGX0
# TkIwHQYDVR0OBBYEFIrAAgu2JHoyUnsN1YAaK/hDlKCMMA4GA1UdDwEB/wQEAwIH
# gDATBgNVHSUEDDAKBggrBgEFBQcDAzCBtQYDVR0fBIGtMIGqMFOgUaBPhk1odHRw
# Oi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmlu
# Z1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNybDBToFGgT4ZNaHR0cDovL2NybDQuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hB
# Mzg0MjAyMUNBMS5jcmwwPgYDVR0gBDcwNTAzBgZngQwBBAEwKTAnBggrBgEFBQcC
# ARYbaHR0cDovL3d3dy5kaWdpY2VydC5jb20vQ1BTMIGUBggrBgEFBQcBAQSBhzCB
# hDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFwGCCsGAQUF
# BzAChlBodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# RzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNydDAMBgNVHRMBAf8E
# AjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBG5FodwyAOpam8ej45BBDgFk1cEgn5GUjD
# w1Ed/aX/595q82bXA1AG2Was+ZCtHeechjssftVVmoygrffZo6yw9Zo4sIinSugv
# uK6fxlNbSEX0ZQy6TwGWnTWf+8BAdfarHrX7ZhycNG6FVN1Yq2l8buLM5J+XARX2
# JF675StUyNK3kkxMO4mfZ/hSarjmExJDUQlyKeb/6mV5hfG/SkGx25+xcOr1DHKZ
# EfstG3hgUWqwDiJRyrIIC2ifJ8THl6I+BPWbk9AK5vBVZnKzpSAHHs89NyV77hEQ
# PmOk185qIMrfZKc/mk4OiKeRfoyXLSZugrcXonaqjY0SqhJWiUqf8MgZJl8hkG3L
# 8F2THQqV88xdVr+pDEJNXmvLu4SgDbQ7HwJJ2LuL3Ped7obJWfJ1tHOAjh0ADVGz
# Exm13XqKmq4hJQjs7XuoxYaE/RuIlGsp441HOf/0tYpuqYE7eKfGmGQbcq/OEGXn
# GyM4jGZ9Zbfi14+2F7/cDhjxmoZB4YiI9mf0KULdEWXxhUbUG7in0fOY5oBB/VoN
# wjn2Kgax7kb802Jxq0urpVzYBD88AXUxFfRYROiW2cu9jfaBIh2Dh08mVeJor3c0
# j8Ha5g3ifP/KPqSyc+t8B/RyE62lb+SQJo8EsYXkd/CTJbZwOOiAWSqa38j/mCLB
# LKKDtac4+TGCBNowggTWAgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IENvZGUg
# U2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENBMQIQDamG+wKm4h4CdmXJXo74
# ZzANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJ
# AzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8G
# CSqGSIb3DQEJBDEiBCCLlp/+zjibcKv4URxBL0eLsHdmz+x2yWd6zFRx+6oJ6TAN
# BgkqhkiG9w0BAQEFAASCAYAi3QbK/xEiAUoTLxfkXjQMwNqztEFLpxyN0WQk36dQ
# MznVjaUqWmTC1kO8svW+4n8iZ7n7KrttCB6UkLU1fVYVDXv3WNiV+vN090YUZlJA
# 9hLs+qDPqvf/pe9z+diyR4EmdlCWxUHI+P7m/e3BlwVqIKu6DDnrjMmiVqphkzAg
# iYZ22ZlNlfcaoAViVJw7omMMb7dqq9WSM+Nhnd7Oc0yfTFPkDAfPQeqXkXJEQmHB
# r8ue0l4h6uQ8719vbtvJgPFAN506CE90BVe/j9UJcEmYvWTCkwBvIwlFtJJCtURS
# ddTkKVFdxEveP5ekFTfqmjkQZQRt1goZLKuJe50LqerM2i00JZipHlP+mu1gV8Hw
# T8dR3iNQLZWrTQU54mw0jtly1dEZhlxX7xwtPWRw8KgytvQ0B1i17uSpxkAXpV/I
# UlTNDxfy0/C0tqBdJQ9iouGhHTb0nzlpGYN7YDvLymBjRReo7E2n3izd0q0P7S1H
# 56R8FJefuxB21z2vCqP5IIihggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEw
# gYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UE
# CxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1
# cmVkIElEIFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgB
# ZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkF
# MQ8XDTIxMTIxNzE3MjExNlowLwYJKoZIhvcNAQkEMSIEIJqkXQzrJrwXAJNiDjf6
# Ektn/EsSBPJhQIds9oXhgRTeMA0GCSqGSIb3DQEBAQUABIIBAAKwIP/rBAFfOJeb
# CNUNP8B2JB8AQhA015Av9eKgRHOclWRMk4/8Mq46Po4F0gXcy77p/3l74aFFQZEw
# mmXvyS6n7kwG3JnHGN3lAkTdO848NoOyV/kb/VnOlPKRwv/v+3m8u401JkzQHSmM
# ++E8WtYI4R5mmCRr+wi1VHwpesOSfL8JP15CG3vNJFSN34JoMftCvgVwkzVp/wpR
# plrKL/kl1EHTGX4nQ83WicQH3f8SdqcDxbpidZurqwceE55uvKKKzTiW1M2YSdAs
# pVUk5wL+neUJtf9JEgkJSjCN/pWQflJmvhyZReoy8VEIpHh0ZHN7bs59RY4D5VbM
# +77yyIY=
# SIG # End signature block
