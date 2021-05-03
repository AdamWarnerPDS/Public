# Skip Computer Accounts?
$skipComputerAccounts = $true

# Accounts to filter out
# NOT USED YET
<#
$accountsToSkip = @(
    "SYSTEM"
    )
#>

# Find DC list from Active Directory
$DCs = Get-ADDomainController -Filter *

# For targeting a specific DC and saving time
#$DCs = Get-ADDomainController -Filter {Hostname -eq "APC-DCconv.ampkcorp.com"}

# Output filenames
$outDir = ".\"
$dateTime = (Get-Date -Format yyyyMMdd-HHmmss )
$outDataName = "$dateTime" + "_" + "$($(Get-ADDomain).dnsroot)" + "_LogonEvents.csv"
$outPath = "$outDir" + "$outFileName"
$outDataPath = "$outDir" + "$outDataName"

# Define time for report (default is 1 day)
$startDate = (get-date).AddDays(-1)

# Store successful logon events from security logs with the specified dates and workstation/IP in an array
$di = 0
foreach ($DC in $DCs){
    $di ++
    Write-Progress -Activity  "Parsing DC's for logon events.  This takes time, please be patient" -Status "Querying $($DC.HostName) ; $di of $($DCs.Count)" -PercentComplete ($di/$DCs.Count*100)
    $slogonevents += Get-Eventlog -LogName Security -ComputerName $DC.Hostname -after $startDate | Where-Object { $_.eventID -eq 4624 }
}

# Output object
$output = @()

# Process all the raw data

$ei = 0
:parseLogonEvents foreach ($e in $slogonevents){
    $ei ++
    Write-Progress -Activity "Parsing logon events" -Status "$ei of $($slogonevents.count)" -PercentComplete ($ei/$slogonevents.Count*100)

    # Skips current loop iteration and begins with next item
    if ( $skipCOmputerAccounts -eq $true ) {
        # 
        if ( $($e.ReplacementStrings[5]) -like "*`$" ) {
            continue parseLogonEvents
        }
    }
    
    #new buffer obj
    $buffer = New-Object PSObject

    # Write majority of event data to buffer
    $buffer | Add-Member -MemberType NoteProperty -Name "LogonTime" -Value $($e.TimeGenerated)
    $buffer | Add-Member -MemberType NoteProperty -Name "User" -Value $($e.ReplacementStrings[5])
    $buffer | Add-Member -MemberType NoteProperty -Name "Domain" -Value $($e.ReplacementStrings[6])
    $buffer | Add-Member -MemberType NoteProperty -Name "SourceComputer" -Value $($e.ReplacementStrings[11])
    $buffer | Add-Member -MemberType NoteProperty -Name "SourceIP" -Value $($e.ReplacementStrings[18])

    # Gather LogonTypes and write buffer to output
    switch ($e.ReplacementStrings[8]) {
        2 { $buffer | Add-Member -MemberType NoteProperty -Name "LogonType" -Value "Interactive" ; $output = $output + $buffer ; break }
        3 { $buffer | Add-Member -MemberType NoteProperty -Name "LogonType" -Value "Network" ; $output = $output + $buffer ; break }
        5 { $buffer | Add-Member -MemberType NoteProperty -Name "LogonType" -Value "Service" ; $output = $output + $buffer ; break }
        10 { $buffer | Add-Member -MemberType NoteProperty -Name "LogonType" -Value "RemoteInteractive" ; $output = $output + $buffer ; break }
    }
}
$output | Export-CSV -Path "$outDataPath" -NoTypeInformation
