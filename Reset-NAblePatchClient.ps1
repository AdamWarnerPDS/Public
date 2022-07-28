$dateTime = (Get-Date -Format yyyy-MM-ddTHH-mm-ss )
$logFileName = "Reset-NAblePatchClient.ps1_" + "$dateTime" + ".log"
$logPath = "C:\temp\" + "$logFileName"

Start-Transcript -Path "$logPath"

$scriptExitCode = 0

$services = @(
    "Windows Agent Service",
    "Windows Agent Maintenance Service"
)

# Setup task to recover agent service in case of failed script
## When to execute; ((Get-Date).AddMinutes(1)) means 1 minute
$taskName = "Reset-NAblePatchClient_Recovery"
$taskExecTime = ((Get-Date).AddMinutes(1))
$A = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument 'Start-Service -Name "Windows Agent Service" ; Start-Service -Name "Windows Agent Maintenance Service"'
$T = New-ScheduledTaskTrigger -At $taskExecTime -Once
$P = New-ScheduledTaskPrincipal "NT Authority\System"
## Deletion actually controlled by the weird pipe below under New-ScheduledTask .EndBoundary thing
$S = New-ScheduledTaskSettingsSet -DeleteExpiredTaskAfter 00:00:01
## New-ScheduledTask Needs '| %{ $_.Triggers[0].EndBoundary = $taskExecTime.AddMinutes(5).ToString('s') ; $_ } ' 
## due to a stupid PS bug wherein the 'New-ScheduledTaskSettings -DeleteExpiredTaskAfter' switch is broken and needs an 'end boundry'
### https://stackoverflow.com/questions/29337135/powershell-v4-create-remote-task-scheduler-task-set-to-expire-and-delete
### Task deletion controlled at $taskExecTime.AddMinutes(5).ToString('s') under AddMinutes
$D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S | ForEach-Object { $_.Triggers[0].EndBoundary = $taskExecTime.AddMinutes(5).ToString('s') ; $_ } 
## Register above task.  
Register-ScheduledTask -TaskName "$taskName" -InputObject $D

Write-Output "Checking for scheduled task $taskName"
try {
    Get-ScheduledTask -TaskName "$taskName"
}
catch {
    Write-Error "Failed to create rescue scheduled task, exiting"
    exit 1
}

# Stop Services
foreach ( $s in $services ) {
    Write-Output "Stopping service $s"
    try {
        Stop-Service -Name "$s" -Force
    }
    catch {
        Write-Error "Unable to stop service $s"
        $scriptExitCode = 1
    }
}

# Delete cached items
Write-Output "Deleting .xml, .zip, and .exe files in C:\Program Files (x86)\N-able Technologies\PatchManagement"
try {
    Get-ChildItem -Path "C:\Program Files (x86)\N-able Technologies\PatchManagement" `
    | Where-Object { $_.Name -Match ".*(.xml|.zip|.exe)" } `
    | Remove-Item -Force
}
catch {
    Write-Error "Problem deleting .xml, .zip, and .exe in C:\Program Files (x86)\N-able Technologies\PatchManagement"
    $scriptExitCode = 1
}

# Remove Patch metadata
Write-Output "Removing contents of C:\Program Files (x86)\N-able Technologies\PatchManagement\metadata\"
try {
    Remove-Item -Recurse -Path "C:\Program Files (x86)\N-able Technologies\PatchManagement\metadata\*"
}
catch {
    Write-Error "Problem deleting contents of C:\Program Files (x86)\N-able Technologies\PatchManagement\metadata\"
    $scriptExitCode = 1
}


# Remove third-party config
Write-Output "Deleting C:\Program Files (x86)\N-able Technologies\Windows Agent\config\PatchConfig.xml"
try {
    Remove-Item -Path "C:\Program Files (x86)\N-able Technologies\Windows Agent\config\PatchConfig.xml"
}
catch {
    Write-Error "Trouble when deleting C:\Program Files (x86)\N-able Technologies\Windows Agent\config\PatchConfig.xml"
    $scriptExitCode = 1
}

# Sleep a bit
Start-Sleep -Seconds 10

# Restart Services
foreach ( $s in $services ) {
    Write-Output "Attempting to start service $s"
    Start-Sleep -Seconds 5
    try {
        Start-Service -Name "$s"
    }
    catch {
        Write-Error "Unable to start service $s"
        $scriptExitCode = 1
    }
}

# Sleep a minute to avoid false positives
Start-Sleep -Seconds 15
if ( $((Get-Service -Name "Windows Agent Service").Status) -eq "Running" -and $((Get-Service -Name "Windows Agent Maintenance Service").Status) -eq "Running") {
    Write-Output "Found desired services running, removing recovery task"
    # -Confirm:$false means it won't prompt for confirmation
    Unregister-ScheduledTask -TaskName "$taskName" -Confirm:$false
}
else {
    Write-Error "The Agent or Agent Maintenance service is not running; relying on recovery task"
    $scriptExitCode = 1
}

Write-Output "Exiting with code $scriptExitCode"
Stop-Transcript
Exit $scriptExitCode