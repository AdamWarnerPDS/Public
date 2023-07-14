$cred = Get-Credential
$to = ""
if ( $to -eq "" ){
    $to = Read-Host -Prompt "Send to what address?"
}

$from = ""
if ( $from -eq "" ){
    $from = Read-Host -Prompt "Send from what address?"
}

$emailParam = @{
    Server =  "smtp.sendgrid.net"
    Port = 25
    From = "$from" 
    To = "$to"
    Subject = "SMTP Test"
    Credential = $cred    
    Text = "Test 1 2 3.  Hello?"
}

Write-Host "Using following parameters"
$emailParam

Send-EmailMessage @emailParam