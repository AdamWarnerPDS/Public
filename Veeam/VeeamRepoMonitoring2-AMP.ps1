$outputProperties = @(
    "Name",
    "Id",
    "TypeDisplay",
    "CapacityInTB",
    "FreeSpaceInTB",
    "UsedSpaceInTB",
    "SpaceUtilizationInPercent"
)
$ignoreRepos = @(
    "Default Backup Repository",
    "ONTAP Snapshot"
)
$allRepos = Get-VBRBackupRepository | Where-Object -Property Name -NotIn $ignoreRepos
$reposCount = $allRepos.count
$outObjectsTop = @()
$counter = @( 0..$( ($reposCount)-1) )
foreach ( $c in $counter ){
    $members = $allRepos | Get-Member | Where-Object -Property "MemberType" -eq "Property" | Select-Object -ExpandProperty "Name"
    $out = New-Object -TypeName PSCustomObject
    foreach ($m in $members ){
        $out | Add-Member -Name "$m" -MemberType NoteProperty -Value "$($($allRepos[$c]).$m)"
    }
    $spaceTemp = $allRepos[$c].GetContainer()
    $out | Add-Member -Name "CapacityInTB" -MemberType NoteProperty -Value ( [math]::Round( ( ($spaceTemp.CachedTotalSpace.InGigabytes) / 1024),2 ) )
    $out | Add-Member -Name "FreeSpaceInTB" -MemberType NoteProperty -Value ([math]::Round( ( ($spaceTemp.CachedFreeSpace.InGigabytes) / 1024),2 ) )
    $out | Add-Member -Name "UsedSpaceInTB" -MemberType NoteProperty -Value ( ($out.CapacityInTB) - ($out.FreeSpaceInTB) )
    # This if/else avoids potential divide by 0 errors
    if ( $out.CapacityInTB -gt 0 ) {
        # Normal operation
        $out | Add-Member -Name "SpaceUtilizationInPercent" -MemberType NoteProperty -Value ( [math]::Round( ( ( ($out.UsedSpaceInTB) / ($out.CapacityInTB) ) * 100 ),2 ) )
    }
    else {
        # Using value 100 to throw "failed" in N-Central
        $out | Add-Member -Name "SpaceUtilizationInPercent" -MemberType NoteProperty -Value 100
    }
    
    New-Variable -Name "repo$c" -Value ( $out | Select-Object -Property $outputProperties ) -Force
    $outObjectsTop = $outObjectsTop + "repo$c"
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

foreach ($o in $outObjectsBot) { Get-Variable $o }