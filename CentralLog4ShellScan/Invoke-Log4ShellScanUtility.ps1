<#
.SYNOPSIS
    Gathers computers from an AD domain and scans them with the Arctic Wolf Log4Shell detection script
.DESCRIPTION
    Gathers computers from an AD domain and scans them with the Arctic Wolf Log4Shell detection script
.EXAMPLE
    PS C:\> .\Invoke-Log4ShellScanUtility.ps1 -targetOU "OU=Servers,OU=Test,DC=domain,DC=tld" -verbosity 2 -outputLocation "\\MyComputer.domain.tld\scans\" -icCredential $cred
    Scans computers in the domain.tld/Test/Servers OU, outputting the scan results to the "\\MyComputer.domain.tld\scans\" directory, using a credential provided by $cred = Get-Credential.  Prints verbosity at level 2 for debugging or tracking
.INPUTS
    Only Parameters
.OUTPUTS
    Only JSON files at $outputLocation
.NOTES
    General notes
#>

[CmdletBinding()]
param (
    # Target Domain to scan, default is domain of the computer running this script.  Value should resemble "domain.tld"
    [Parameter()]
    [string]
    $targetDomain = "",

    # Target OU to scan, default is entire domain. This parameter excludes the use of $singleComputerTarget.  Value should resemble "OU=Servers,OU=Test,DC=domain,DC=tld"
    [Parameter()]
    [string]
    $targetOU = "",

    # Toggle refresh of script from remote download location? default is $true
    [Parameter()]
    [string]
    $refreshScript = "",

    <# Old Util aw scan script
    # Location to download scan script from; default is 
    # https://raw.githubusercontent.com/AdamWarnerPDS/Public/master/CentralLog4ShellScan/Invoke-AW-log4shell_detection.ps1
    [Parameter()]
    [string]
    $scanScriptRemoteLocation = "https://raw.githubusercontent.com/AdamWarnerPDS/Public/master/CentralLog4ShellScan/Invoke-AW-log4shell_detection.ps1",
    #>

    # Location to download scan script from; default is 
    # https://raw.githubusercontent.com/AdamWarnerPDS/Public/master/CentralLog4ShellScan/Invoke-AW-log4shell_detection.ps1
    [Parameter()]
    [string]
    $scanScriptRemoteLocation = "https://raw.githubusercontent.com/AdamWarnerPDS/Public/master/CentralLog4ShellScan/Invoke-AW-log4shell_detectionV2.ps1",

    # Location to save scan script to and run from; default is .\Invoke-AW-log4shell_detection.ps1
    [Parameter()]
    [string]
    $scanScriptLocalLocation = ".\Invoke-AW-log4shell_detectionV2.ps1",

    # Where on the network to write output
    [Parameter()]
    [string]
    $outputLocation = "\\computer.tld\share\",

    # What directory on the remote computers should the json be written to. Default is "c:\temp\"
    [Parameter()]
    [string]
    $remoteComputerJsonDir = "C:\temp\",

    # Increases console verbosity.  None=0, higher numbers for additional. Unknown ceiling
    [Parameter()]
    [int32]
    $verbosity = 0,

    # Credential to run remote commands as.  
    # Either input a credential object previouly gathered with something like 
    # $cred = Get-Credential, or input one when prompted at at runtime
    [Parameter()]
    [PSCredential]
    $icCredential,

    # To scan only one computer, use this parameter.  Enter a fqdn "computer.domain.tld".  This parameter excludes the use of $targetOU
    [Parameter()]
    [String]
    $singleComputerTarget = $null,

    # How many concurent parallel scans to run at a time; default is 25
    [Parameter()]
    [int32]
    $throttleLimit = 25
)
# Enable verbose output
if ( $verbosity -ge 1 ){
    $oldVerbosePreference = $verbosePreference
    $VerbosePreference = "continue"
}

# Prompt for credential if a credential object is not presented in param -icCredential
if ( $icCredential -eq $null ){
    $icCredential = $(Get-Credential)
}

# Function Declarations

function Invoke-VersionCheck() {
    $psVersion = (Get-Host | Select-Object -ExpandProperty Version).ToString().Split(".") 
    if ( $psVersion[0] -lt 7 ) {
        Write-Error -Message "This script requires powershell 7"
        Write-Host 'Install powershell 7; use the below command'
        Write-Host 'Invoke-Expression "& { $(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') }"'
        Exit 1
    }
}

