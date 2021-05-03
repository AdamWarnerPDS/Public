### Declarations

##Credentials
# On Secure string for credential:
# https://pscustomobject.github.io/powershell/howto/Store-Credentials-in-PowerShell-Script/
# https://interworks.com/blog/trhymer/2013/07/08/powershell-how-encrypt-and-store-credentials-securely-use-automation-scripts/
# Each secure string only works when run from the generating user on the generating machine
# Generate the value $EncryptedPassword using Generate-SecureCredential.ps1 located at https://github.com/AdamWarnerPDS/OneOffs/blob/master/Generate-SecureCredential.ps1
[string]$UserName = "pdstsc@mastershvac.com"

# TESTING: This $EncryptedPassword value only works when run from pds\awarner on pds\P02-3703
#[string]$EncryptedPassword = "01000000d08c9ddf0115d1118c7a00c04fc297eb0100000024f0ee222d359a44abae4fd92861cbc60000000002000000000003660000c00000001000000053e55a7f209cc0d690e786f1242146930000000004800000a0000000100000006f69bcb44ce6b5440ed6104135c3686320000000f41a5531750dfcdf540ae189624304074daca073b883ccdf92becf268bba2e5f1400000019201bac12108be17e04a7f891af2a673db00c3b"

# PRODUCTION: This $EncryptedPassword value only works when run from mastershvac\pdstsc on dc2.mastershvac.com
[string]$EncryptedPassword = "01000000d08c9ddf0115d1118c7a00c04fc297eb010000007b8602eeaa8aa241a9d6647b50df492a0000000002000000000003660000c00000001000000025d09e8a5969cda6840e564b259afcdc0000000004800000a0000000100000006e700da7632b153176385b8d3ea50a4c200000002327e989fe9392c3b454b952a4a36b300ad8e87283fd8a58af8803e739e35a9f14000000442dbaf248647242dc196fdb615eecdc835eaac6"

## GroupWise Filtering
# Group to filter down to
# Dist group "mastersusers"
$FilterGroupOID = "9dd6e76c-7077-45e7-831c-7477efd66a90"


## Exclusions
$ExcludedUsers = @("pdstsc@mastershvac.com")

## Misc
# Nulling $Result
$Result = [ordered]@{}

### Main Loop

#Check for MSOnline module
$Modules=Get-Module -Name MSOnline -ListAvailable
if($Modules.count -eq 0)
{
  Write-Host  Please install MSOnline module using below command: `nInstall-Module MSOnline  -ForegroundColor yellow
  Exit
}

# Credential logic
$SecureStringPassword = ConvertTo-SecureString -String "$EncryptedPassword"
$credentialObject = New-Object System.Management.Automation.PSCredential ($UserName, $SecureStringPassword)

Connect-MsolService -Credential $credentialObject

# Check login success
Get-MSolDomain -ErrorAction SilentlyContinue > $null
if($?) { 
        Write-Host "Successfully connected to O365 `n"
}
Else {
        Write-Host "Unable to connect to O365; check credentials or connectivity"
        Exit
}

# Generate list of users to keep based on $FilterGroupOID
$UsersToKeep = (Get-MsolGroupMember -GroupObjectID "$FilterGroupOID").EmailAddress

# Gathering and sorting information
# NOTE: This is really just a one-liner, mind the ` s at the end of each line
$Result = `
(get-msoluser -All | `
    Where-Object {$_.StrongAuthenticationRequirements.State -ne 'Enforced' `
            -and  $_.IsLicensed -eq $true `
            -and ( $_.UserType -like "Member" -or $_.UserType -like "Other") `
            -and $_.UserPrincipalName -in $UsersToKeep `
            -and $_.UserPrincipalName -notin $ExcludedUsers } | `
    Select-Object DisplayName,UserPrincipalName,StrongAuthenticationRequirements.State)

# TESTING modifier: comment or delete for production
#$Result = ( get-msoluser -all | Select-Object DisplayName,UserPrincipalName,StrongAuthenticationRequirements.State )


# Text to display if there are resultant users
$Body = @"
=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+

The following users were found to not have MFA enabled
please service as appropriate

=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
$($Result | Select-Object DisplayName,UserPrincipalName | Out-String)
"@

# Text to display if there are no resultant users
$NoUsersBody = @"
=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+

No users were found to have MFA disabled

=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
"@

# Always returns 0 if you don't include the ".UserPrincipalName." presumably because $Result is a complex object
if ( $Result.UserPrincipalName.Count -gt 0 ) {
Write-Host "$Body"
}
elseif ( $Result.UserPrincipalName.Count -eq 0 ) {
        Write-Host "$NoUsersBody"
}