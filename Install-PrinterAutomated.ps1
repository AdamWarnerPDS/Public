[CmdletBinding()]
param (
    # Path to find the inf file to install to the computer.  Accepts UNC
    [Parameter(Mandatory)]
    [String]
    $infPath,

    # Name of the printer driver: find this in the inf file
    [Parameter(Mandatory)]
    [String]
    $printerDriverName,

    # Name for the port
    [Parameter(Mandatory)]
    [String]
    $printerPortName,

    # IP or Hostname of the printer
    [Parameter(Mandatory)]
    [String]
    $printerPortAddress,

    # Display Name for the printer
    [Parameter(Mandatory)]
    [String]
    $printerDisplayName
)

### Other Declarations
[String]$infName = ($infPath.Split( "\")[-1] )


### Main Loop

# Install Drivers to Windows Driver Store
pnputil.exe /a "$infPath"

# Find Driver in Driver Store
$driverDirGet = (Get-ChildItem -Path "C:\Windows\System32\DriverStore\FileRepository" |
    Where-Object { $_.Name -like "$infName*" } )
$printerInstalledInfPath = (Get-ChildItem -Path "$driverDirGet" |
    Where-Object { $_.Name -like "*.inf" } )

# Install Printer Driver
Add-PrinterDriver -Name "$printerDriverName" -InfPath "$printerInstalledInfPath"

# Add Port
Add-PrinterPort -Name "$printerPortName" -PrinterHostAddress "$printerPortAddress"

# Add Printer
Add-Printer -DriverName "$printerDriverName" -Name "$printerDisplayName" -PortName "$printerPortName"
