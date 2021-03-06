Write-Host "Please enter Veeam Credentials"
$cred = (Get-Credential)

Add-PSSnapin VeeamPSSnapin

Connect-VBRServer -server "localhost" -Credential $cred

$out = @()
foreach ( $j in $(Get-VBRJob) ) { 
    $out = $out + "$($j.JobType) // $($j.name) // $($j.uid)"
    $out = $out + ( Get-VBRJobObject -Job "$($j.uid)" | `
        Select-object -Property Name) 
} 

$out | Out-file  "~\Desktop\ProtectedVMs.txt"