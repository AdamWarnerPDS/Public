Param(
    # Positioned parameters can be gathered from Invoke-Command -ArgumentList
    # Where to copy the json to on the network
    # This parameter is deprecated.  It remains only for positional accuracy
    [Parameter(Position=0)]
    [string[]]
    $centralOutputDir = "",

    # Where to store the json locally on computer being scanned
    [Parameter(Position=1)]
    [string[]]
    $jsonDir = "",

    [Parameter(Position=2)]
    [string[]]
    $search_root = "",

    # This was previously $output_filepath.  With the addition of variable directory, $output_filepath is assigned below
    [Parameter(Position=3)]
    [string[]]
    $output_filename = ""
)

$scan_ts = $(Get-Date -format 'o')
$hostname = "$([System.Net.Dns]::GetHostByName($env:computerName).HostName)"

Write-Host "Scanning on $hostname as $(whoami)"

if ( $(Test-Path -Path $jsonDir) -eq $false ){
  Write-Host "Target local directory $jsonDir does not exist, creating it"
  New-Item -ItemType Directory -Path "$jsonDir"
  if ( $(Test-Path -Path $jsonDir) -eq $false ){
    Write-Error "Failed to create $jsonDir"
    Exit 1
  }
}


$output_filepath = "$jsonDir" + "$output_filename"
Write-Host "Local output file is $output_filepath"

<# Deprecated
$centralOutputPath = "$centralOutputDir" + "$output_filename"
Write-Host "Remote output path is $centralOutputPath"
#>

# clear all errors
$error.Clear()
Add-Type -Assembly "System.IO.Compression.Filesystem"

<#  All of this is really not necessary for a headless script
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
#>

# make sure output path doesn't exict
if (Test-Path $output_filepath) {
    Write-Output "ERROR: output file exists. Please delete $output_filepath or specify an alternate output file."
    exit 0
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

        <# Deprecated
        # added for central collection
        Write-Host "Writing output to remove path $centralOutputPath"
        Copy-Item -Path "$output_filepath" -Destination "$centralOutputPath"
        #>

        # was exit 1
        exit 2
    } else {
        Write-Output "Result: PASS"
        Write-Output "No Java applications containing unpatched Log4j were found."
        "[`n  { `"hostname`":`"$hostname`", `"scan_ts`":`"$scan_ts`", `"search_root`":`"$search_root_escaped`", `"result`":`"PASS`", `"vulnerable_jar`":false } `n]" | Out-File "$output_filepath"

        # ping result
        try {
          $ping_output = ping -n 1 jkl.122021a.arcticwolf.com
        } catch {}

        <# Deprecated
        # added for central collection
        Write-Host "Writing output to remove path $centralOutputPath"
        Copy-Item -Path "$output_filepath" -Destination "$centralOutputPath"
        #>

        exit 0
    }
} catch {
    Write-Output $_
    Write-Output "Result: ERROR"

    # ping result
    try {
      $ping_output = ping -n 1 xyz.122021a.arcticwolf.com
    } catch {}
    
    exit 1
}

