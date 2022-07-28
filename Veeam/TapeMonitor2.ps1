$tapeJobs = Get-VBRTapeJob
$counter = @(0..$($($($tapeJobs).count)-1))
#$output = @()
$output = New-Object -TypeName PSCustomObject
foreach ( $c in $counter ){
    $members = $tapeJobs | Get-Member | Where-Object -Property "MemberType" -eq "Property" | Select-Object -ExpandProperty "Name"
    $out = New-Object -TypeName PSCustomObject
    foreach ($m in $members ){
        $out | Add-Member -Name "$m" -MemberType NoteProperty -Value "$($($tapeJobs[$c]).$m)"
    }
    $output | Add-Member -Name "$($($tapeJobs[$c]).Id)" -MemberType NoteProperty -Value $out
    $output
    #$output = $output + $out   
}
$output

$selectedProperties = @(
    "Name",
    "Id",
    "LastResult",
    "LastState",
    "Enabled"
)



# Gets information from last tape job(s?)
Get-VBRSession -Job $(Get-VBRTapeJob) -Last | Select -expand Log | Where -Property Status -EQ Warning





