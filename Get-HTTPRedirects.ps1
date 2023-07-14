[CmdletBinding()]
param (
    # Target URI
    [Parameter()]
    [String]
    $URI = "",

    # What response code to start at.  Default is 200
    [Parameter()]
    [int]
    $TargetStatusCode = 200,

    # Maximum redirects before quitting
    [Parameter()]
    [int]
    $MaximumRedirects = 10
)

# Static variables, no touchy!
$CurrentRedirectNo = 0
$CurrentStatusCode = 0
$SuccessResponseCodes = (200..299)
$RedirectCodes = (300..399)
$ClientErrorCodes = (400..499)
$ServerErrorCodes = (500..599)
$InformationResponseCodes = (100..199)
$bar = "=" * 40

# Sanity check
if ( $URI -eq "" ) {
    Write-Host "Parameter `$URI is not set, exiting"
    Exit
}

# Check and display Server DNS
# Rip out domain name using regex.
$URI -match '(?<=^https\:\/\/|http\:\/\/)(?<fqdn>[a-zA-Z0-9\-\.]*)' | Out-Null
$fqdn = "$( $matches['fqdn'])"
Write-Host "$bar"
Write-Host "Domain information for $fqdn"
Resolve-DnsName $fqdn
Write-Host "`n"

Write-Host "$bar"
Write-Host "Redirects for $URI"
# Main loop
while ( $CurrentStatusCode -ne $TargetStatusCode -and $currentRedirectNo -lt $MaximumRedirects ) {
    # Reset cycling variables
    $CurrentStatusCode = 0
    $CurrentRedirLocation = ""
    $out = $null

    # Get Data
    try { 
        $out = $( Invoke-WebRequest -Method GET -Uri "$URI" -MaximumRedirection $CurrentRedirectNo -ErrorAction SilentlyContinue ) 
    }
    catch {
        # Suppresses and fixes "Invoke-WebRequest : Object moved to here." when pointing -MaximumRedirection 
        # switch at a response 200ish returning page
        $out = $( Invoke-WebRequest -Method GET -Uri "$URI" -ErrorAction SilentlyContinue ) 
    }

    # Output
    finally { 
        $CurrentStatusCode = $out.StatusCode
        $CurrentRedirLocation = "$($out.Headers.Location)"
        if ( $CurrentStatusCode -in $RedirectCodes ) {
            Write-Host "Hop $CurrentRedirectNo, Recieved code $CurrentStatusCode REDIRECTING to $CurrentRedirLocation"
        }
        elseif ( $CurrentStatusCode -in $ClientErrorCodes ) {
            Write-Host "Hop $CurrentRedirectNo, Recieved code $CurrentStatusCode indicating a CLIENT ERROR"
        }
        elseif ( $CurrentStatusCode -in $ServerErrorCodes ) {
            Write-Host "Hop $CurrentRedirectNo, Recieved code $CurrentStatusCode indicating SERVER ERROR"
        }
        elseif ( $CurrentStatusCode -in $SuccessResponseCodes ) {
            Write-Host "Hop $CurrentRedirectNo, Recieved code $CurrentStatusCode indicating SUCCESS"
        }
        elseif ( $CurrentStatusCode -in $InformationResponseCodes ) {
            Write-Host "Hop $CurrentRedirectNo, Recieved code $CurrentStatusCode indicating INFORMATION"
        }
        else {
            Write-Host "Hop $CurrentRedirectNo, Recieved code $CurrentStatusCode"
        }
        $CurrentRedirectNo = $CurrentRedirectNo + 1
    }
}

# Final Output
if ( $CurrentStatusCode -eq $TargetStatusCode -and $currentRedirectNo -le $MaximumRedirects ) {
    Write-Host "Hit target status code $TargetStatusCode, done!"
}
elseif ( $CurrentStatusCode -ne $TargetStatusCode -and $currentRedirectNo -ge $MaximumRedirects ) {
    Write-Host "Hit `$MaximumRedirects limit of $MaximumRedirects before hitting target status code of $TargutStatusCode"
}

Write-Host "Information on response codes can be found here: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status"