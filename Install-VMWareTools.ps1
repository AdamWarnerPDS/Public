<#
.SYNOPSIS
    Fetches and installs VMWare tools on a device silently
.DESCRIPTION
    Fetches and installs VMWare tools on a device silently.  Currently does not force reboot.  
    You can define 
    1. A local (ie local drive, local network/UNC) path to fetch the installer from
    2. remote (internet) path to fetch the installer from
    3. Define working folder (where logs and installer go)
    4. Time to wait for insaller to complete
    5. Exclude certain modules from being installed such as Bootcamp and ThinPrint
    6. Whether or not to clobber an existing installation with equal or newer version number, or to simply not install
.EXAMPLE
    PS C:\> Install-VMWareTools.ps1
    Installs VMWareTools using default settings
.EXAMPLE
    PS C:\Install-VMWareTools.ps1 -localInstallerFolderPath "\\server\folderContainingVMT" -remoteInstallerFolderPath "https://packages.vmware.com/tools/esx/7.0p02/windows" -workingPath "C:\VMTInstall" -installerTimeout 600 -excludeModules "Bootcamp","ThinPrint" -execMode "InstallClobber"
    Installs VMWareTools with the following:
    1. Tries to fetch installer from \\server\folderContainingVMT
    2. If it can't get the installer from UNC path, tries to fetch installer from https://packages.vmware.com/tools/esx/7.0p02/windows
    3. Uses C:\VMTInstall as a working directory (installer and logs land here)
    4. Waits 600 seconds (10 minutes) for installer to complete
    5. Excludes the Bootcamp and ThinPrint modules from being installed
    6. Clobbers any existing installation regardless of its version

    Logging should be reasonably verbose for troubleshooting.  Not all error-cases will be caught, but most should throw and exit.  If the installer fails, the script should dump the installer log into the script log.
.PARAMETER localInstallerFolderPath
    Type: string
    Default: ""
    Description: 'Local' path to fetch installer from such as "C:\Users\SomeUser\Downloads\" or "\\SomeServer\SomeShare\VMWareTools\".  Default value "" (blank string) will simply revert to downloading from the defined or default $remoteInstallerFolderPath.
.PARAMETER remoteInstallerFolderPath
    Type: string
    Default: "https://packages.vmware.com/tools/esx/latest/windows"
    Description: 'Remote' (internet or other HTTP/s) path to fetch installer from such as "https://packages.vmware.com/tools/esx/latest/windows"
.PARAMETER workingPath
    Type: string
    Default: "C:\Temp\VMWareTools"
    Description: Where to download installer to and output logs
.PARAMETER installerTimeout
    Type: int32
    Default: 300
    Description: how long to wait for VMWareTools installer before timing script out and throwing an error
.PARAMETER excludeModules
    Type: array (of strings)
    Default: "Bootcamp","Sync","Hgfs","AppDefense","ThinPrint"
    Description: List of modules you wish to exclude from being installed.  You can view the names of vmwaretools modules here: https://docs.vmware.com/en/VMware-vSphere/5.5/com.vmware.vmtools.install.doc/GUID-E45C572D-6448-410F-BFA2-F729F2CDA8AC.html#GUID-E45C572D-6448-410F-BFA2-F729F2CDA8AC
.Parameter execMode
    Type: string
    Default: InstallNoClobber
    Description: Defines whether to actually perform installation depending on this switch and the (potentially) currently installed version of VMWareTools
    Options:
    "InstallNoClobber"      Default, performs installation if the installed version is less than the downloaded installer version
    "InstallClobber"        Performs installation even if installed version is equal to or newer than the downloaded installer version
    "NoInstall"             Does not actually install
.NOTES
    Sources
    * https://docs.vmware.com/en/VMware-vSphere/5.5/com.vmware.vmtools.install.doc/GUID-CD6ED7DD-E2E2-48BC-A6B0-E0BB81E05FA3.html
    * https://www.vgemba.net/vmware/VMware-Tools-Drivers/

    ##################################################
    ### Copywrite 2021 Paragon Development Systems ###
    ### Written by: Adam Warner                    ###
    ##################################################


    TODO
    * Installer download cleanup
#>



