[CmdletBinding()]
param (
    [Parameter()]
    [Boolean]$backupChrome = $true,
    [Parameter()]
    [Boolean]$backupFirefox = $true,
    [Parameter()]
    [Boolean]$backupEdge = $true,
    [Parameter()]
    [Boolean]$clobberCurrent = $false,
    [Parameter()]
    [String]$backupToPathSuffix = "\OneDrive - Paragon Development Systems\BookmarkBackup\",
    [Parameter()]
    [Array]$ignoreUsers = @("awadmin")
)

# Logged in Users - There must be a better way
$loggedInUsers = ( (Get-Process -IncludeUserName `
    | Select-Object -Property "UserName" `
    | Where-Object { `
        # Ignore system users
        $_.UserName -notlike "NT AUTHORITY*" `
        -and $_.UserName -ne $null `
        -and $_.UserName -notlike "Font Driver*" `
        -and $_.UserName -notlike "Window Manager*" `
    } `
    | Sort-Object -Property UserName `
    | Get-Unique -AsString `
    ) `
    | Foreach-Object {
        # Strip out domain
        $_.UserName.Split('\') `
        | Select-Object -Skip 1 `
    } `
# Where() method necessary because...reasons?  Where-Object not playing nice with -notin
).Where{ $_ -notin $ignoreUsers }



function Backup-ChromiumBookmarks {
    param (
        [Parameter()]
        [String]$UserName,
        [String]$chromeBackupToPath,
        [String]$edgeBackupToPath,
        [String]$flavor
    )
    # Chromium-type browser appdata dirs
    $chromeAppDataDir = "\AppData\Local\Google\Chrome\User Data\Default\"
    $edgeAppDataDir = "\AppData\Local\Microsoft\Edge\User Data\Default\"

    # Set paths 'dynamically', there is probably a cleaner way to do this but hey it works
    # Microsoft Edge  
    if ( $flavor -eq "Edge" ) {
        [string]$primaryLocation = "C:\Users\" + "$username" + "$edgeAppDataDir" + "Bookmarks"
        [string]$bakLocation = "C:\Users\" + "$username" + "$edgeAppDataDir" + "Bookmarks.bak"
        [string]$backupTo = $edgeBackupToPath
    }
    # Google Chrome
    elseif ( $flavor -eq "Chrome" ) {
        [string]$primaryLocation = "C:\Users\" + "$username" + "$chromeAppDataDir" + "bookmarks"
        [string]$bakLocation = "C:\Users\" + "$username" + "$chromeAppDataDir" + "bookmarks.bak"
        [string]$backupTo = $chromeBackupToPath
    }

    Write-Host "`$flavor is $flavor"
    Write-Host "`$backupTo is $backupTo"
    # Debugging text
    <#
    [array]$singleFileLocations = @("$primaryLocation","$bakLocation")
    foreach ( $s in $singleFileLocations ) {Write-Host " `$s is $s" }
    #>

    # How this works
    # New-Item -ItemType HardLink -Path <whereitgoes> -Target <whereitsfrom>
    if ( $(Test-Path -Path "$backupTo\Bookmarks") -eq $false ) {
        New-Item -ItemType HardLink -Path "$backupTo\Bookmarks" -Target "$primaryLocation"
    }
    if ( $(Test-Path -Path "$backupTo\Bookmarks.bak") -eq $false )  {
        New-Item -ItemType HardLink -Path "$backupTo\Bookmarks.bak" -Target "$bakLocation"
    }

}


function Backup-FireFoxBookmarks {
    param (
        [Parameter()]
        [String]$UserName,
        [String]$backupTo
    )
    # Firefox
    [string]$basePath = "C:\Users\" + "$username" + "\AppData\Roaming\Mozilla\Firefox\Profiles\"
    [string]$firefoxDefaultReleasePath = "$basePath" + "$(Get-ChildItem -Path "$basePath" `
        | Where-Object { $_.Name -like "*.default-release" } | Select-Object -ExpandProperty Name)"
    [string]$firefoxPrimaryLocation = "$firefoxDefaultReleasePath" + "\places.sqlite"
    [string]$firefoxFavIconLocation = "$firefoxDefaultReleasePath" + "\favicons.sqlite"
    [array]$firefoxBakFilenames = ((Get-ChildItem -Path "$( "$firefoxDefaultReleasePath" + "\bookmarkbackups\")" ).Name)
    [array]$firefoxBakLocations = @()
    foreach ( $f in $firefoxBakFilenames ) { 
        $firefoxBakLocations += "$("$firefoxDefaultReleasePath" + "\bookmarkbackups\" + "$f") "
    }
    [array]$singleFileLocations = @("$firefoxPrimaryLocation","$firefoxFavIconLocation")
    [array]$multiFileLocations = @("$firefoxBakLocations")
    foreach ( $s in $singleFileLocations ) { Write-Host " `$s is $s" }
    foreach ( $m in $multiFileLocations ) {Write-Host " `$s is $m" }
    # Only attempt to create the new links if they don't exist
    if ( $(Test-Path -Path "$backupTo\places.sqlite" ) -eq $false ) {
        New-Item -ItemType HardLink -Path "$backupTo\places.sqlite" -Target "$firefoxPrimaryLocation" -ErrorAction SilentlyContinue
    }
    if ( $(Test-Path -Path "$backupTo\favicons.sqlite") -eq $false ) {
        New-Item -ItemType HardLink -Path "$backupTo\favicons.sqlite" -Target "$firefoxFavIconLocation" -ErrorAction SilentlyContinue
    }

    foreach ( $c in $($firefoxBakFilenames.Count) ) {
        $i = $c - 1
        # Debugging text
        #<#
        Write-Host "Index $i"
        Write-Host " `$(`$firefoxBakFilenames[`$i]) is $($firefoxBakFilenames[$i]) "
        Write-Host " `$(`$firefoxBakLocations[`$i]) is $($firefoxBakLocations[$i]) "
        Write-Host "Making link from $("$backupTo\bookmarkbackups\$($firefoxBakFilenames[$i])") to $("$($firefoxBakLocations[$i])")"
        #>
        if ( $(Test-Path -Path "$backupTo\bookmarkbackups\$($firefoxBakFilenames[$i])") -eq $false ) {
            New-Item -ItemType HardLink -Path "$backupTo\bookmarkbackups\$($firefoxBakFilenames[$i])" -Target "$($firefoxBakLocations[$i])" -ErrorAction SilentlyContinue
        }
    }
}

