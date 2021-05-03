##################################################
### Copywrite 2020 Paragon Development Systems ###
### Written by Adam Warner                     ###
##################################################

# Check if connected to msolservice, connect if not connected
try {
    Get-MsolDomain -ErrorAction Stop > $null
}
catch {
    Write-Host "Not connected to MsolService, connecting"
    Connect-MsolService
}
<#
# Not needed at the moment
try { 
    Get-Mailbox -ErrorAction Stop > $null
}
catch {
    Write-Host "Not connected to ExchangeOnline, connecting"
    Connect-ExchangeOnline
}
#>
try {
    Get-AzureADDomain -ErrorAction Stop > $null
}
catch {
    Connect-AzureAD
}

[datetime]$passwordChangeTargetDate = "2021-02-22 18:28:00"

$azProperties = @("DisplayName","UserPrincipalName","LastPasswordChangeTimeStamp","BlockCredential")

$AzADUsers = Get-MsolUser -All `
    | Where-Object {$_.UserType -like "Member" -or $_.UserType -like "Other"} `
    | Select-Object $azProperties

$terminatedEmployess = Import-CSV "C:\Users\awarner\OneDrive - Paragon Development Systems\Client Work\FSMAD\2021-02-22 Breach\FSMAD_Terminated_Employees_2021-02-24T1208.csv"

# Collect Login audit logs, this takes a long time
#$AzureADAuditSignInLogs = $null
Write-Progress -Activity "Gathering Azure AD login audit logs" -Status "This takes time, please be patient"
$AzureADAuditSignInLogs = Get-AzureADAuditSignInLogs -All $True

