#Get-WmiObject win32_computersystem -ComputerName 192.168.161.5 | Select-Object Name



$ips = @(
    "10.2.35.47",
    "10.2.35.35",
    "10.2.35.30",
    "10.2.35.22",
    "10.2.35.46",
    "10.2.40.140",
    "10.2.40.173",
    "10.2.35.26",
    "10.2.35.50",
    "10.2.35.33",
    "10.1.7.224",
    "10.2.35.20",
    "10.2.40.105",
    "10.2.40.102",
    "10.2.40.80",
    "10.2.35.43",
    "10.2.35.44",
    "10.2.40.61",
    "10.2.40.74",
    "10.2.35.28",
    "10.2.50.24",
    "10.2.50.21",
    "10.2.35.24",
    "10.1.8.50",
    "10.2.40.57",
    "10.2.35.27",
    "10.2.40.91",
    "10.2.80.10",
    "10.2.35.38",
    "10.2.35.21",
    "10.2.35.36",
    "10.2.35.34",
    "10.2.40.168",
    "10.2.40.58",
    "10.2.40.154",
    "10.2.40.52",
    "10.2.80.11",
    "10.2.35.39",
    "10.1.8.187",
    "10.2.35.23",
    "10.2.40.85")

$export = @()


foreach ( $i in $ips ) {
    $outputObject = New-Object psobject
    $outputObject | Add-Member -MemberType NoteProperty -Name "Hostname" -Value "blank" -Force
    $outputObject | Add-Member -MemberType NoteProperty -Name "IP" -Value "blank" -Force

    $outputObject.IP = "$i"
    $outputObject.Hostname = $( Get-WmiObject win32_computersystem -ComputerName "$i" | Select-Object Name ).Name
    $export = $export + $outputObject
    Write-Host "$($outputObject.Hostname) = $($outputObject.IP)"
}

$export | Export-Csv -path .\HostnameLookup.csv -NoTypeInformation