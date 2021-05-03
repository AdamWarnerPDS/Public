param (
    # domain to query, use a FQDN ie: subdomain.contoso.com
    [Parameter(mandatory=$true)]
    [string]
    $domain = ""
)


$exclusionsPath = '.\ExcludedUsers.csv'

$dateTime = (Get-Date -Format yyyyMMdd-HHmmss )
$outPath = '.\'
$outName = "NotExcludedUsers_" + "$domain" + "_" + "$dateTime" + ".csv"



# Safety nulls
$dnsRoot = ""
$pdcEmulator = ""

# Dont change these
$pdcEmulator = (Get-ADDomain "$domain").PDCEmulator
$dnsRoot = (Get-ADDomain "$domain").DNSRoot


$adusers = (Get-ADUser -Filter * -Properties SamAccountName,UserPrincipalName -Server $pdcEmulator)
$exclusions = Import-CSV -Path "$exclusionsPath"
$includedUsers = @()

foreach ( $u in $adUsers ) {
    $outputObject = New-Object psobject
    $outputObject | Add-Member -MemberType NoteProperty -Name "SamAccountName" -Value "blank" -Force
    $outputObject | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value "blank" -Force
    $outputObject | Add-Member -MemberType NoteProperty -Name "Name" -Value "blank" -Force
    #$outputObject | Add-Member -MemberType NoteProperty -Name "ExcludedBy" -Value "blank" -Force   
    
    if ( "$($u.SamAccountName)" -notin $($exclusions.SamAccountName) ) {
        if ( "$($u.UserPrincipalName)" -notin $($exclusions.UserPrincipalName)) {
            $outputObject.SamAccountName = "$($u.SamAccountName)"
            $outputObject.UserPrincipalName = "$($u.UserPrincipalName)"
            $outputObject.Name = "$($u.Name)"
            #$outputObject.ExcludedBy = "$($exclusions.source)"

            $includedUsers = $includedUsers + $outputObject
        }
    }
}

$includedUsers | Export-CSV -Path "$outPath$outName" -NoTypeInformation


