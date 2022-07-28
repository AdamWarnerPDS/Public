<#
$VBRvaults = get-vbrtapevault

$vault1p = $VBRVaults[0].Protect
$tapeName1 = $VBRVaults[0].Medium
$vault1m = $tapeName1.Name
$vault1i = $VBRVaults[0].Id
$vault1n = $VBRVaults[0].Name
$vault1d = $VBRVaults[0].Description
$vault1c = $tapeName1.count

$vault2p = $VBRVaults[1].Protect
$tapeName2 = $VBRVaults[1].Medium
$vault2m = $tapeName2.Name
$vault2i = $VBRVaults[1].Id
$vault2n = $VBRVaults[1].Name
$vault2d = $VBRVaults[1].Description
$vault2c = $tapeName2.count
#>


<#
$vbrTapeVaults = Get-VBRTapeVault
$counter = @(0..$($($($vbrTapeVaults).count)-1))
$output = @()
foreach ( $c in $counter ){
    $out = New-Object -TypeName PSCustomObject
    $members = $vbrTapeVaults | Get-Member | Where-Object -Property "MemberType" -eq "Property" | Select-Object -ExpandProperty "Name"
    foreach ($m in $members ){
        $out | Add-Member -Name "$m-$($($c)+1)" -MemberType NoteProperty -Value "$($($vbrTapeVaults[$c]).$m)"
    }
    $output = $output + $out
}
$output | Format-List
#>

$vbrTapeVaults = Get-VBRTapeVault
$counter = @(0..$($($($vbrTapeVaults).count)-1))
#$output = New-Object -TypeName PSCustomObject
$output = @()
foreach ( $c in $counter ){
    $members = $vbrTapeVaults | Get-Member | Where-Object -Property "MemberType" -eq "Property" | Select-Object -ExpandProperty "Name"
    $out = New-Object -TypeName PSCustomObject
    foreach ($m in $members ){
        $out | Add-Member -Name "$m" -MemberType NoteProperty -Value "$($($vbrTapeVaults[$c]).$m)"
    }
    #$output | Add-Member -Name "$($($vbrTapeVaults[$c]).Id)" -MemberType NoteProperty -Value $out
    $output = $output + $out
    
}

