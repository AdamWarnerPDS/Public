[CmdletBinding()]
param (
    # Define what action to take
    [Parameter()]
    [String]
    $action = "Refresh",

    # Define target cameras
    [Parameter()]
    [array]
    $targets = @("192.168.66.66","1.2.3.4","5.6.7.8","host.domain.tld"),

    # Parameter help description
    [Parameter()]
    [String]
    $clipSource = "C:\users\awarner\Downloads\SentaraClips\",

    # Toggle use of SSL
    [Parameter()]
    [bool]
    $useSSL = $true,

    # Toggle Ignore Certificate Errors
    [Parameter()]
    [bool]
    $ignoreCertificateErrors = $false,

    # Toggle Verbose Output
    [Parameter()]
    [bool]
    $outputVerbose = $true,

    # Toggle Debug Output
    [Parameter()]
    [bool]
    $outputDebug = $true

)
# Variable Resets and declarations
Clear-Variable baseUris -Scope script
$script:baseUris = @()

$cameraCredential = Get-Credential


# Set Verbose Preference
if ( $outputVerbose -eq $true ) {
    $VerbosePreference = "Continue"
}

# Set Debug Preference
if ( $outputDebug -eq $true ) {
    $DebugPreference = "Continue"
}

# Generate list of uris to parse.  Outputs $script:baseUri
function New-HostIndex {
    [CmdletBinding()]
    param (
        # URI list from script param
        [Parameter(ValueFromPipeline=$true)]
        [string[]]
        $uri
    )
 
    process {
        foreach ( $u in $uri ) {
            Clear-Variable fullUri
            Write-Debug "Processing $u"
            if ( $script:useSSL -eq $true ) {
                $fullUri = 'https://' + "$u"
                $script:baseUris += "$fullUri"
            }
            elseif ( $script:useSSL -eq $false ) {
                $fullUri = 'http://' + "$u"
                $script:baseUris += "$fullUri"
            }
            Write-Debug "Added $fullUri to `$script:baseUris"
        }
    }
    
    end {
        Write-Verbose "Calculated `$script:baseUris to include:"
        $script:baseUris | Write-Verbose
    }
}

function Get-AudioClips {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        
    }
    
    process {
        
    }
    
    end {
        
    }
}

# Main Loop
New-HostIndex -uri $targets