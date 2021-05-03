param (
    # domain to query, use a FQDN ie: subdomain.contoso.com
    [Parameter(mandatory=$true)]
    [string]
    $domain = ""#,

    <#
    [Parameter(mandatory=$true)]
    [string]
    $testPath = "C:\AmericanPackingCo.ect"
    #>
)


$dateTime = (Get-Date -Format yyyyMMdd-HHmmss )
$outPath = '.\'
$outName = "FileTest_" + "$domain" + "_" + "$dateTime" + ".csv"
$outPathName = "$outPath" + "$outName"

# Safety nulls
$dnsRoot = ""
$pdcEmulator = ""

# Dont change these
$pdcEmulator = (Get-ADDomain "$domain").PDCEmulator
$dnsRoot = (Get-ADDomain "$domain").DNSRoot

$computers = (Get-ADComputer -Filter * -Server $pdcEmulator).DNSHostName

$output = @()
$i = 0

foreach ( $c in $computers ){
    $i ++ 
    Write-Progress -Activity "Testing for presence of file on remote computers" -Status "$i of $($computers.count)"
    $outputObject = New-Object psobject
    $outputObject | Add-Member -MemberType NoteProperty -Name "Computer" -Value "blank" -Force
    $outputObject | Add-Member -MemberType NoteProperty -Name "Present" -Value "blank" -Force
    $test = $null
    $test = (Invoke-Command -ComputerName "$c" -ScriptBlock { Test-Path "C:\AmericanPackingCo.ect" }  -ErrorAction SilentlyContinue)
    $outputObject.Computer = "$c"
    if ( $test -eq $true ) {
        $outputObject.Present = "TRUE"
    }
    elseif ( $test -eq $false ) {
        $outputObject.Present = "FALSE"
    }
    elseif ( $test -eq $null ) {
        $outputObject.Present = "DNT"
    }
    $output = $output + $outputObject
}

$output | Export-CSV -Path "$outPath$outName" -NoTypeInformation

