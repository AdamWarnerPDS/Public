<#
Get-WinEvent -FilterHashtable @{logname='security; id='4624'}


$xpath = "*[EventData[TargetUserName=$username]]"

#>

# Find DC list from Active Directory
$DCs = Get-ADDomainController -Filter *
 
# Define time for report (default is 1 day)
$startDate = (get-date).AddDays(-1)


# File name and location with $StartDate
$FileName = "C:\Temp\LogonEvents" + $startDate.ToString('MMddyy') + ".csv"
 
# Store successful logon events from security logs with the specified dates and workstation/IP in an array
foreach ($DC in $DCs){
$slogonevents = Get-Eventlog -LogName Security -ComputerName $DC.Hostname -after $startDate | where {$_.eventID -eq 4624 } | Export-Csv $FileName -Append -NoTypeInformation}

