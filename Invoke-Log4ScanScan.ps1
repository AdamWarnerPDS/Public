# Original logic for script burrowed from
# https://www.cyberdrain.com/monitoring-with-powershell-detecting-log4j-files/

# Enable verbose output
$oldVerbosePreference = $verbosePreference
$VerbosePreference = "continue"

# Set to TLS12 for current session
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$logPath = "C:\temp\log4scan-scan.log"
$psVersion = (Get-Host | Select-Object -ExpandProperty Version).ToString().Split(".") 
# For PS version 5.1 and above
if ($psVersion[0] -ge 5) {
    # Check that NuGet Package Provider is version 2.8.5.201 or later, install if not
    $nuGetMinVer = @(2,8,5,201)
    $nuGetMinVerStr = $($nuGetMinVer -join '.')
    try {
        $ngver = Get-PackageProvider -ErrorAction SilentlyContinue `
            | Where-Object -Property Name -like NuGet `
            | Select-Object -ExpandProperty Version

        if ( $($ngver.Major) -le $nuGetMinVer[0] `
                -and $($ngver.Minor) -le $nuGetMinVer[1] `
                -and $($ngver.Build) -le $nuGetMinVer[2] `
                -and $($ngver.Revision) -lt $nuGetMinVer[3] ) {
            Write-Verbose "Installing NuGet"
            Install-PackageProvider -Name NuGet -MinimumVersion "$nuGetMinVerStr" -Force -Confirm:$false
        }
    }
    catch {
        Write-Warning -Message "Could not query current package provider, blindly force installing latest NuGet"
        Install-PackageProvider -Name NuGet -MinimumVersion "$nuGetMinVerStr" -Force-Confirm:$false
    }

    # Install PSGallery package provider
    if ( "PSGallery" -notin $(Get-PSRepository | Select-Object -ExpandProperty Name) `
        -or $null -eq $(Get-PSRepository) ) {
        Register-PSRepository -Default
    }

    # set Installation Policy for PSGallery to trusted for duration of script (reversion at bottom)
    $oldInstallationPolicy = Get-PSRepository `
        | Where-Object -Property Name -eq "PSGallery" `
        | Select-Object -ExpandProperty "InstallationPolicy"
    if ( $oldInstallationPolicy -eq "untrusted") {
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    }
}
<# Module requires powershell version 5.1
# For PS 5.1 and below (really just 4)
else {
    $primaryPSModulePath = ($env:PSModulePath.Split(";") -match 'C:\\Program Files')
    $secondaryPSModulePath = ($env:PSModulePath.Split(";") -match 'C:\\Windows\\system32')
    if ( $(Test-Path -Path "$primaryPSModulePath" ) ) {
        $psModulePath = "$primaryPSModulePath"
    }
    elseif ( $(Test-Path -Path "$secondaryPSModulePath" ) ) {
        $psModulePath = "$secondaryPSModulePath"
    }
    else {
        throw "No valid path for psmodules"
        Exit 1
    }
    $psEverythingURL = "https://github.com/AdamWarnerPDS/Public/raw/master/pseverything.3.2.1.zip"
    $psEverythingZip = "c:\temp\pseverything.3.2.1.zip"
    $psEverythingExtractPath = "C:\temp"
    Invoke-WebRequest -UseBasicParsing -Uri "$psEverythingURL" -OutFile $psEverythingZip
    # Expand-Archive is not part of PS4, FFS
    #Expand-Archive "$psEverythingZip" -DestinationPath "$psEverythingExtractPath" -Force
    # Use a .net assembly that is hopefully installed
    Add-Type -Assembly "System.IO.Compression.Filesystem"
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$psEverythingZip","$psEverythingExtractPath")
    Copy-Item -Path "$psEverythingExtractPath`\pseverything.3.2.1`\`*" -Destination "$psModulePath`\PSEverything`\"
    Import-Module PSEverything
}
#>

# Install Everything portable and engange service
$PortableEverythingURL = "https://www.voidtools.com/Everything-1.4.1.1009.x64.zip"
# AMPs don't like below variables for some reason; using static assignment
#[string]$zipPath = "$($ENV:TEMP)`\Everything.zip"
[string]$zipPath = "C:\temp\Everything.zip"
if ( $(Test-Path -Path "$zipPath") -eq $false ) {
    Write-Verbose "Downloading Everything to $zipPath"
    [System.Net.servicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri "$PortableEverythingURL" -OutFile "$zipPath"
}
else {
    Write-Verbose "Found $zipPath"
}

# AMPs don't like below variables for some reason; using static assignment
#[string]$exePath = "$($ENV:TEMP)\everything.exe"
[string]$exeDestPath = 'C:\temp'
[string]$exePath = 'C:\temp\everything.exe'
[string]$exeArgsInst = @('-install-client-service')
[string]$exeArgsUnInst = @('-uninstall-client-service')
[string]$exeArgsStartSvc = @('-start-client-service')
# Verified sthat $exePath is in fact a file and exists
if ( $(Test-Path -Path "$exePath" -PathType leaf) -eq $false ) {
    # Cleans up previous problem that we may have made
    if ( $(Test-Path -Path "$exePath" -PathType container) -eq $true ) {
        Remove-Item "$exePath" -Recurse -Force
    }
    Write-Verbose "Extracting Everything to $exeDestPath"
    if ($psVersion[0] -ge 5) {
        Expand-Archive "$zipPath" -DestinationPath "$exeDestPath" -Force
    }
    Else {
        Add-Type -Assembly "System.IO.Compression.Filesystem"
        [System.IO.Compression.ZipFile]::ExtractToDirectory("$zipPath","$exeDestPath")
    }
}
else {
    Write-Verbose "Found $exePath"
}

if (!(Get-Service "Everything Client" -ErrorAction SilentlyContinue)) {
    Write-Verbose "Did not find service, installing"
    & C:\temp\everything.exe $exeArgsInst
}
# Had to hard-code C:\temp\everything.exe for some reason, & not taking variable for filepath
Write-Verbose "Starting Service"
& C:\temp\everything.exe $exeArgsStartSvc

if ($psVersion[0] -ge 5) {
    if ( $null -eq $(Get-Module PSEverything) ) {
        Write-Verbose "Installing PSEverything module"
        Install-Module PSEverything
        $removeModule = $true
    }    
}

# Needs to launch to avoid IPC error.  There is a -exit near the end
Write-Verbose "Launching everything.exe"
& C:\temp\everything.exe -minimized -nonewwindow
Start-Sleep -Seconds 5

if ($psVersion[0] -lt 5) {
    if ($(Test-Path -Path "C:\temp\ES-1.1.0.20.zip") -eq $false ) {
        [System.Net.servicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Write-Verbose "Dowloading https://www.voidtools.com/ES-1.1.0.20.zip"
        invoke-webrequest -UseBasicParsing -Uri "https://www.voidtools.com/ES-1.1.0.20.zip" -OutFile "C:\temp\ES-1.1.0.20.zip"
    }
    if ( $(Test-Path -Path "C:\temp\es.exe") -eq $false ) {
        Write-Verbose "Extracting C:\temp\ES-1.1.0.20.zip"
        Add-Type -Assembly "System.IO.Compression.Filesystem"
        [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\temp\ES-1.1.0.20.zip","C:\temp\")
    }
}

if ($psVersion[0] -ge 5) {
    $ScanResults = Search-Everything -Global -Extension jar
}
else {
    $ScanResults = C:\temp\es.exe *.jar
}
$ScanResultsFiltered = ($ScanResults `
    | ForEach-Object { Select-String "JndiLookup.class" $_ }).path
if ( $null -ne $ScanResultsFiltered ) {
    # Disabled these as they put out far too much information
    #Write-Verbose "Potential vulnerable JAR files found. Please investigate:"
    #Write-Verbose "all Results:"
    #$scanresults
    Write-Verbose "All Results with vulnerable class:"
    $ScanResultsFiltered `
        | Tee-Object -FilePath "$logPath" `
        | Tee-Object -Variable "scanResultsRaw"
    Write-Verbose "Wrote results to $logPath"
    $scanResultsString = ($scanResultsRaw -join ';' )
}
else {
    Write-Verbose "Did not find any vulnerable files."
    $scanResultsString = "N/A"
}

# Revert Installation Policy for PSGallery
if ( $oldInstallationPolicy -eq "untrusted") {
    Write-Verbose "Reverting InstallationPolicy for PSGallery to untrusted"
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy untrusted
}

# Don't quit, leave it running
<#
Write-Verbose "Killing everything.exe"
& C:\temp\everything.exe -quit
Start-Sleep -Seconds 5
#>


# Remove Everything Client service
if ((Get-Service "Everything Client" -ErrorAction SilentlyContinue)) {
    Write-Verbose "Removing Service"
    & C:\temp\everything.exe $exeArgsUnInst
}


# Remove PSEverything module if it was previously not installed
if ($psVersion[0] -ge 5) {
    if ( $removeModule = $true ) {
        Remove-Module PSEverything
    }
}

$verbosePreference = "$oldVerbosePreference"
Exit 0