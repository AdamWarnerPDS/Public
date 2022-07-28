<#
.SYNOPSIS
Parses some directory looking for file change times and 'bad' suffixes

.EXAMPLE
Get-FilesAndCheckForEncryptionOrAge.ps1 -opMode filterEncrypted -includeDirs "temp"


#>

###############################################
# Copywrite 2020 Paragon Development Systems
# Written by Adam Warner
###############################################

[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $driveRoot = "C:\",

    [Parameter()]
    [string]
    $opMode = "infected",

    [Parameter()]
    [string]
    $dirMode = "exclude",

    [Parameter()]
    [array]
    $includeDirs = @("Users"),

    [Parameter()]
    [array]
    $excludeDirs = @("Windows","Program FIles (x86)","Program Files","ProgramData"),

    [Parameter()]
    [string]
    $newerThreshold = "10/19/2020 12:00:00 AM",

    # Needs asterisk
    [Parameter()]
    [string]
    $badSuffix = "*.3ncrypt3d*",

    [Parameter()]
    [string]
    $ignoreSuffix = "*_help",

    # Needs single quotes
    [Parameter()]
    [string]
    $outDir = '.\',

    # may be nicer as a switch or boolean value
    [Parameter()]
    [string]
    $trimExtensions = "true",

    # Must be single quotes, doublequotes do not work with the -include parameter of gci
    # Wrapping in asterisks ( * ) allows for detection of encrypted versions
    # Each line is roughly by file classification (MS Word document, MS Excel document, Image, etc.) for easier tuning
    # More file types = more files = longer processing time, but larger catch
    [Parameter()]
    [array]
    $trimExtensionsList = @(
        '*.doc*','*.docx*','*.wbk*','*.dot*','*.docm*','*.dotx*','*.dotm*','*.docb*',
        '*.xls*','*.xlt*','*.xlm*','*.xlsx*','*.xlsm*','*.xlxt*','*.xltm*','*.xlsb*','*.xla*','*.xlam*','*.xlw*',
        '*.ppt*','*.pot*','*.pps*','*.pptx*','*.pptm*','*.potm*','*.ppsx*','*.sldx*','*.sldm*',
        '*.accdb*','*.accde*','*.accdt*','*.accdr*',
        '*.one*',
        '*.xps*','*.pdf*','*.txt*','*.html*','*.htm*','*.md*','*.csv*'
        '*.apng*','*.gif*','*.jpg*','*.jpeg*','*.jfif*','*.pjpeg*','*.pjp*','*.png*','*.svg*','*.webp*','*.bmp*','*.ico*','*.cur*','*.tiff*','*.raw*'
        '*.avif*','*.webm*','*.mpg*','*.mp2','*.mpeg*','*.mpe*','*.mpv*','*.ogg*','*.mp4*','*.m4p*','*.m4v*','*.avi*','*.mov*','*.qt*','*.flv*','*.swf*','*.avchd*'
        )
)

### Declarations

## Static Values, don't change these
$hostname = $env:COMPUTERNAME
$dateTime = (Get-Date -Format yyyyMMdd-HHmmss )
$outPrefix = "$hostname" + "_" + "$dateTime"
# Output filenames
$outFIleName = "$outPrefix" + "_FilesystemDump.csv"
$outDataName = "$outPrefix" + "_" + "$opMode" + "_Data.csv"
$outPath = "$outDir" + "$outFIleName"
$outDataPath = "$outDir" + "$outDataName"

# Convert date comparison to datetime
$newerThresholdDateTime = (Get-Date $newerThreshold)

### Main 'loop'

# Checking output directory
if ( (Test-Path $outDir) -ne $true ){
    Write-Error "Desired output directory `"$outDir`" is invalid, verify `$outDir parameter and try again"
    Exit
}

# Checking opMode param for validity
if (( $opMode -ne "infected" ) -and ( $opMode -ne "clean" ) -and ( $opMode -ne "filterEncrypted")) {
    Write-Error "Value $opMode for paramemter `$opMode is invalid, use either `"infected`", `"filterEncrypted`", or `"clean`" "
    Exit 1
}

# Getting list of directories to search
$dirs = Get-ChildItem -Path "$driveRoot" -Directory -ErrorAction SilentlyContinue

# dirMode Logic
if ( $dirMode -eq "exclude") {
    $trimDirs = $dirs | Where-Object {$_.Name -notin $excludeDirs }
}
elseif ( $dirMode -eq "include" ) {
    $trimDirs = $dirs | Where-Object {$_.Name -in $includeDirs }
}
else {
    Write-Error "Value $dirMode for parameter `$dirMode is invalid, use either `"exclude`" or `"include`""
    Exit 1
}