# Main Loop
[array]$chromiumFlavors = @()
if ( $backupChrome -eq $true ) { $chromiumFlavors += "Chrome"}
if ( $backupEdge -eq $true ) { $chromiumFlavors += "Edge"}

if ( $loggedInUsers -eq $null) {
    Exit 0
}

foreach ($u in $loggedInUsers) {
    $username = "$u"
    Write-Host "Current `$username is $username"
    # Set Backup To Path
    [string]$backupToPath = "C:\Users\" + "$username" + "$backupToPathSuffix"
    [string]$chromeBackupToPath = "$backupToPath" + "Chrome\"
    [string]$edgeBackupToPath = "$backupToPath" + "Edge\"
    [string]$firefoxBackupToPath = "$backupToPath" + "Firefox\"
    [string]$firefoxBakBackupToPath = "$backupToPath" + "Firefox\bookmarkbackups"
    # Order matters, make sure $backupToPath is first as it's the root.
    [array]$backupToPaths = @("$backupToPath" `
        ,"$chromeBackupToPath" `
        ,"$edgeBackupToPath" `
        ,"$firefoxBackupToPath" `
        ,"$firefoxBakBackupToPath" `
        )

    # Should this get its own function at this point?
    foreach ( $bp in $backupToPaths ) {
        if (( $(Test-Path -Path $bp) -eq $true -and $clobberCurrent -eq $true ) `
        -or ($(Test-Path -Path $bp) -eq $false) ) {
               Remove-Item -Path "$bp" -Recurse -Force -ErrorAction SilentlyContinue
               New-Item -ItemType Directory -Path "$bp" -Force -ErrorAction SilentlyContinue
           }
   }

    foreach ( $f in $chromiumFlavors ){
        Backup-ChromiumBookmarks -Username $username -chromeBackupToPath "$chromeBackupToPath" -edgeBackupToPath "$edgeBackupToPath" -flavor "$f"
    }
    if ( $backupFirefox -eq $true ) {
        Backup-FireFoxBookmarks -Username $username -backupTo "$firefoxBackupToPath"
    }

}