[CmdletBinding()]
param (
    [Parameter()]
    # 'Local' meaning local network, likely a UNC path
    [string]$localInstallerFolderPath = "",
    # 'Remote' meaning internet, likely vmware's download site
    [string]$remoteInstallerFolderPath = "https://packages.vmware.com/tools/esx/latest/windows",
    # Working path where installer and logs go
    [string]$workingPath = "C:\Temp\VMWareTools",
    # Time to wait for installer to finish in seconds
    [int32]$installerTimeout = 300,
    # Modules to exclude, see names here: 
    # https://docs.vmware.com/en/VMware-vSphere/5.5/com.vmware.vmtools.install.doc/GUID-E45C572D-6448-410F-BFA2-F729F2CDA8AC.html#GUID-E45C572D-6448-410F-BFA2-F729F2CDA8AC
    [array]$excludeModules = @(
        "Bootcamp",
        "Sync",
        "Hgfs",
        "AppDefense",
        "ThinPrint"
    ),
    [string]$execMode = "NoInstall"

)

# Variable Declarations

# ISO 8601 short datetime format
$startDateTime = "$(get-date -uf %Y%m%dT%H%M%S%Z)"

# Where the logs go and their names
$installerLogPath = "$workingPath\$startDateTime" + "_$env:COMPUTERNAME" + "_VMWareToolsInstall_Installer.log"
$scriptLogPath = "$workingPath\$startDateTime" + "_$env:COMPUTERNAME" +  "_VmwareToolsInstall_Script.log"

# turn $excludeModules into a nice string, don't edit
$excludedModulesString = $($excludeModules -join ',')

# Function Declarations

function Exit-Script0 {
    # End Script with code 0
    Stop-Transcript
    Exit 0
}

function Exit-Script1 {
    # End Script with code 1
    Stop-Transcript
    Exit 1
}


function Write-InlineLog($writeText){
    # allow for time-stamp based output/logging; just makes it easier
    # ISO8601 Extended datetime format
    Write-Host "$(get-date -uf %Y-%m-%dT%H:%M:%S%Z);$env:COMPUTERNAME;$writeText"
}


function New-WorkingPath {
    # Make new working path if it does not already exist
    if ( $(Test-Path -Path "$workingPath") -eq $false ) {
        Write-InlineLog "Creating $workingPath"
        New-Item -Path "$workingPath" -ItemType Directory
    }
}

function Get-Installer {
    # Determine OS 32/64 bit for correct installer
    $osBit = 0
    If ( $(Get-WmiObject win32_operatingsystem).osarchitecture -eq "64-bit" ) {
        $osBit = 64
    }
    ElseIf ( $(Get-WmiObject win32_operatingsystem).osarchitecture -eq "32-bit" ) {
        $osBit = 32
    }
    Write-InlineLog "Detected $osBit bit OS"
    If ( $osBit -eq 0 ) {
        Write-Error "Could not determine OS bit value, exiting"
        Exit-Script1
    }

    $fileName = ""
    # Determine whether to use local or internet installer paths and download correct installer
    # Test and use 'local' path first
    If ( $localInstallerFolderPath -ne "" ) {
        If ( $(Test-Path -Path "$localInstallerFolderPath") -eq $true ) {
            Write-InlineLog "Using local network stored installer from $localInstallerFolderPath"
            If ( $osBit -eq 32 ) {
                $fileName = (Get-ChildItem -Path "$localInstallerFolderPath" -Filter "*-i386.exe").Name
            }
            ElseIf ( $osBit -eq 64 ) {
                $fileName = (Get-ChildItem -Path "$localInstallerFolderPath" -Filter "*-x86_64.exe").Name
            }
            $script:fullInstallerPath = "$workingPath\$fileName"
            Write-InlineLog "Detected $osBit bit OS, fetching $osBit bit installer from $localInstallerFolderPath/$fileName to $fullInstallerPath"
            Copy-Item -Path "$localInstallerFolderPath\$fileName" -Destination "$fullInstallerPath"
        }
    }
    # Test and use 'remote' path if 'local' fails
    ElseIf ( $($(invoke-webrequest "$remoteInstallerFolderPath" -UseBasicParsing).StatusCode) -eq 200 ) {
        Write-InlineLog "Using internet stored installer from $remoteInstallerFolderPath"
        If ( $osBit -eq 32 ){
            $dlPath = "$remoteInstallerFolderPath/x86/"
            $fileName = (Invoke-WebREquest -URI "$dlPath" -UseBasicParsing).Links.href[1]
        }
        ElseIf ( $osBit -eq 64 ){
            $dlPath = "$remoteInstallerFolderPath/x64/"
            $fileName = (Invoke-WebREquest -URI "$dlPath" -UseBasicParsing).Links.href[1]
        }
        $script:fullInstallerPath = "$workingPath\$fileName"
        Write-InlineLog "Detected $osBit bit OS, fetching $osBit bit installer from $dlPath/$fileName to $fullInstallerPath"
        Start-BitsTransfer -Source "$dlPath/$fileName" -Destination "$fullInstallerPath"
    }
    Else {
        Write-Error "Cannot locate installer, exiting"
        Exit-Script1
    }
    # Attempts to catch a failed transfer; should replace this with a hash check
    if ( (Test-Path $fullInstallerPath) -eq $False) {
        Write-Error "Installer missing, exiting"
        Exit-Script1
    }
}

