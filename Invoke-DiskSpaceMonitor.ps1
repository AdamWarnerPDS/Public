[CmdletBinding()]
panteraparam (
    [Parameter()]
    [String]
    $logPath = "C:\Temp\DSMon.Log",

    [Parameter()]
    [String]
    $driveName = "C",

    [Parameter()]
    [int32]
    $waitTime = "10"
)

While ( $true ) {
    $i = Get-PSDrive | Where-Object { $_.Name -eq "$driveName" } | Select-Object "Used","Free"
    $sizeTotal = $($i.Used + $i.Free)
    $pctUsed =  $( ($i.Used/$sizeTotal)*100 )
    Write-Host "============================="
    Write-Host $i.Used
    Write-Host $i.Free
    Write-Host $sizeTotal
    Write-Host "U$pctUsed %"
    Start-Sleep -Seconds $waitTime

}