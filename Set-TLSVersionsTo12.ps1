[CmdletBinding()]
param (

    # Set target value of Internet Settings\WinHttp -> DefaultSecureProtocols: 00000800 = TLS 1.2 enabled, 00000200 = TLS 1.1 enabled, 00000A00 = TLS 1.1, 1.2 enabled, 00000A80 = TLS 1.0, 1.1, 1.2 enabled
    [Parameter()]
    [string]$defaultSecureProtocols = "00000800",

    # Set target value of SCHANNEL\Protocols\TLS n.n\Client or Server -> DisabledByDefault: 0 = enabled, 1 = disabled.
    [Parameter()]
    [int]$sChannelDisabledByDefault = "0",

    # Set target value of SCHANNEL\Protocols\TLS n.n\Client or Server -> Enabled: 1 = enabled, 0 = disabled.
    [Parameter()]
    [int]$sChannelEnabled = "1"
)

## Variable Declarations
# "Static" Variables
$defaultSecureProtoPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp"
    )
$schannelPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client",
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client",
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server",
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
)
$allPaths = $defaultSecureProtoPaths + $schannelPaths

# 'Dynamic" Variables

# Transform $defaultSecureProtocols to hex value
$defaultSecureProtocols = [convert]::toint32("$defaultSecureProtocols",16)


# ISO 8601 short datetime format
$startDateTime = "$(get-date -uf %Y%m%dT%H%M%S%Z)"

# Backup filenames
$regBackupPath = 'C:\RegBackup\'
$regBackupFilename = 'HKLM_' + "$startDateTime" + '.reg'
$regBackupZipFilename = 'HKLM_' + "$startDateTime" + '.zip'
$regBackupFullPath = "$regBackupPath" + "$regBackupFilename"
$regBackupZipFullPath = "$regBackupPath" + "$regBackupZipFilename"

# Safety nulls
$targetKeyPath = $null
$targetProperty = $null
$targetValue = $null
$p = $null

## Function Declarations
function Get-HKLMBackup {
    Write-Host "Backing up the HKLM registry hive to $regBackupFullPath"
    New-Item -Path "$regBackupPath" -ItemType Directory -ErrorAction SilentlyContinue
    reg export HKLM "$regBackupFullPath" /y
    Compress-Archive -Path "$regBackupFullPath" -DestinationPath "$regBackupZipFullPath" -CompressionLevel Optimal
    If ( $(Test-Path -Path "$regBackupZipFullPath" ) -eq $true ) {
        # Check if zipped backup is greater than 5 MB, or more broadly, isn't a zero length file, before deleting the large .reg
        If ( $($(Get-ChildItem -Path "$regBackupZipFullPath").length) -gt 5000 ){
            Remove-Item "$regBackupFullPath"
            Write-Host "Verified presence of $regBackupZipFullPath"
        }
    }
}

function New-RegistryPath {
    if ( $(Test-Path "$targetKeyPath") -eq $false) {
        Write-Host "Creating registry key `"$targetKeyPath`""
        New-Item -Path "$targetKeyPath" -Force
    }
    else {
        Write-Host "Registry key `"$targetKeyPath`" already exists"
    }
}
function Set-RegistryValues {
    Write-Host "Creating registry property `"$targetProperty`" with value `"$targetValue`" at location `"$targetKeyPath`""
    New-ItemProperty -Path "$targetKeyPath" -Name "$targetProperty" -Value $targetValue -PropertyType DWORD -Force | Out-Null
}

## Main Loop
# Backup HKLM registry hive
Get-HKLMBackup

# Create all paths/keys
foreach ( $p in $allPaths ) {
    $targetKeyPath = "$p"
    New-RegistryPath
}

# Write DefaultSecureProtocols
foreach ( $p in $defaultSecureProtoPaths ){
    $targetKeyPath = "$p" ######### THIS NEEDS TO BE SET AS HEX
    $targetProperty = "DefaultSecureProtocols"
    $targetValue = "$defaultSecureProtocols"
    Set-RegistryValues
}

# Write SCHANNEL\Protocols\TLS n.n\Client or Server
foreach ( $p in $schannelPaths ){
    $targetKeyPath = "$p"
    # Write SCHANNEL\Protocols\TLS n.n\Client or Server -> DisabledByDefault
    $targetProperty = "DisabledByDefault"
    $targetValue = "$sChannelDisabledByDefault"
    Set-RegistryValues

    # Write SCHANNEL\Protocols\TLS n.n\Client or Server -> Enabled
    $targetProperty = "Enabled"
    $targetValue = "$sChannelEnabled"
    Set-RegistryValues        
}
