$outputProperties = @(
    "Name",
    "Id",
    "TypeToString",
    "IsScheduleEnabled",
    "SheduleEnabledTime",
    "IsRunning",
    "IsIdle",
    "Result",
    "State"
)

$sessionProperties = @(
    "Result",
    "State"
)
<# Broke see SheduleEnabledTime
$vbrBackupJobs = Get-VBRJob | Where-Object { `
    ($_.IsBackupCopy -eq $false) `
    -and ($_.IsScheduleEnabled -eq $true) `
    -and ($_.SheduleEnabledTime) -ne $null `
    -and ($_.IsAgentManagementParentJob -eq $false) `
    -and ($_.IsAgentManagementParentJob -eq $false) `
    }
#>
$vbrBackupJobs = Get-VBRJob | Where-Object { `
    ($_.IsBackupCopy -eq $false) `
    -and ($_.IsScheduleEnabled -eq $true) `
    -and ($_.IsAgentManagementParentJob -eq $false) `
    -and ($_.IsAgentManagementParentJob -eq $false) `
    }


$backupJobsCount = $vbrBackupJobs.count
$outObjectsTop = @()

$jobTrackingContainers = @(
    "failedJobs",
    "warningJobs",
    "successfulJobs",
    "unknownStatusJobs",
    "runningJobs"
)
foreach ( $j in $jobTrackingContainers ) {
    New-Variable -Name "$j" -Value @() -Force
}
$overallStatus = -1
$overallStatusMessage = ""

$counter = @( 0..$( ($backupJobsCount)-1) )
foreach ( $c in $counter ){
    $members = $vbrBackupJobs | Get-Member | Where-Object -Property "MemberType" -eq "Property" | Select-Object -ExpandProperty "Name"
    $out = New-Object -TypeName PSCustomObject
    foreach ($m in $members ){
        $out | Add-Member -Name "$m" -MemberType NoteProperty -Value "$($($vbrBackupJobs[$c]).$m)"
    }
    $sessionBuffer = $vbrBackupJobs[$c] | `
        ForEach-Object { `
        Get-VBRBackupSession `
        | Where-Object -Property jobId -eq $_.Id `
        | Sort EndTimeUTC -Descending `
        | Select -First 1 `
        | Select-Object -Property "Result","State"
        }
    foreach ( $p in $sessionProperties ) {
        $out | Add-Member -Name "$p" -MemberType NoteProperty -Value "$($sessionBuffer.$p)"
    }
    New-Variable -Name "backupJob$c" -Value ( $out | Select-Object -Property $outputProperties ) -Force
    $outObjectsTop = $outObjectsTop + "backupJob$c"

    if ( $out.IsRunning -eq $false ) {
        if ( $out.Result -eq "Failed" ) {
            $failedJobs = $failedJobs + "$($out.Name)"
        }
        elseif ( $out.Result -eq "Warning" ) {
            $warningJobs = $warningJobs + "$($out.Name)"
        }
        elseif ( $out.Result -eq "Success" ) {
            $successfulJobs = $successfulJobs + "$($out.Name)"
        }
        else {
            $unknownStatusJobs = $unknownStatusJobs + "$($out.Name)"
        }
    }
    elseif ( $out.IsRunning -eq $true ) {
        $runningJobs = $runningJobs + "$($out.Name)"
    }
    else {
        $unknownStatusJobs = $unknownStatusJobs + "$($out.Name)"
    }
}

# Make all output into its own variable as N-Central Automation Manager expects discrete variables
# It can't handle nested information
$outObjectsBot = @()
foreach ( $o in $outObjectsTop ) {
    foreach ( $p in $outputProperties ) {
        $name = "$o`_$p"
        $target = ( Get-Variable -ValueOnly "$o" | Select-Object -ExpandProperty "$p" )
        New-Variable -Name "$name" -Value $target -Force
        $outObjectsBot = $outObjectsBot + $name
    }
}

foreach ( $j in $jobTrackingContainers ) {
    $name = "$j`Count"
    New-Variable -Name "$name" -Value $( (Get-Variable -ValueOnly "$j").count ) -Force
    $outObjectsBot = $outObjectsBot + $j
    $outObjectsBot = $outObjectsBot + $name

    $jobObjectBuffer = ""
    foreach ( $m in $(Get-Variable -ValueOnly "$j") ) {
        $jobObjectBuffer = $jobObjectBuffer + "$m, "
    }
    if ( $jobObjectBuffer -ne "" ) { 
        $jobObjectBuffer = $jobObjectBuffer.TrimEnd(", ") 
    }
    if ( $jobObjectBuffer -eq "" ) { 
        $jobObjectBuffer = "N/A" 
    }
    New-Variable -Name "$j" -Value "$jobObjectBuffer" -Force
}

if ( $failedJobsCount -gt 0 ) {
    $overallStatus = -3
    $overallStatusMessage = "Failed Jobs!"
}
elseif ( $warningJobsCount -gt 0 ) {
    $overallStatus = -2
    $overallStatusMessage = "Jobs completed with warnings"
}
elseif ( $unknownStatusJobsCount -gt 0 ) {
    $overallStatus = -1
    $overallStatusMessage = "Jobs in unknown state"
}
elseif ( $runningJobsCount -gt 0 ) {
    $overallStatus = 0
    $overallStatusMessage = "Jobs running"
}
elseif ( $successfulJobsCount -gt 0 ) {
    $overallStatus = 0
    $overallStatusMessage = "Jobs successful"
}
else {
    $overallStatus = -1
    $overallStatusMessage = "Unknown state, check job status manually"
}

$outObjectsBot = $outObjectsBot + "overallStatus"
$outObjectsBot = $outObjectsBot + "overallStatusMessage"

foreach ($o in $outObjectsBot) { Get-Variable $o }