# Get currently installed version of vmwaretools with following format: MM.m.p.BBBBBBBB (Major.minor.pico.Build) for comparison against installer version info and compare against downloaded installer version.
function Compare-VMWareToolsVersion {
    $script:newerVMWareToolsVersionInstalled = $null
    Write-InlineLog "Checking installed VMWareTools version"
    # Note: spaces are escaped in the Invoke-Expression expression as it does not handle spaces well
    #If ($true) { # Testing only!!!!!!!!!!!!!!!!!!!
    If ( $(Test-Path "C:\Program FIles\VMware\VMware Tools\VMwareToolboxCmd.exe") -eq $true) {  
        $versionInstalledRaw = Invoke-Expression 'C:\Program` Files\VMware\VMware` Tools\VMwareToolboxCmd.exe -v' -ErrorAction SilentlyContinue
        #$versionInstalledRaw = "11.2.5.26209 (build-17337674)"
        # Make prefix by joining array of string created by splitting $$versionInstalledRaw at space, then items selected by '.', then selecting only the first 3 values (omitting the last one)
        #$currentInstalledVersionPrefix = [string]::Join(".",(($versionInstalledRaw -split " ")[0]).split('.')[0..2])
        # This is slightly cleaner
        $currentInstalledVersionPrefix = (($versionInstalledRaw -split " ")[0]).split('.')[0..2] -join "."
        # Get suffix by stripping out non numbers
        $currentInstalledVersionSuffix = ($versionInstalledRaw -split " ")[1] -replace '[^\d]'
        # Join them to get a nice version number to compare
        # $niceInstalledVersion = "$currentInstalledVersionPrefix" + "." + "$currentInstalledVersionSuffix"
        $niceInstalledVersion = "$currentInstalledVersionPrefix","$currentInstalledVersionSuffix" -join '.' 
        If ( $null -ne $niceInstalledVersion ) {
            Write-InlineLog "Detected VMWareTools, installed version is $niceInstalledVersion"
            $installerVersion =  (Get-Item "$fullInstallerPath").VersionInfo.ProductVersion
            Write-InlineLog "Downloaded installer is version $installerVersion"
            # Casting [version] type so PS does not get things backwards
            If ( [version]$niceInstalledVersion -ge [version]$installerVersion ) {
                Write-InlineLog "Installed version $niceInstalledVersion is equal or newer than downloaded version $installerVersion"
                $script:newerVMWareToolsVersionInstalled = $True
            }
            Else {
                Write-InlineLog "Installed version $niceInstalledVersion is older than downloaded version $installerVersion"
                $script:newerVMWareToolsVersionInstalled = $False
            }
        }
        Else {
            Write-InlineLog "Unable to get installed VMware Tools version number, does VMwareToolbxCmd.exe exist?"
            $script:newerVMWareToolsVersionInstalled = $False
            Return
        }
    }
    Else {
        Write-InlineLog "Did not detect VMwareTools installation"
        $script:newerVMWareToolsVersionInstalled = $null
    }
}

function Install-VMWareTools {
    <#
    # Construct installer command, be careful editing the below!
    https://docs.vmware.com/en/VMware-vSphere/5.5/com.vmware.vmtools.install.doc/GUID-CD6ED7DD-E2E2-48BC-A6B0-E0BB81E05FA3.html
    https://www.advancedinstaller.com/user-guide/msiexec.html
    ## Switches or other operators      ##Explaination
    * /s                                Silent installation
    * /v "list of MSI args see below"   Execute with MSI arguments in quotes
    * "                                 Begin quotes containing MSI args
    * /qn                               Set UI level to "no UI"
    * REBOOT=R                          Do not force reboot, https://docs.microsoft.com/en-us/windows/win32/msi/reboot; Means REBOOT=ReallySuppress; MSI API only reads the first character
    * ADDLOCAL=ALL                      Install all components
    * REMOVE=<list-of-stuff>            Remove <list-of-stuff> from the currently "all" list of to-be-installed components
    * "                                 end quotes containing MSI args
    * /l <somepath>                     Log to this path
    #>
    $installerCommand = "$script:fullInstallerPath" + ' /s /v "/qn REBOOT=R ADDLOCAL=ALL REMOVE=' + "$excludedModulesString" + '" /l ' + "$installerLogPath"
    Write-InlineLog "Running $installerCommand"
    #Invoke-Expression "$installerCommand"

}