function Get-ScanScript() {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri "$scanScriptRemoteLocation" -OutFile "$scanScriptLocalLocation" -ErrorAction Stop
    }
    catch {
        Write-Error "Could not download script from $scanScriptRemoteLocation"
        Exit 1
    }
}

function Test-OutputPath() {
    if ( $outputLocation -eq "\\computer.tld\share" ) {
        Write-Error -Message "Please specify a value for `$outputLocation"
        Exit 1
    }
    else {
        if ( $(Test-Path -Path $outputLocation) -eq $false ){
            Write-Error "$outputLocation does not exist, please create it"
            Exit 1
        }
        else {
            if ( $verbosity -ge 2){
                Write-Verbose "Verified desired output location $outputLocation exists"
            }
            if ( $verbosity -ge 1 ) {
                Write-Verbose "Writing output to $outputLocation"
            }
        }
    }
}

function Get-DomainComputersToScan() {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $domain = "",
        [Parameter()]
        [string]
        $OU = "",
        [Parameter()]
        [string]
        $singleComputer = $null
    )
    
    # Verify or fix dependancies
    if ( $((Get-WindowsCapability -Online | Where-Object -Property Name -like "ActiveDirectory").IsPresent) -eq $false ) {
        Add-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -Online
    }
    if ( $($OU) -and $($singleComputer) ){
        Write-Error "Select either `$targetOU, or `$singleComputerTarget.  You cannot use both"
        Exit 1
    }
    # Safety nulls
    $dnsRoot = ""
    $pdcEmulator = ""

    # Dont change these
    $pdcEmulator = (Get-ADDomain "$domain").PDCEmulator
    $dnsRoot = (Get-ADDomain "$domain").DNSRoot

    $allComputers = ((Get-ADComputer -Filter * -Server $pdcEmulator) | Select-Object DistinguishedName,DNSHostName )
    if ( $verbosity -ge 3 ) {
        Write-Verbose "`$allComputers contains $($allComputers.DNSHostName)"
    }
    if ( $($OU) ){
        $global:computers = ($allComputers | Where-Object { $_.DistinguishedName -match ".*$OU"})
        Write-Verbose "Searching in $domain, $OU"
        if ( $verbosity -ge 2 ) {
            Write-Verbose "`$global:computers contains $($global:computers.DNSHostName)"
        }
    }
    elseif ( $($singleComputer) )  {
        $global:computers = ($allComputers | Where-Object { $_.DNSHostName -match "$singleComputer"})
        Write-Verbose "Searching in $domain for $singleComputer"
        if ( $verbosity -ge 2 ) {
            Write-Verbose "`$global:computers contains $($global:computers.DNSHostName)"
        }
    }
    else {
        $fullDomainConfirm = (Read-Host "Are you sure you want to target the entire domain? Y/[N]")
        if ($fullDomainConfirm -eq "Y" -or $fullDomainConfirm -eq "y" ) {
            $global:computers = ($allComputers)
            Write-Verbose "Searching in $domain for all computers"
            if ( $verbosity -ge 2 ){
                Write-Verbose "`$global:computers contains $($global:computers.DNSHostName)"
            }
        }
        else {
            Write-Host "Exiting"
            Exit 1
        }




    }
    if ( $null -eq $computers ) {
        Write-Error "No matching computers found"
        Exit 1
    }

}

function Test-WinRMBulk() {
    $global:wsmanFailures = @()
    $global:computers.DNSHostName | Foreach-Object -Parallel -ThrottleLimit $throttleLimit {
        $wsmanSuccess = 0
        if ( $verbosity -ge 2 ){
            Write-Verbose "Testing WSMan on $_"
        }
        $authMethods = @("Negotiate","Kerberos","Default")
        foreach ( $a in $authMethods ) {
            if ( $verbosity -ge 2 ){
                Write-Verbose "Testing WSMan on $_ using $a authentication"
            }
            # Needs the ; $? to actually trigger the if statement result if true
            if ( $(Test-WSMan -ComputerName $_ -Authentication $a -ErrorAction Ignore -Credential $using:icCredential ; $?) -eq $true ){
                if ( $verbosity -ge 2 ){
                    Write-Verbose "Found WSMan on $_ using $a authentication"
                }
                $wsmanSuccess = 1
                break
            }
            else {
                if ( $verbosity -ge 1 ){
                    Write-Warning "Failed to detect wsman on $_ using $a authentication" -WarningAction SilentlyContinue
                }
            }
        }
        if ( $wsmanSuccess -ne 1 ){
            Write-Error "Unable to verify WSMan on $_"
            $global:wsmanFailures += "$_"
        }
    }
    if ( $global:wsmanFailures.Count -gt 0 ) {
        if ( $verbosity -ge 1) {
            Write-Warning "Failed to detect WSMan on the following computers, script may not have run on them" -WarningAction SilentlyContinue
            $global:wsmanFailures
        }
    }
    Else {
        Write-Host "Succesfully detected WSMan on all target hosts" -ForegroundColor Green
    }
    if ( $($global:computers.DNSHostName).count -le $($global:wsmanFailures).Count ) {
        Write-Error "Unable to connect to all target hosts"
        Exit 1
    }

}

