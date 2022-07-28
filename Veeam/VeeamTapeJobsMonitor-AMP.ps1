$outputProperties = @(
    "FullBackupPolicy",
    "Id",
    "Type",
    "Enabled",
    "LastResult",
    "LastState"
)

$vbrtapeJobs = Get-VBRTapeJob | Where-Object { `
    ( $_.Enabled -eq $true )
    }

$tapeJobsCount = $vbrtapeJobs.count
$outObjectsTop = @()

$jobTrackingContainers = @(
    "failedJobs",
    "warningJobs",
    "successfulJobs",
    "unknownStatusJobs",
    "runningJobs",
    "stoppedJobs",
    "otherStateJobs"
)
foreach ( $j in $jobTrackingContainers ) {
    New-Variable -Name "$j" -Value @() -Force
}
$overallStatus = -1
$overallStatusMessage = ""

$counter = @( 0..$( ($tapeJobsCount)-1) )
foreach ( $c in $counter ){
    $members = $vbrtapeJobs | Get-Member | Where-Object -Property "MemberType" -eq "Property" | Select-Object -ExpandProperty "Name"
    $out = New-Object -TypeName PSCustomObject
    foreach ($m in $members ){
        $out | Add-Member -Name "$m" -MemberType NoteProperty -Value "$($($vbrtapeJobs[$c]).$m)"
    }
    New-Variable -Name "tapeJob$c" -Value ( $out | Select-Object -Property $outputProperties ) -Force
    $outObjectsTop = $outObjectsTop + "tapeJob$c"

    if ( $out.LastResult -eq "Failed" ) {
        $failedJobs = $failedJobs + "$($out.Name)"
    }
    elseif ( $out.LastResult -eq "Warning" ) {
        $warningJobs = $warningJobs + "$($out.Name)"
    }
    elseif ( $out.LastResult -eq "Success" ) {
        $successfulJobs = $successfulJobs + "$($out.Name)"
    }
    else {
        $unknownStatusJobs = $unknownStatusJobs + "$($out.Name)"
    }

    if ( $out.LastState -eq "Running" ) {
        $runningJobs  = $runningJobs + "$($out.Name)"
    }
    elseif ( $out.LastState -eq "Stopped" ) {
        $stoppedJobs = $stoppedJobs + "$($out.Name)"
    }
    elseif ( $out.LastState -ne "Running" -and $out.LastState -eq "Stopped" ){
        $otherStateJobs = $otherStateJobs + "$($out.Name)"
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
    $overallStatusMessage = "Jobs in unknown LastState"
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
    $overallStatusMessage = "Unknown LastState, check job status manually"
}

$outObjectsBot = $outObjectsBot + "overallStatus"
$outObjectsBot = $outObjectsBot + "overallStatusMessage"

foreach ($o in $outObjectsBot) { Get-Variable $o }
