
param (
    [Parameter(#Mandatory=$true
    )]
    [string]
    $infectedReport = "P02-3703_20201104-103223_infected_Data.csv",

    [Parameter(#Mandatory=$true
    )]
    [string]
    $cleanReport = "P02-3703_20201104-095538_clean_Data.csv",

    [Parameter()]
    [string]
    $badSuffix = "*.3ncrypt3d",

    [Parameter()]
    [string]
    $outDir = '.\',

    [Parameter(#mandatory=$true
    )]
    [string]
    $hostname = "somecomputer"

)

## Static Values, don't change these
#$hostname = $env:COMPUTERNAME
$dateTime = (Get-Date -Format yyyyMMdd-HHmmss )
$outPrefix = "$dateTime" + "_" + "$hostname"
# Output filenames
$outFileName = "$outPrefix" + "_FileComparisonReport.csv"
$outPath = "$outDir" + "$outFileName"


# Import data from infected computer and differentiate header
## Order of headers matters!!  It must match the order of the input file
$infectedHeader = @(
    "I_Name"
    ,"I_FullPath"
    ,"I_Length"
    ,"I_CreationTime"
    ,"I_LastWriteDateTime"
    ,"I_LastWriteDateStamp"
    ,"I_LastWriteTimeStamp"
    ,"I_Encrypted"
    ,"I_Newer"
    ,"I_OrigName"
    ,"I_OrigFullPath"
)
$infectedFiles = @()
$infectedFiles = Import-CSV $infectedReport -Header $infectedHeader
# Make the array mutable
$infectedFiles = [System.Collections.ArrayList]$infectedFiles
# Remove original headers
$infectedFiles.RemoveAt(0)
#make the array immutable again
$infectedFiles = [array]$infectedFiles

# Import data from clean computer and differentiate header
## Order of headers matters!!  It must match the order of the input file
$cleanHeader = @(
    "C_Name"
    ,"C_FullPath"
    ,"C_Length"
    ,"C_CreationTime"
    ,"C_LastWriteDateTime"
    ,"C_LastWriteDateStamp"
    ,"C_LastWriteTimeStamp"
    ,"C_Newer"
)
$cleanFiles = @()
$cleanFiles = Import-CSV $cleanReport -Header $cleanHeader
# Make the array mutable
$cleanFiles = [System.Collections.ArrayList]$cleanFiles
#remove original headers
$cleanFiles.RemoveAt(0)
#make the array immutable again
$cleanFiles = [array]$cleanFiles

$allFiles = @()
$allFilesHeader = $infectedHeader + $cleanHeader
#$allFiles = $infectedHeader + $cleanHeader #adding the headers like this to $allFiles resulted in erroneous end output

[int]$count = 0

foreach ( $i in $infectedFiles) {
    $count++
    Write-Progress -Activity "Processing files" -CurrentOperation "$count of $($infectedFiles.Length) - $($i.I_Name)" -PercentComplete ($count/$infectedFiles.Length*100)

    # Create the loop output buffer and it's headers
    $outputObject = New-Object psobject
    foreach ($h in $allFilesHeader){
        $outputObject | Add-Member -MemberType NoteProperty -Name "$h" -Value "empty"
    }

    # Process Encrypted files
    if ($i.I_Encrypted -eq "True") {
        
        # Generate original file names for comparison
        $i.I_OrigFullPath = $i.I_FullPath.TrimEnd("$badSuffix")
        $i.I_OrigName = $i.I_Name.TrimEnd("$badSuffix")

        # Match to 'same' file from clean server
        foreach ( $c  in $cleanFiles ) {
            if ( $i.I_OrigFullPath -eq $c.C_FullPath ) {
                foreach ( $ih in $infectedHeader ) {
                    $outputObject.$ih = $i.$ih
                }
                foreach ( $ch in $cleanHeader ) {
                    $outputObject.$ch = $c.$ch
                }
            }
            # If no match, add the infected data anyway
            else {
                foreach ( $ih in $infectedHeader ) {
                    $outputObject.$ih = $i.$ih
                }
            }
        }
    }

    # Process remaining matching files
    else {
        # Match to 'same' file from clean server
        foreach ( $c  in $cleanFiles ) {
            if ( $i.I_FullPath -eq $c.C_FullPath ) {
                foreach ( $ih in $infectedHeader ) {
                    $outputObject.$ih = $i.$ih
                }
                foreach ( $ch in $cleanHeader ) {
                    $outputObject.$ch = $c.$ch
                }
            }
        }
    }

    # Process non matching infected file
    if ( $outputObject.I_FullPath -eq "empty"){
        foreach ( $ih in $infectedHeader ) {
            $outputObject.$ih = $i.$ih
        }
    }
    
    # Place this loop's gathered output into end output
    $allFiles = $allFiles + $outputObject
    #exit
    # Reset this loop's gathered output
    $outputObject = $null
}

Write-Host "Outputting to $outPath"
$allFiles | Export-CSV -Path "$outPath" -NoTypeInformation -Force
