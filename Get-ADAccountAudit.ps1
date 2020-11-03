###############################################################################
# Copywrite 2020 Paragon Development Systems
# Written by: Adam Warner
###############################################################################





<# #### Issue Tracker

=== Known Issues - Major ===

*Processing speed is somewhat slow, but speeding it up would require a massive refactor
** Too many nested loops, but they do allow this to be flexible

* The Get-ADPrincipalGroupMembership lines in the account processing loop fails if a group name has a slash ( / ) in it such as "Accounting / IS (EL&C)"
** This is a known bug in Get-ADPrincipalGroupMembership
** Not sure what to do about this one


=== Known Issues - Minor ===
* Script name should be more like Get-PrivilegedADAccounts.ps1, current name too broad
* Needs inline help
* $outdir is picky
* May want to add some sort of authentication mechanism for long term use
* Throws errors on child domains that lack groups like "Schema Admins" and "Infrastructure Admins"
* During the user processing loop, the occasional error "Get-ADUser: Object reference not set to an instance of an object" occurs
** This may be due to subdomains and searching on individual servers


# / Issue Tracker #>


param (
    [Parameter(mandatory=$true)]
    [string]
    $domain,
    
    [Parameter()]
    [string]
    $outDir = '.\',

    [Parameter()]
    [array]
    $groupsToCheck = @(
        "Domain Admins",`
        "Administrators",`
        "Enterprise Admins",`
        "Schema Admins",`
        "Server Operators",`
        "Backup Operators"
    )
)

# Safety nulls
$dnsRoot = ""
$pdcEmulator = ""

# Dont change these
$pdcEmulator = (Get-ADDomain "$domain").PDCEmulator
$dnsRoot = (Get-ADDomain "$domain").DNSRoot
$dateTime = (Get-Date -Format yyyyMMdd-HHmmss )
# Output filenames
$outDataName = "$dateTime" + "_" + "$dnsRoot" + "_PrivilegedADUsers.csv"
$outPath = "$outDir" + "$outFileName"
$outDataPath = "$outDir" + "$outDataName"


<#    MOVED TO PARAMS, NOT SURE IT WILL WORK
$groupsToCheck = @(
    "Domain Admins",`
    "Administrators",`
    "Enterprise Admins",`
    "Schema Admins",`
    "Server Operators",`
    "Backup Operators"
)
#>

# pre-null
$adminListRaw = @()
$adminList = @()
$adminInfo = @()
$adminGroups = @()
$i = 0
# Grab all admins
foreach ( $g in $groupsToCheck ) {
    $i ++
    Write-Progress -Activity "Checking group membership in $dnsRoot" -CurrentOperation "Processing $g, $i of $($groupsToCheck.Length)" -PercentComplete ($i/$groupsToCheck.Length*100)
    $members = @()
    $members = (Get-ADGroupMember -Identity "$g" -Server $pdcEmulator -Recursive).SamAccountName
    $adminListRaw = $adminListRaw + $members

    # Making a quick to process list of each groups members for determining individual priv group membership later
    $gName = ($g -replace '\s','')
    $adminGroups = $adminGroups + $gName
    New-Variable -Name "$gName" -Value @() -Force
    # index 0  of the array is the unadulterated group name (ie: Domain Admins)
    (Get-Variable -Name "$gName").Value += $g
    # indexs 2 to infinity of the array are actual members
    (Get-Variable -Name "$gName").Value += $members
}

# Scrub raw of duplicates
$adminList = $adminListRaw | Select-Object -Unique

# This controlls all properties that are logged
$userProperties = @(
    "SamAccountName"`
    ,"DisplayName"
    ,"GivenName"`
    ,"SurName"`
    ,"CanonicalName"`
    ,"DistinguishedName"`
    ,"mail"`
    ,"Description"`
    ,"LockedOut"`
    ,"Enabled"`
    ,"PasswordNotRequired"`
    ,"PasswordNeverExpires"`
    ,"AccountExpirationDate"`
    ,"whenCreated"`
    ,"WhenChanged"`
    ,"PasswordLastSet"`
    ,"LastLogonDate"`

)

# These were pulled from $userProperties as they may not be useful
<#
    ,"userAccountControl"`
    ,"DoesNotRequirePreAuth"
    ,"accountExpires"`
#>

# Make $userProperties a nice string for the "Process user properties loop below"
[string]$userPropertiesString = ""
foreach ( $p in $userProperties ) {
    $userPropertiesString = $userPropertiesString + '"' + $p + '",'
}
$userPropertiesString = $userPropertiesString -replace ".$"

$output = @()
$i = 0
foreach ( $a in $adminList ) {
    $i ++
    Write-Progress -Activity "Processing user accounts in $dnsRoot" -CurrentOperation "$a, $i of $($adminList.Length)" -PercentComplete ($i/$adminList.Length*100)
    $adminRaw = $null
    $adminInfo = New-Object PSCustomObject
    $adminRaw = (Get-ADUser -Filter {SamAccountName -eq $a} -Properties * -Server $pdcEmulator)
    # Deals with subdomain issues
    if ($adminRaw -ne $null ) {
        # Get Group Membership for user
        $groups = @()
        $groupsString = ""
        $groups = Get-ADPrincipalGroupMembership -Identity "$a" -Server $pdcEmulator -| Select-Object SamAccountName
        # Turn group results into a ; separated string
        foreach ( $g in $groups ) {
            $groupsString = $groupsString + "$($g.SamAccountName)" + ";"
        }
        # Removes final ;
        $groupsString = $groupsString -replace ".$"

        # Break out privileged groups
        $userAdminGroups = @()
        foreach ( $g in $adminGroups ) {
            if ("$a" -in $(Get-Variable $g).Value ){
                # uses idex 0 of the array for unadulterated group name
                $userAdminGroups = $userAdminGroups + $(Get-Variable -Name "$g").Value[0]
                Write-Host "$a in $($(Get-Variable -Name "$g").Value[0])"
            }
        }
        $adminGroupsString = ""
        # Transform to string
        foreach ($a in $userAdminGroups) {
            $adminGroupsString = $adminGroupsString + "$a" + ";"
        }
        # Remove final ;
        $adminGroupsString = $adminGroupsString -replace ".$"

        # Process user properties, uses the $userProperties from declarations to determine what fields to add.  This is dynamic, edit $userProperties to add or remove items
        foreach ( $p in $userProperties ){
            $adminInfo | Add-Member -MemberType NoteProperty -Name "$p" -Value $adminRaw."$p" -Force
        }
        $adminInfo | Add-Member -MemberType NoteProperty -Name "Groups" -Value "$groupsString" -Force
        $adminInfo | Add-Member -MemberType NoteProperty -Name "PriviledgedGroups" -Value "$adminGroupsString"

        $output = $output + $adminInfo

    }    
}

Write-Host "Outputting report to $outDataPath"
$output | Export-CSV -NoTypeInformation "$outDataPath"
