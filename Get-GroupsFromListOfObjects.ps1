$potentialGroups = Get-Content -Path .\groupsIn.txt

$out = @()

foreach ( $g in $potentialGroups ) {
    $groupInfo = $null
    $groupInfo = Get-ADGroup -Identity "$g"
    $outObj = New-Object psobject
    $outObj | Add-Member -MemberType NoteProperty -Name "SamAccountName" -Value $($groupInfo.SamAccountName)
    $outObj | Add-Member -MemberType NoteProperty -Name "DistinguishedName" -Value $($groupInfo.DistinguishedName)
    $outObj | Add-Member -MemberType NoteProperty -Name "ObjectClass" -Value $($groupInfo.ObjectClass)
    $outObj | Add-Member -MemberType NoteProperty -Name "GroupScope" -Value $($groupInfo.GroupScope)
    $outObj | Add-Member -MemberType NoteProperty -Name "ObjectGUID" -Value $($groupInfo.ObjectGUID)
    if ( $outObj.ObjectClass -eq "group" ){
        $out = $out + $outObj
    }

}

$out | Export-CSV -Path .\groupsOut.csv -NoTypeInformation