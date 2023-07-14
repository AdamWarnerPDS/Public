$IPs = ("50.62.223.155")
$Names = ("docspot","doc-cares","compass")
$servers = ("docfs01.docreit.com","docdc01.docreit.com")
$zone = "docreit.com"
$TTL = "00:05:00"
$oldIP = ("15.197.142.173","3.33.152.147")

function Change-DNSRecords {
    # Remove old entries
    foreach ( $n in $Names ) { foreach ( $o in $oldIP ) { Remove-DnsServerResourceRecord -ZoneName "$zone" -Name "$n" -RRtype "A" -RecordData "$o" }}

    # Add new entries
    foreach ($n in $names ) { ForEach ($i in $IPs) { Add-DnsServerResourceRecord -ZoneName "$zone" -A -Name "$n" -IPv4Address "$i" -TimeToLive $TTL }}
}

function Verify-DNSRecords {
    foreach ( $s in $servers ) { Write-Host "From $s" ; Get-DnsServerResourceRecord -ZoneName "$zone" -ComputerName "$s" | Where-Object {$_.HostName -in $Names} | FL }
}

$selection = Read-Host -Prompt "(C)hange DNS records, (V)erify records, (Q)uit"
switch ($selection) {
    C {Change-DNSRecords}
    V {Verify-DNSRecords}
    Q {Exit}
}