function Start-Log4ShellScan() {
    # Re-declaring all these because of scopes
    # Local Use
    $sl = $global:scanScriptLocation
    # For $icArgs
    $ol = $outputLocation
    $jd = $remoteComputerJsonDir
    # Search Root, this should usually be an empty string
    $sr = ""
    $icCred = $icCredential
    $global:computers.DNSHostName | Foreach-Object -Parallel -ThrottleLimit $throttleLimit {
        # Output filename.  Below should result in ~"computer.domain.tld_log4shell_detection.output.YYYY-MM-DDTHH.MM.SSSSSSS-TZoffset.json"
        $ofn = "$(Invoke-Command -ComputerName $_ -ScriptBlock { "$([System.Net.Dns]::GetHostByName($env:computerName).HostName)_log4shell_detection.output.$(Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }).json" } -Credential $using:icCred )"
        if ( !($ofn) ){
            Write-Error "Failed to generate `$ofn"
            Continue
        }
        # Mind the order of param in Invoke-AW-log4shell_detection.ps1
        $icArgs = @("$using:ol","$using:jd","$using:sr","$ofn")
        if ($verbosity -ge 2 ){
            Write-Verbose "`$ofn for $_ is $ofn"
            Write-Verbose "`$icArgs is $icArgs"
        }
        if ( $verbosity -ge 2 ){
            Write-Verbose "Scanning $_ using $using:sl and sending results to $using:ol"
        }
        Invoke-Command -ComputerName $_ -FilePath "$using:sl" -ArgumentList $icArgs -Credential $using:icCred
        # This was used for network based copy; it didn't work
        #$copyFromPath = "`\`\" + "$_" + "$($jd -split ':')[0]" + "$" + "$($jd -split ':')[1]" + "$ofn"
        $copyFromPath = "$using:jd" + "$ofn"
        $copyToPath = "$using:ol" + "$ofn"
        if ( $verbosity -ge 2 ){
            Write-Verbose "Copying $copyFromPath to $copyToPath"
        }
        # Does not seem to be triggering
        #Copy-Item -Path "$copyFromPath" -Destination $copyToPath
        $jsonFetchParameters = @{
            ComputerName = "$_"
            ScriptBlock = { Param ($icparam1) Get-Content -Path $icparam1 }
            Credential = $using:icCred
            ArgumentList = "$copyFromPath"
        }
        <# Don't work
        $gcArgs = @("$copyFromPath")
        $out = "$(Invoke-Command -ComputerName $_ -ScriptBlock { Get-Content $args[0]} -ArgumentList $gcArgs -Credential $using:icCred)"
        #>
        $out = "$(Invoke-Command @jsonFetchParameters)"
        $out | Out-File -FilePath $copyToPath
    }
}

# Main Loop
Write-Verbose "Executing Invoke-VersionCheck"
Invoke-VersionCheck
if ( $refreshScript -eq $true -or $(Test-Path $scanScriptLocalLocation) -eq $false ) {
    Write-Verbose "Executing Get-ScanScript"
    Get-ScanScript
}

Write-Verbose "Executing Test-OutputPath"
Test-OutputPath
if ( $targetDomain -eq "") {
    $targetDomain = "$([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() | Select-Object -ExpandProperty Name)"
    Write-Verbose "`$targetDomain was `$null, changing it to $targetDomain"
}

Write-Verbose "Executing Get-DomainComputersToScan"
Get-DomainComputersToScan -domain "$targetDomain" -OU "$targetOU" -singleComputer "$singleComputerTarget"

Test-WinRMBulk
# Fixes differences between script param and Start-Log4ShellScan function as-written parameters; hacky, should be cleaned
$global:scanScriptLocation = $scanScriptLocalLocation
Start-Log4ShellScan
if ( $global:wsmanFailures.count -gt 0 ){
    Write-Host "Failed to detect WSMan on the following computers, script may not have run on them"
    $global:wsmanFailures
}

if ( $verbosity -gt 0){
    $verbosePreference = "$oldVerbosePreference"
}
