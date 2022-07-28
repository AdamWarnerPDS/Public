[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $downloadURI = "https://www.nartac.com/Downloads/IISCrypto/IISCryptoCli.exe",

    [Parameter()]
    [String]
    $workingDir = "C:\temp\iiscrypto\",

    [Parameter()]
    [String]
    $exeName = "IISCryptoCli.exe",

    [Parameter()]
    [String]
    $templateName = "default",

    [Parameter()]
    [Boolean]
    $backup = $true,

    [Parameter()]
    [String]
    $backupPrefix = "Set-IISCryptoTemplate.ps1_RegBackup_",

    [Parameter()]
    [String]
    $logPrefix = "Set-IISCryptoTemplate.ps1_log_",

    [Parameter()]
    [Boolean]
    $reboot = $false,

    [Parameter()]
    [String]
    $runMode = "set"
)

# Declarations
$dateTime = (Get-Date -Format yyyy-MM-ddTHH-mm-ss )
$localExePath = "$workingDir" + "$exeName"
$localBackupPath = "$workingDir" + "$backupPrefix" + "$dateTime" + ".reg"
$latestLocalBackupPath = "$workingDir" + "$backupPrefix" + "LATEST" + ".reg"
$logFileName = $logPrefix + "$dateTime" + ".log"
$logPath = "$workingDir" + "$logFileName"
$acceptableTemplates = @(
    "default",
    "best",
    "pci32",
    "strict",
    "fips140"
)
$acceptableRunModes = @(
    "set",
    "restoreLatestReg"
)

# Main Loop
## Begin Logging
Start-Transcript -Path "$logPath"

## Print out parameters
Write-Output @"
Current variables and parameters
`$downloadURI = `'$downloadURI`'
`$workingDir = `'$workingDir`'
`$exeName = `'$exeName`'
`$templateName = `'$templateName`'
`$backup = `'$backup`'
`$backupPrefix = `'$backupPrefix`'
`$reboot = `'$reboot`'
`$runMode = `'$runMode`'
`$dateTime = `'$dateTime`'
`$localExePath = `'$localExePath`'
`$localBackupPath = `'$localBackupPath`'
`$logFileNameh = `'$logFileName`'
`$logPath = `'$logPath`'
`$acceptableTemplate = `'$($acceptableTemplates.Split(","))`'
`$acceptableRunModes = `'$($acceptableRunModes.Split(","))`'
"@

## Check and create working directory
if ( $(Test-Path -Path "$workingDir") -eq $false ) {
    Write-Output "Did not find `'$workingDir`' , creating it"
    New-Item -Path "$workingDir" -ItemType Directory
}

## Download iiscrypto
Write-Output "Downloading iiscrypto from `'$downloadURI`' to `'$localExePath`'"
Start-BitsTransfer -Source "$downloadURI" -Destination "$localExePath"

## Execute runMode
Write-Output "Executing mode `'$runMode`'"
if ( $runMode -eq "restoreLatestReg" ) {
    Write-Output "Restoring registry to contents of `'$latestLocalBackupPath`'"
    Write-Output "Contents as follows:"
    Get-Content $latestLocalBackupPath | Write-Output
    Invoke-Command { reg import $latestLocalBackupPath }
}
elseif ( $runMode -eq "set") {
    ### Backup if enabled
    if ( $backup -eq $true ){
        Write-Output "Creating registry backup at `'$latestLocalBackupPath`'"
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create("$localExePath /backup $latestLocalBackupPath"))
        Write-Output "Archiving registry backup at `'$localBackupPath`'"
        Copy-Item -Path "$latestLocalBackupPath" -Destination "$localBackupPath"
    }

    ### Apply template using iiscrypto
    if ( $templateName -in $acceptableTemplates ){
        Write-Output "Using iiscrypt to set to template `'$templateName`'"
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create("$localExePath /template $templateName"))
    }
    else {
        Write-Error -Message "Selected `$templateName $templateName is invalid.  Acceptable templates are $($acceptableTemplates.Split(","))"
    }
}
else {
    Write-Error -Message "Selected `$runMode $runMode is invalid.  Acceptable modes are $($acceptableRunModes.Split(","))"
}

## Stop Logging
Stop-Transcript