# Extension trim switch logic
if ($trimExtensions -eq "false") {
    $trimExtensionsList = '*'
}

# Gathering filenames and other metadata from found directories, then dumping to csv at $outPath
# Using 2 stages with a file buffer to try to keep memory down
ForEach ( $t in $trimDirs ) {
    Write-Progress -Activity "Collecting file information from $driveRoot$t"
    Get-ChildItem -Path "$driveRoot$t" -File -Include $trimExtensionsList -Recurse -ErrorAction SilentlyContinue `
    | Select-Object -Property Name,Length,CreationTime,LastWriteTime,LastAccessTime,{$_.VersionInfo.FileName},{$_.LastWriteTime.Date} `
    | Export-CSV -Path $outPath -Append 
    Write-Progress -Activity "Checking $driveRoot$t" -Completed
}
Write-Host "Raw data dumped to $outPath"

# Pulling raw data collected before
$checks = (Import-CSV $outPath)
# Adding new properties for our checks
$checks | Add-Member -MemberType NoteProperty -Name "FullPath" -Value "blank"
$checks | Add-Member -MemberType NoteProperty -Name "Encrypted" -Value "unknown"
$checks | Add-Member -MemberType NoteProperty -Name "Newer" -Value "unknown"
$checks | Add-Member -MemberType NoteProperty -Name "LastWriteDateStamp" -Value "unset"
$checks | Add-Member -MemberType NoteProperty -Name "LastWriteTimeStamp" -Value "unset"
$checks | Add-Member -MemberType NoteProperty -Name "LastWriteDateTime" -Value "unset"
# Creating index of values for the array to loop through, yes it's ugly, but it works
$checksMembersIndex = @(0..$checks.Length)

# Checking for suffix, comparing LastWriteTime, and prettying output
foreach ( $i in $checksMembersIndex ) {
    Write-Progress -Activity "Processing item $i of $($checks.Length)" -PercentComplete ($i/$checks.Length*100)
    # Ignore the "help" files
    if ( $checks[$i].Name -notlike $ignoreSuffix) {

        # Look for the encryption suffix
        if ( $checks[$i].Name -like "$badSuffix" ) { 
            $checks[$i].Encrypted = $true 
        } 
        Else { 
            $checks[$i].Encrypted = $false 
        } 
        # Check write time. This parses strings so may not be perfectly accurate as it's based on string comparison
        $dateObject = @()
        $dateObject = (Get-Date $checks[$i].LastWriteTime)
        If ( $checks[$i].LastWriteTime -gt $newerThresholdDateTime ) {
            $checks[$i].Newer = $true
        }
        Else {
            $checks[$i].Newer = $false
        }

        # Split LastWriteTime into date and time as these will be more usable in Excel
        $checks[$i].LastWriteDateStamp = ( $(($checks[$i]).LastWriteTime) -split " " )[0]
        $checks[$i].LastWriteTimeStamp = ( $(($checks[$i]).LastWriteTime) -split " " )[1]

        # Prettying up output
        $checks[$i].FullPath = ($checks[$i].'$_.VersionInfo.FileName')
        $checks[$i].LastWriteDateTime = $($checks[$i]).LastWriteTime
    }
}

# Final Output to $outDataPath
Write-Host "Exporting to $outDataPath"

if ( $opMode -eq "infected") {
    $checks `
        | Select-Object -Property Name,FullPath,Length,CreationTime,LastWriteDateTime,LastWriteDateStamp,LastWriteTimeStamp,Encrypted,Newer `
        | Export-CSV -Path "$outDataPath" -NoTypeInformation 
}
if ( $opMode -eq "filterEncrypted" ){
    $checks `
        | Where-Object {$_.Encrypted -eq "TRUE" } `
        | Select-Object -Property Name,FullPath,Length,CreationTime,LastWriteDateTime,LastWriteDateStamp,LastWriteTimeStamp,Encrypted,Newer `
        | Export-CSV -Path "$outDataPath" -NoTypeInformation 
}
if ( $opMode -eq "clean" ) {
    $checks `
        | Select-Object -Property Name,FullPath,Length,CreationTime,LastWriteDateTime,LastWriteDateStamp,LastWriteTimeStamp,Newer `
        | Export-CSV -Path "$outDataPath" -NoTypeInformation   
}

# Cleanup csv buffer file
Remove-Item $outPath -Force

