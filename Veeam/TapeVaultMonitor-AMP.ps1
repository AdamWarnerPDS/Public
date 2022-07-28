$outputProperties = @(
    "Name",
    "VaultTapeCount",
    "ActionRecomended"
)

# Gets info for vaults
$vbrTapeVaults = Get-VBRTapeVault
$vaultsCount = $vbrTapeVaults.count
$outObjectsTop = @()
$counter = @( 0..$( ($vaultsCount)-1 ) )
foreach ( $c in $counter ){
    $members = $vbrTapeVaults | Get-Member | Where-Object -Property "MemberType" -eq "Property" | Select-Object -ExpandProperty "Name"
    $out = New-Object -TypeName PSCustomObject
    foreach ($m in $members ){
        $out | Add-Member -Name "$m" -MemberType NoteProperty -Value "$($($vbrTapeVaults[$c]).$m)"
    }
    $out | Add-Member -Name "VaultTapeCount" -MemberType NoteProperty -Value $($($vbrTapeVaults[$c]).Medium.count)
    # Add action reccomendation
    if ( $out.VaultTapeCount -eq 0 ) {
        $out | Add-Member -Name "ActionRecomended" -MemberType NoteProperty -Value "N/A"
    }
    elseif ( $out.VaultTapeCount -ge 1 -and $out.VaultTapeCount -le 3 ) {
        $out | Add-Member -Name "ActionRecomended" -MemberType NoteProperty -Value "Please cycle tapes in vault"
    }
    elseif ( $out.VaultTapeCount -ge 4 ) {
        $out | Add-Member -Name "ActionRecomended" -MemberType NoteProperty -Value "Cycle tapes in vault ASAP!"
    }
    else {
        $out | Add-Member -Name "ActionRecomended" -MemberType NoteProperty -Value "ERROR"
    }
    New-Variable -Name "vault$c" -Value ( $out | Select-Object -Property $outputProperties ) -Force
    $outObjectsTop = $outObjectsTop + "vault$c"
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