$serviceName = "AuvikWatchdog"
$logPath = "C:\Temp\Invoke-AuvikWatchdogMaintenance.ps1.log"

function Write-ScriptOutput {
    param (
        [Parameter(Position=0)]
        [string[]]
        $text = "",

        [Parameter(Position=1)]
        [string[]]
        $type = ""
    )
    Write-Output "$(Get-Date -Format FileDateTime) - $type - $text" | Tee-Object -FilePath "$LogPath" -Append
}

$serviceStatus = $((Get-Service -Name "$serviceName").Status)
Write-Host "============================================="
Write-ScriptOutput "Begining $serviceName maintenance" "INFO"
Write-ScriptOutput "Service $serviceName is $serviceStatus" "INFO"

if ( $serviceStatus -eq "Running" ) {
    Write-ScriptOutput "Restarting $serviceName" "INFO"
    Restart-Service -Name "$serviceName"
}
elseif ( $serviceStatus  -ne "Running" ) {
    Write-ScriptOutput "$serviceName is NOT running" "WARN"
    Write-ScriptOutput "Starting $serviceName" "INFO"
    Start-Service -Name "$serviceName"
}

$newServiceStatus = $((Get-Service -Name "$serviceName").Status)
Write-ScriptOutput "Post maintenance check" "INFO"
Write-ScriptOutput "Service $serviceName is $newServiceStatus" "INFO"
if  ( $newServiceStatus -ne "Running" ) {
    Write-ScriptOutput "Service $serviceName was not found to be running, attempting to start" "ERROR"
    Start-Service -Name "$serviceName"
    $newNewServiceStatus = $((Get-Service -Name "$serviceName").Status)
    if ( $newNewServiceStatus -ne "Running") {
        Write-ScriptOutput "Service $serviceName is still not running, it appears to be unable to start" "ERROR"
        Exit 1
    }
}
elseif ( $newServiceStatus -eq "Running") {
    Write-ScriptOutput "Maintenance on $serviceName is complete" "INFO"
    Exit 0
}