function Test-VMWareToolsInstallationStatus {
    $script:installerLog = Get-Content "$installerLogPath"
    if ( $null -ne $($script:installerLog | Select-String "Product: VMware Tools -- Installation completed successfully.") ) {
        Write-InlineLog "VMware Tools installed Successfully"
    }
    # Dump installer log to output if it appears failed
    else {
        Write-InlineLog "VMware Tools installation appears to have failed, begining output of installer log at $installerLogPath"
        Write-Host '####################'
        $script:installerLog
        Write-Host '####################'
        Write-InlineLog "End of installer log"
        Write-error "VMware Tools Installation appears to have failed, please review the log"
        Exit-Script1
    }
}


function Start-Install {
    # Run installation
    Install-VMWareTools
    # Wait for installation
    Start-Sleep -Seconds $installerTimeout
    # Verify installation, dump installer log if fails
    Test-VMWareToolsInstallationStatus
}



# Main 'loop'

# Script logging
Start-Transcript -Path "$scriptLogPath"
# Test and create install path if not present
New-WorkingPath
# Download installer to local folder
Get-Installer
# Check installed version (if present) against new installer
Compare-VMWareToolsVersion

# Install decision logic
# Can this be cleaned up?
if ( $execMode -eq "InstallNoClobber" ) {
    if ( $script:newerVMWareToolsVersionInstalled -eq $False -or $null -eq $script:newerVMWareToolsVersionInstalled ) {
        Write-InlineLog "Installed version is older than installer version, installing"
        Start-Install
    }
    ElseIf ( $script:newerVMWareToolsVersionInstalled -eq $True ) {
        Write-InlineLog "Newer version of VMwareTools already installed and -execMode is set to not clobber, exiting"
    }
}
ElseIf ( $execMode -eq "InstallClobber" ) {
    If ( $script:newerVMWareToolsVersionInstalled -eq $False -or $null -eq $script:newerVMWareToolsVersionInstalled ) {
        Write-InlineLog "Installed version is older than installer version, installing"
        Start-Install
    }
    ElseIf ( $script:newerVMWareToolsVersionInstalled -eq $True ) {
        Write-InlineLog "Newer version of VMwareTools already installed and -execMode is set to clobber, installing"
        Start-Install
    }
}
ElseIf ( $execMode -eq "NoInstall") {
    Write-InlineLog "-execMode set to `"NoInstall`", no installation will be performed"

}
Else {
    Write-InlineLog "-execMode not set to valid value, exiting"
    Exit-Script1
}

Exit-Script0




<#
### Random notes

vmwaretools-installer.exe /s /v" /qn REBOOT=R ADDLOCAL=ALL REMOVE=<stuff from #exclude, comma separated no spaces>" /l C:\Temp\somelogfilename.log

# Install
MemCtl - Virtual Memory Control Driver
Mouse - Mouse Driver
PVSCSI - Paravirtual SCSI driver
SVGA - SVGA display Driver
VMCI - Virtual Machine Communication Interface driver
VMXNet - VMXNet network driver
VMXNet3 - VMXNet3 network driver
VSS - VSS based snapshot backups drivers for Windows Server 2003 and newer
Perfmon - WMI performance logging driver

# Unsure
Audio - Audio driver
FileIntrospection - NSX File Introspection driver
NetworkIntrospection - NSX Network Introspection driver

# Exclude
Bootcamp - Mac BootCamp Driver
Sync - Filesystem Driver to allow snapshot based backups for older than Windows Server 2003 OSs
Hgfs - Shared Folders driver. For Workstation, Player and Fusion only
AppDefense - AppDefence component
ThinPrint - Allows printers on host OS to be used in VM. Depreciated from vSphere 5.5 onwards

# Sources
* https://docs.vmware.com/en/VMware-vSphere/5.5/com.vmware.vmtools.install.doc/GUID-CD6ED7DD-E2E2-48BC-A6B0-E0BB81E05FA3.html
* https://www.vgemba.net/vmware/VMware-Tools-Drivers/

#>