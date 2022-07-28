# Declarations
[CmdletBinding()]
param (
    # Where to download file from
    [Parameter()]
    [string]
    $sourceURI = "https://github.com/AdamWarnerPDS/Public/raw/master/LAPS.x64.msi",
    # Where to save the file
    [Parameter()]
    [string]
    $msiLocalPath = "C:\temp\LAPS.x64.msi",
    # Where to save the file
    [Parameter()]
    [string]
    $logPath = "C:\Temp\LAPS.x64.msi.log"
)
function Wait-ForPath() {
    [CmdletBinding()]
    param (
        # How Many loops to wait
        [Parameter()]
        [int32]
        $loopMax,
        # How long to wait per loop in seconds
        [Parameter()]
        [int32]
        $waitTime,
        # What path to test
        [Parameter()]
        [String]
        $Path
    )
    
    [int32]$i = 0
    [int32]$elapsedTime = 0
    while ( $i -lt $loopMax ) {
        if ( $(Test-Path -Path "$path") -eq $false) {
            $i ++
            Write-Host "Did not find $path - waiting $waitTime seconds.  Have waited $elapsedTime seconds"
            Start-Sleep -Seconds $waitTime
            $elapsedTime = $elapsedTime + $waitTime
        }
        else {
            Write-Host "Found $path"
            break
        }
    }
    if ( $(Test-Path -Path "$path") -eq $false) {
        Write-Host "Did not find $path - exiting with code 1"
        Exit 1
    }
}

Start-BitsTransfer -Source "$sourceURI" -Destination $msiLocalPath

Wait-ForPath -loopMax 3 -waitTime 10 -path "$msiLocalPath"

msiexec.exe /i "$msiLocalPath" ALLUSERS=1 /qn /norestart /L*V "$logPath"

Wait-ForPath -loopMax 3 -waitTime 10 -path "$logPath"

$logContent = Get-Content -Path "$logPath"
$targetMessage = "Windows Installer installed the product. Product Name: Local Administrator Password Solution"
$successMessage = $logContent | Select-String -Pattern "$targetMessage"

$logContent

if ( $null -eq $successMessage ) { 
    Write-Host "Did not find success message, the installation likely failed"
    Exit 1
}
else {
    Write-Host "Found success message.  The installation succeeded"
    Exit 0
}