$output = @()
$i = 0
foreach ( $u in $AzADUsers ) {
    # Pretty status display
    $i ++
    Write-Progress -Activity "Parsing users $i of $($AzADUsers.Count)" -Status "User $($u.UserPrincipalName)" -PercentComplete ($i/$($AzADUsers.Count)*100)

    # New temporary object for storing data in the loops
    $userOutput = New-Object PsCustomObject

    # Initial sub-object creation for all extracted AzAD object properties
    foreach ( $p in $azProperties ) {
        $userOutput | Add-Member -Name "$p" -MemberType NoteProperty -Value $($u.$p) -Force
    }
    
    <#
    Doesn't work!!!!!!! Reports some very old 'logon' times for users known to have logged on recently
    # Last login date using values from Get-MailboxStatistics
    # Get Primary Mailbox for the current user
    $primaryMailbox = $null
    $primaryMailbox = (get-msoluser -UserPrincipalName "$($u.UserPrincipalName)" `
        | Select-Object -Property ProxyAddresses `
        | Select-Object -ExpandProperty ProxyAddresses `
        | Where-Object { $_ -clike "SMTP:*" }) `
        -replace "SMTP:",""
    
    $userOutput | Add-Member -Name "LastLogon" -MemberType NoteProperty -Value $(Get-MailboxStatistics -Identity "$primaryMailbox" | Select-Object -ExpandProperty LastUserActionTime) -Force
    #>

    <#
    ## Generates too many requests; gets locked out
    # Create filter string for finding last logon time
    $lastLogonTimeFilterString = 'userPrincipalName eq ' + "'" + "$($userOutput.UserPrincipalName)" + "'"
    $lastLogonTimeFilterString
    $lastLogonTime = Get-AzureADAuditSignInLogs -Filter "$lastLogonTimeFilterString" -Top 1 | Select-Object -ExpandProperty CreatedDateTime
    Get-AzureADAuditSignInLogs -Filter "$lastLogonTimeFilterString" -Top 1 | Select-Object -ExpandProperty CreatedDateTime
    $userOutput | Add-Member -Name "LastLogon" -MemberType NoteProperty -Value "$lastLogonTime"
    #>

    # Get last time user logged on interactivly
    $lastLogonTime = $null
    $userLogons = $null
    $userLogons = $AzureADAuditSignInLogs | Where-Object { $_.UserPrincipalName -eq "$($userOutput.UserPrincipalName)" }
    if ( $null -ne $userLogons  ) {
        $lastLogonTime = ( $userLogons | Select-Object -Property CreatedDateTime | Sort-Object -Property CreatedDateTime -Descending)[0] | Select-Object -ExpandProperty CreatedDateTime 
        $lastLogonTime = Get-Date "$lastLogonTime" -UFormat %Y-%m-%dT%H:%M:%S%Z
        $userOutput | Add-Member -Name "LastLogon" -MemberType NoteProperty -Value "$lastLogonTime"
        $userOutput.LastLogon = [datetime]$userOutput.LastLogon
        $userOutput | Add-Member -Name "LogonLastIn30Days" -MemberType NoteProperty -Value "$True"
    }
    else {
        $userOutput | Add-Member -Name "LastLogon" -MemberType NoteProperty -Value "$null"
        $userOutput | Add-Member -Name "LogonLastIn30Days" -MemberType NoteProperty -Value "$False"
    }


    # Cast LastPasswordChangeTimeStamp to type datetime for comparison later
    $userOutput.LastPasswordChangeTimeStamp = [datetime]$userOutput.LastPasswordChangeTimeStamp

    # Compare LastPasswordChangeTimestamp against target datetime
    if ( $($userOutput.LastPasswordChangeTimeStamp) -lt  $passwordChangeTargetDate ) {
        $userOutput | Add-Member -Name "PasswordChangedCompliant" -MemberType NoteProperty -Value $False
    }
    else {
        $userOutput | Add-Member -Name "PasswordChangedCompliant" -MemberType NoteProperty -Value $True
    }

    # Match AzADUsers againts terminated employess spreadsheet
    if ( $u.UserPrincipalName -in  $($terminatedEmployess.userPrincipalName) ) {
        $userOutput | Add-Member -Name "terminated" -MemberType NoteProperty -Value $True
    }
    else {
        $userOutput | Add-Member -Name "terminated" -MemberType NoteProperty -Value $False
    }

    # Mark if terminated employee is not yet blocked
    if ( $userOutput.terminated -eq $True ) {
        if ( $userOutput.BlockCredential -eq $False ) {
            $userOutput | Add-Member -Name "LoginBlockCompliant" -MemberType NoteProperty -Value $False
        }
        elseif ( $userOutput.BlockCredential -eq $True ){
            $userOutput | Add-Member -Name "LoginBlockCompliant" -MemberType NoteProperty -Value $True
        }
    }
    else {
        $userOutput | Add-Member -Name "LoginBlockCompliant" -MemberType NoteProperty -Value "N/A"
    }

    # Get MFA Status
    $mfaStatus = Get-MSOLUser -UserPrincipalName $userOutput.UserPrincipalName `
        | Select-Object -ExpandProperty StrongAuthenticationRequirements `
        | Select-Object State
    $userOutput | Add-Member -Name "mfaStatus" -MemberType NoteProperty -Value "$($mfaStatus.state)"
    # Transform blank string (not to be confused with $null) to "Disabled"; looks nicer
    if ( $userOutput.mfaStatus -eq "" ) {
        $userOutput.mfaStatus = "Disabled"
    }

    # Automate action flags
    # Create properties
    $userOutput | Add-Member -Name "NeedsAction" -MemberType NoteProperty -Value $False
    $userOutput | Add-Member -Name "ActionNeeded" -MemberType NoteProperty -Value $null
    # Note if password change is needed, only if credential is not blocked
    if ( $userOutput.PasswordChangedCompliant -eq $False -and $userOutput.BlockCredential -eq $False ) {
        $userOutput.NeedsAction = $True
        $userOutput.ActionNeeded = "Change Password"
    }
    # Note if credential should be blocked
    if ( $userOutput.LoginBlockCompliant -eq $False ) {
        $userOutput.NeedsAction = $True
        $userOutput.ActionNeeded = "Block Credential"
    }
    # Note if MFA needs to be reviewed
    if ( $userOutput.mfaStatus -ne "Enforced" ) {
        # Ignore blocked users and AzAD Connect service accounts
        if ( $userOutput.BlockCredential -ne $True `
            -and $userOutput.LoginBlockCompliant -ne $False `
            -and $userOutput.DisplayName -ne "On-Premises Directory Synchronization Service Account"
            ){
            # if no other value in $userOutput.ActionNeeded, set to "Review MFA"
            if ( $null -eq $userOutput.ActionNeeded ) {
                $userOutput.ActionNeeded = "Review MFA"
            }
            # Append ", Review MFA" if there is a value in $userOutput.ActionNeeded
            else {
                $userOutput.ActionNeeded = $userOutput.ActionNeeded + ", Review MFA"
            }
            
        }
    }
    # Note for review if account may be disused/stale
    if ( $userOutput.LogonLastIn30Days -eq $False ) {
        if ( $userOutput.BlockCredential -ne $True `
            -and $userOutput.LoginBlockCompliant -ne $False `
            -and $userOutput.DisplayName -ne "On-Premises Directory Synchronization Service Account"
            ){
            if ( $null -eq $userOutput.ActionNeeded ) {
                $userOutput.ActionNeeded = "Review if account is stale"
            }
            # Append ", Review MFA" if there is a value in $userOutput.ActionNeeded
            else {
                $userOutput.ActionNeeded = $userOutput.ActionNeeded + ", Review if account is stale"
            }
        }
    }


    <#
    # Note the "-Force" parameters inside proceeding if statement, this is because we don't care about the password or blocking if the user is already blocked
    if ( $userOutput.BlockCredential -eq $True ) {
        $userOutput.NeedsAction = $False
        $userOutput.ActionNeeded = $null
    }
    #>
    
    $output += $userOutput
}

# Order of output determined by order of below array
$outputProperties = @(
    "DisplayName",
    "UserPrincipalName",
    "LastLogon",
    "LogonLastIn30Days",
    "LastPasswordChangeTimeStamp",
    "PasswordChangedCompliant",
    "terminated",
    "BlockCredential",
    "LoginBlockCompliant",
    "mfaStatus",
    "NeedsAction",
    "ActionNeeded"
)

# Reorder output
$output = $output | Select-Object -Property $outputProperties `
    | Sort-Object -Property UserPrincipalName

<#
ForEach ( $u in $AzADUsers.UserPrincipalName ) { if ( $u -in $($terminatedEmployess.userPrincipalName) ) { write-host "true" }}    


#>

