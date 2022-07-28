$fileDate = (Get-Date -Format yyyy-MM-ddTHH-mm-ss )
$fileName = "AuvikWatchdogMemory" + "_" + "$fileDate" + ".log"
$path = "c:\temp\"
$outPath = "$path" + "$fileName"
$sleepTime = 120 #seconds
$columns = "DateTime    PagedMemorySize CPU"
$columns | Out-File $outPath
While ( $true ){
    $dateTime = (Get-Date -Format yyyy-MM-ddTHH-mm-ss )
    $watchdogProcess = Get-Process -Name AuvikAgentService | Select-Object * | Where-Object {$_.Path -like "*AuvikWatchdogService.exe"}
    $out = "$dateTime" + "`t" + "$($watchdogProcess.PagedMemorySize)" + "`t" + "$($watchdogProcess.CPU)"
    $out | Tee-Object -FilePath "$outPath" -Append
    Start-Sleep -Seconds $sleepTime
}