
$switchUris = @(
    "http://192.168.1.3/html/login.html",
    "http://192.168.1.4/html/login.html"
)

$firewallUris = @(
    "https://192.168.1.1"
)

function Poke-Switches {
    foreach ( $s in $switchUris ) {
        Invoke-WebRequest -URI "$u" | Out-Null
    }
    
}

function Poke-Firewalls {
    foreach ( $f in $firewallUris ) {
        Invoke-WebRequest -URI "$f" | Out-Null
    }
}

