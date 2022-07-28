# These were previously in a param block    
    [string]$search_root = ""
    #[string]$output_filepath = "log4shell_detection.output.$(Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }).json"
    [string]$output_filename = "log4shell_detection.output.$(Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }).json"
    [string]$output_folder = "C:\temp"


function Get-AmpOutputVariableValues() {
    # Output vars for AMP
    # [int32]$ampOutVulJarsFound // 1 = found, 0 = none.  Thresholds Normal = 0, Failed = 1
    # $ampOutVulJarsPaths // string, No threshold, just print it; might be useful
    # $output_filepath // String, No thresholds, just print it
    Write-Host "`$ampOutVulJarsFound - $ampOutVulJarsFound"
    Write-Host "`$ampOutVulJarsPaths - $ampOutVulJarsPaths"
    Write-Host "`$output_filepath - $output_filepath"
}

$scan_ts = $(Get-Date -format 'o')
$hostname = [System.Net.Dns]::GetHostName()


# clear all errors
$error.Clear()
Add-Type -Assembly "System.IO.Compression.Filesystem"

Write-Output  ""
Write-Output  "------------------------------------------------------------------------------"
Write-Output  "Log4Shell (CVE-2021-44228) Vulnerable Application Detection Script"
Write-Output  "------------------------------------------------------------------------------"
Write-Output  "This script searches the system for Java applications that contain the Log4J"
Write-Output  "class JndiLookup.class which is the source of the Log4Shell vulnerability. If"
Write-Output  "this class is found within an application, the script looks for updates to the"
Write-Output  "JndiManager.class that indicate the application has been updated to use Log4J"
Write-Output  "2.15+. If the application contains JndiLookup.class but does not appear to"
Write-Output  "have been updated to use Log4J 2.15+, the application is vulnerable."
Write-Output  ""
Write-Output  "See https://nvd.nist.gov/vuln/detail/CVE-2021-44228 for additional details."
Write-Output  ""
Write-Output  "For usage please see the readme.txt."
Write-Output  "------------------------------------------------------------------------------"
Write-Output  ""

if ( $(Test-Path "$output_folder") -eq $false ){
    New-Item -ItenType "Directory" -Path "$output_folder"
}

$output_filepath = "$output_folder" + "`\" + $output_filename

# make sure output path doesn't exict
if (Test-Path $output_filepath) {
    Write-Output "ERROR: output file exists. Please delete $output_filepath or specify an alternate output file."
    exit 1
}

try {
    $vuln_jars_found = @()

    if ($search_root) {
      $start_paths = @($search_root)
    } else {
      $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object {$_.DriveType -eq 'Fixed' } | Select-Object RootDirectory
      $search_root = ($drives | Select-Object -ExpandProperty RootDirectory)
      $start_paths = @($drives | Select-Object -ExpandProperty RootDirectory)
    }
    $search_root_escaped = "$search_root".replace('\','\\').replace('"','\"')

    Write-Output "Finding all JAR files under $start_paths and scanning each."
    Write-Output "This can take several minutes. Ctrl-c to abort."
    Write-Output ""
    
    $start_paths | ForEach-Object {Get-ChildItem -Filter *.jar -Path $_ -ErrorAction SilentlyContinue -Force -Recurse} | Where-Object {!$_.PSIsContainer} | ForEach-Object{
      try {
        $jar_path = $_.FullName
        $jar = [io.compression.zipfile]::OpenRead($jar_path)

        $maybeVuln = $false
        $patched = $false
        foreach ($Entry in $jar.Entries) {
          if ($Entry.Name -eq "JndiLookup.class") {
            $maybeVuln = $true
          } elseif ($Entry.Name -eq "JndiManager.class") {
            try {
                $stream = $Entry.Open()
                $reader = New-Object IO.StreamReader($stream)
                $patched = $reader.ReadToEnd() | Select-String -Pattern "allowedJndiProtocols" -Quiet
            } catch {
                Write-Output $_
                Write-Output "Result: ERROR"
                exit 1
            } finally{
                # Need the checks since we don't know where the try statements might fail
                if ($reader){
                    $reader.Close()
                }
                if ($stream){
                    $stream.Close()
                }
                if ($jar){
                    $jar.Dispose()
                }
            }
          }
        }
        if ($maybeVuln -and !$patched) {
          $vuln_jars_found += $_.FullName
        }
      } catch {
        if (-Not ($jar_path -match '\\\$Recycle\.Bin\\')) {
          Write-Output "Warning: failed t$o read jar: $jar_path"
        }
      }

    }

    Write-Output ""
    if ($vuln_jars_found) {
        [int32]$ampOutVulJarsFound = 1
        [string]$ampOutVulJarsPaths = ($vuln_jars_found -join ';')
        Write-Output "Result: FAIL"
        Write-Output "The following Java applications contain Log4j JndiLookup, do not appear to have"
        Write-Output "been updated to Log4J 2.15+, and are likely subject to Log4Shell"
        Write-Output "(CVE-2021-44228)."
        Write-Output ""

        $i = 0
        $json_string = "["
        foreach ($jndi_jar in $vuln_jars_found) {
            $i += 1
            Write-Output "- $jndi_jar"
            $jndi_jar_escaped = $jndi_jar.replace('\','\\').replace('"','\"')
            $json_string += "`n  { `"hostname`":`"$hostname`", `"scan_ts`":`"$scan_ts`", `"search_root`":`"$search_root_escaped`", `"result`":`"FAIL`", `"vulnerable_jar`":`"$jndi_jar_escaped`" }"
            if ($i -lt $vuln_jars_found.length) {
                $json_string += ','
            }
        }
        $json_string += "`n]"
        $json_string | Out-File "$output_filepath"

        Write-Output ""
        Write-Output "For remediation steps, contact the vendor of each affected application."

        # ping result
        try {
            $ping_output = ping -n 1 asd.122021a.arcticwolf.com
        } catch {}

        Get-AmpOutputVariableValues
        exit 0
    } else {
        [int32]$ampOutVulJarsFoun = 0
        Write-Output "Result: PASS"
        Write-Output "No Java applications containing unpatched Log4j were found."
        "[`n  { `"hostname`":`"$hostname`", `"scan_ts`":`"$scan_ts`", `"search_root`":`"$search_root_escaped`", `"result`":`"PASS`", `"vulnerable_jar`":false } `n]" | Out-File "$output_filepath"

        # ping result
        try {
          $ping_output = ping -n 1 jkl.122021a.arcticwolf.com
        } catch {}

        Get-AmpOutputVariableValues
        exit 0
    }
} catch {
    Write-Output $_
    Write-Output "Result: ERROR"

    # ping result
    try {
      $ping_output = ping -n 1 xyz.122021a.arcticwolf.com
    } catch {}
    
    Get-AmpOutputVariableValues
    exit 1
}
# Nothing down here will run due to above exit commands in try/catch block