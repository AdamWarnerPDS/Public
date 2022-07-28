$waitingForTapeJobs = ( `
    Get-VBRTapeJob | `
    Where-Object -Property LastState -like WaitingTape | `
    Select-Object -ExpandProperty Name `
    )

 if ( $waitingForTapeJobs -ne $null ) {
    $waitingForTapeJobs = $waitingForTapeJobs.ToString()
 }
 else {
     $waitingForTapeJobs = "N/A"
 }
