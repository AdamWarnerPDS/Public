[CmdletBinding()]
param (

    # Set target version such as "2004"; default is "$null"; use values from the "version" column at https://aka.ms/ReleaseInformationPage
    [Parameter(Mandatory=$True)]
    [string]$targetReleaseVersionInfoValue,

    # Enables or disables the target version restriction; 0 = disabled, 1 = enabled; default is 1
    [Parameter()]
    [int]$targetReleaseVersionValue = "1"
)

# Origial source of reg keys: https://www.ghacks.net/2020/06/27/you-can-now-set-the-target-windows-10-release-in-professional-versions/

## Declarations
# "Static" Variables
$hive = "HKLM:\"
$keyPath = "SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

# 'Dynamic" Variables
$fullKeyPath = "$hive" + "$keyPath"
$dateTime = (Get-Date -Format yyyy-MM-ddTHH-mm-ss)

# Main loop
function Set-RegistryValues {
    New-ItemProperty -Path "$fullKeyPath" -Name "TargetReleaseVersion" -Value $targetReleaseVersionValue -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path "$fullKeyPath" -Name "TargetReleaseVersionInfo" -Value "$targetReleaseVersionInfoValue" -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path "$fullKeyPath" -Name "TargetReleaseVersionValuesLastUpdated" -Value "$dateTime" -PropertyType STRING -Force | Out-Null
}

## This is bloody dangerous!!!!  Will overwrite registry keys and their content values if you're not careful
<#
# Check if key exists and create key if it does not
if ( $(Test-Path "$fullKeyPath") -eq $false) {
    Write-Host "Creating registry key `"$fullKeyPath`""
    New-Item -Path "$fullKeyPath" -Force
}
else {
    Write-Host "Registry key `"$fullKeyPath`" exists"
}
#>

$valuesAtStart = @($(Get-ItemProperty -Path "$fullKeyPath" | Select-Object TargetReleaseVersion,TargetReleaseVersionInfo,TargetReleaseVersionValuesLastUpdated) )
# Check values and edit if they do not meet input

if ( $($valuesAtStart.TargetReleaseVersion) -ne "$targetReleaseVersionValue" -or $($valuesAtStart.TargetReleaseVersionInfo) -ne "$targetReleaseVersionInfoValue" ) {
    Write-Host "Setting registry to target values"
    Set-RegistryValues
    Start-Sleep -Seconds 1
}
else {
    Write-Host "Registry already at target values"
}

$valuesAtEnd = @($(Get-ItemProperty -Path "$fullKeyPath" | Select-Object TargetReleaseVersion,TargetReleaseVersionInfo,TargetReleaseVersionValuesLastUpdated))

# Verify changes
if ( $($valuesAtEnd.TargetReleaseVersion) -ne "$targetReleaseVersionValue" -or $($valuesAtEnd.TargetReleaseVersionInfo) -ne "$targetReleaseVersionInfoValue" ) {
    Write-Error "Values in registry are incorrect"
    $valuesAtEnd | FL
    Exit 1
}
else {
    Write-Host "Complete"
    $valuesAtEnd | FL
    Exit 0
}

