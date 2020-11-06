$exclusionsPath = '.\ExcludedUsers.csv'

$dateTime = (Get-Date -Format yyyyMMdd-HHmmss )
$outPath = '.\'
$outName = "ExcludedUsers_$dateTime.csv"




$adusers = (Get-ADUser -Filter * -Properties SamAccountName,UserPrincipalName)
$exclusions = Import-CSV -Path "$exclusionsPath"
$includedUsers = @()

foreach ( $u in $adUsers ) {
    $outObject = New-Object psobject
    Add-Member -MemberType NoteProperty -Name "SamAccountName" -Value "blank" -Force
    Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value "blank" -Force
    Add-Member -MemberType NoteProperty -Name "ExcludedBy" -Value "blank" -Force   
    
    if ( "$($u.SamAccountName)" -notin "$($exclusions.SamAccountName)" ) {
        if ( "$($u.UserPrincipalName)" -notin "$($exclusions.UserPrincipalName)")
            $outputObject.SamAccountName = "$($u.SamAccountName)"
            $outputObject.UserPrincipalName = "$($u.UserPrincipalName)"
            $outputObject.ExcludedBy = "$($exclusions.source)"

            $includedUsers = $includedUsers + $outputObject
    }
}

Export-CSV -Path "$outPath$outName" -NoTypeInformation