[CmdletBinding()]
param (
    # Working Path
    [Parmeter()]
    [string]
    $workingPath = 'C:\Setup-FreshAirGPUVM\',

    # Log Level: uses definitions for PS output streams
    # https://learn.microsoft.com/en-gb/powershell/module/microsoft.powershell.core/about/about_output_streams?view=powershell-5.1
    [Parameter()]
    [int]
    $logLevel = 3,

    # Install DDNS?
    [Parameter()]
    [bool]
    $installDDNS = $true,

    # Enable DDNS?
    [Parameter()]
    [bool]
    $enableDDNS = $true,

    # Cloudflare Zone ID
    [Parameter()]
    [string]
    $cloudflareZoneID,

    # Cloudflare API Key
    [Parameter()]
    [string]
    $cloudflareAPIKey,

    # DNS Name for this device
    [Parameter()]
    [string]
    $dnsName,

    # DDNS Util install location
    [Parameter()]
    [string]
    $ddnsPath = "C:\automation\cloudflare-ddns\",

    # Install Sunshine and Prereqs?
    [Parameter()]
    [bool]
    $installSunshine = $true,

    # Desired username for sunshine
    [Parameter()]
    [string]
    $sunshineUsername,

    # Desired password for sunshine
    [Parameter()]
    [string]
    $sunshinePassword
)

# To be used like Write-Log -Message "Some normal message", or Write-Log -Type error -Message "Some error!"
# Expects $logPath to exist
function Write-Log {
    [CmdletBinding()]
    param (
        # Set log type
        [Parameter()]
        [ValidateSet("DEBUG","VERBOSE","INFO","WARNING","ERROR")]
        [string]
        $type = "INFO",
    
        # Input message parameter
        [Parameter()]
        [string]
        $message
    )
    $dateTime = "$(Get-Date -Format yyy-MM-ddTHH-mm-ss)"
    $fullMessage = "$dateTime" + " - $type" + " - $message"

    Write-Output $fullMessage | Out-File -Append -FilePath $logPath

    switch ($type) {
        "INFO" { Write-Output $fullMessage }
        "WARNING" { Write-Warning -Message $fullMessage }
        "ERROR" { Write-Error -Message $fullMessage }
        "VERBOSE" { Write-Verbose -Message $fullMessage }
        "DEBUG" { Write-Debug -Message $fullMessage }
        Default { Write-Output "Undefined Log Input!!! $fullMessage" }
    }
}

function Install-Chocolatey {
    Write-Log "Installing Chocolatey"
    # Ripped from https://chocolatey.org/install
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    try {
        choco
    }
    catch {
        Write-Log -error "Did not detect chocolatey after installation"
    }
}

function Install-Curl {
    Write-Log "Installing Curl.exe"
    choco install curl
    refreshenv
}

function Stop-AndDisableParsec {
    Write-Log "Setting service 'Parsec' to manual startup and stopping service"
    # Disable Parsec Service first
    Set-Service parsec -StartupType Manual
    Stop-Service parsec
}

function Install-IddSampleDriver {
    $dlPath = $workingPath + "IddSampleDriver.zip"
    $extractedPath = "C:\IddSampleDriver\"
    $optionPath = "C:\IddSampleDriver\option.txt"
    $bakOptionPath = $optionPath + ".backup"
    $devConPath = $extractedPath + "\devcon.exe"
    $driverURI = "https://github.com/ge9/IddSampleDriver/releases/download/0.0.1.2/IddSampleDriver.zip"
    $devConURI = "https://f000.backblazeb2.com/file/Strangenet-Public0/devcon.exe"
    # Nasty array join to keep script formatting nice, so sue me
    $newOption = -join @(
        "1 `n"
        "# place this file in C:\IddSampleDriver\ `n"
        "# lines beginning with # are ignored (comment) `n"
        "# the first line mush be a positive integer (small number (<5) is recommended)), NOT comment `n"
        "# (currently) the location of this file must be C:\IddSampleDriver\option.txt (hard-coded) `n"
        "# numbers should be separated by comma `n"
        "1920, 1080, 60`n"
        "1920, 1080, 144`n"
        "3840, 2160, 60`n"
        "3840, 2160, 144`n"
    )

    # Changing to curl.exe
    #Start-BitsTransfer -Source $driverURI -Destination "$dlPath"
    Write-Log -type INFO -message "Downloading IddSampleDriver"
    curl.exe $driverURI --output $dlPath

    Write-Log -type INFO -message "Expanding $dlpath to C:\"
    # Zip contains directory "IddSampleDriver", send this straight to C:\
    Expand-Archive -Path $dlPath -DestinationPath "C:\"

    Write-Log -type INFO -message "Downloading DevCon.exe to $extractedPath"
    curl.exe $devConURI --output $devConPath
    
    Write-Log -type INFO -message "Moving $optionsPath to $backOptionsPath"
    Move-Item -Path $optionPath -Destination $bakOptionPath

    Write-Log -type INFO -message "Writing new $optionsPath"
    Out-File -InputObject $newOption -FilePath $optionPath

    Write-Log -type INFO -message "Installing certificate $extractedPath\IddSampleDriver.cer"
    Start-Process -FilePath "$extractedPath\installCert.bat" -Wait -NoNewWindow

    Write-Log -type INFO -message "Installing IddSampleDriver"
    Start-Process -FilePath $devConPath -ArgumentList @("install", "$extractedPath\IddSampleDriver.inf", "root\iddsampledriver") -Wait -NoNewWindow
}

function Install-ViGEmBus {
    # Install ViGEmBus (Controller passthrough)
    ## TODO move to some sort of "latest" tag for download
    $viGEmBusURI = "https://github.com/ViGEm/ViGEmBus/releases/download/v1.21.442.0/ViGEmBus_1.21.442_x64_x86_arm64.exe"
    $viGEmBusPath = "$workingPath" + "ViGEmBusPath.exe"
    Write-Log "Downloading ViGEmBus to $viGEmBusPath"
    # Chagned to curl.exe
    #Start-BitsTransfer -Source $viGEmBusURI -Destination "$viGEmBusPath"
    curl.exe $viGEmBusURI --output $viGEmBusPath
    Write-Log "Installing ViGEmBus from $viGEmBusPath"
    Start-Process -FilePath $viGEmBusPath -ArgumentList "/quiet" -Wait -NoNewWindow
}


function Install-Sunshine {
    # Install Sunshine
    choco install sunshine -y
}

function Set-SunshineConfig {
    $sunshineInstallPath = "C:\Program Files\Sunshine\"
    $configPath = $sunshineInstallPath  + "config\sunshine.conf"
    $defaultConfigPath = $sunshineInstallPath + "config\sunshine.conf.default"
    $newConfig = -join @(
        "key_rightalt_to_key_win = enabled`n"
        "gamepad = x360`n"
        "upnp = disabled`n"
        "dwmflush = enabled`n"
        "min_log_level = 2`n"
        "origin_pin_allowed = pc`n"
        "origin_web_ui_allowed = pc`n"
        "hevc_mode = 0`n"
        "nv_preset = p4`n"
        "nv_tune = ull`n"
        "nv_coder = auto`n"
        "nv_rc = cbr`n"
        "qsv_preset = medium`n"
        "qsv_coder = auto`n"
        "amd_coder = auto`n"
        "amd_quality = balanced`n"
        "amd_rc = vbr_latency`n"
        "vt_coder = auto`n"
        "vt_software = auto`n"
        "vt_realtime = enabled`n"
        "fps = [10,30,60,90,120,144]`n"
        "resolutions = [`n"
        "    352x240,`n"
        "    480x360,`n"
        "    858x480,`n"
        "    1280x720,`n"
        "    1920x1080,`n"
        "    2560x1080,`n"
        "    3440x1440,`n"
        "    1920x1200,`n"
        "    3860x2160,`n"
        "    3840x1600`n"
        "]`n"
    )
    Stop-Service sunshinesvc
    Copy-Item -Path $configPath -Destination $defaultConfigPath
    Out-File -FilePath $configPath -InputObject $newConfig
    if ($null -ne $sunshineUsername -and $null -ne $sunshinePassword ) {
        $sunshineArgs = @("--creds", "$sunshineUsername", "$sunshinePassword")
        Start-Process -FilePath $($sunshineInstallPath + "sunshine.exe") -ArgumentList $sunshineArgs -Wait -NoNewWindow
    }
    Start-Service sunshinesvc
}

function Install-CLoudflareDDNS {
    $downloadURIs = @(
        "https://raw.githubusercontent.com/fire1ce/DDNS-Cloudflare-PowerShell/main/README.md",
        "https://raw.githubusercontent.com/fire1ce/DDNS-Cloudflare-PowerShell/main/update-cloudflare-dns_conf.ps1",
        "https://raw.githubusercontent.com/fire1ce/DDNS-Cloudflare-PowerShell/main/update-cloudflare-dns.ps1"
    )
    if ( $(Test-Path -Path $ddnsPath) -eq $false ) {
        New-Item -ItemType Directory -Path $ddnsPath
    }
    foreach ( $u in $downloadURIs ) {
        $n = ""
        $n = "$($u.split('/')[-1])"
        curl.exe $u --output $ddnsPath\$n
    }
    $configPath = $ddnsPath + "\Update-cloudflare-dns_conf.ps1"
    $zoneIDString = $ExecutionContext.InvokeCommand.ExpandString('$zoneid = ' + '"' + $cloudflareZoneID + '"')
    $tokenString = $ExecutionContext.InvokeCommand.ExpandString('$cloudflare_zone_api_token = ' + '"' + $cloudflareAPIKey + '"')
    (Get-Contnet -FilePath "$configPath") -replace 'before','after'
    (Get-Contnet -FilePath "$configPath") -replace 'ddns.example.com',"$dnsName"
    (Get-Contnet -FilePath "$configPath") -replace '$zoneid = "ChangeMe"',"$zoneIDString"
    (Get-Contnet -FilePath "$configPath") -replace '$cloudflare_zone_api_token = "ChangeMe"',"$tokenString"

    $taskName = "Update-Cloudflare-DDNS"
    $ps1Path = $ExecutionContext.InvokeCommand.ExpandString("$ddnsPath\update-cloudflare-dns.ps1")
    $taskAction = $(New-ScheduledTaskAction -Execute "$ps1Path")
    $taskTrigger = $( New-ScheduledTaskTrigger -AtStartup )
    $taskTrigger.Delay = 'PT1M'
    # Jank way to add repitition to AtStartup 
    # https://learn.microsoft.com/en-us/answers/questions/573477/powershell-new-scheduledtasktrigger-cmdlet-atlogon
    $taskTrigger.Repetition = (New-ScheduledTaskTrigger -once -At 00:00 -RepetitionInterval (New-TimeSpan -Minutes 5 )).repetition
    $taskTrigger.Repetition.StopAtDurationEnd = $False
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId "$(whoami)"
    $taskSettingsSet = New-ScheduledTaskSettingsSet
    $task =New-ScheduledTask -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettingsSet
    Register-ScheduledTask -TaskName "$taskName" -InputObject $task
    Start-ScheduledTask -TaskName $taskName
}

# Main Loop
## Stage working path
if (Test-Path $workingPath -eq $false ) {
    New-Item -ItemType Directory -Path $workingPath
}

## Start Log
$logPath = "$workingPath" + "Setup_$(Get-Date -Format yyy-MM-ddTHH-mm-ss)" + ".log"
New-Item -ItemType File -Path $logPath


## Install chocolatey if not installed
try {
    choco
}
catch {
    Install-Chocolatey
}

## Install Curl if not installed
try {
    curl.exe
}
catch {
    Install-Curl
}

## Install IddSampleDriver
if ( $null -eq $(pnputil /enum-devices /class display /drivers | findstr 'root\iddsampledriver') ){
    Install-IddSampleDriver
}

## Kill Parsec
Stop-AndDisableParsec

## Install ViGEmBus
if ( $null -eq $(pnputil /enum-devices /class system /drivers | findstr 'Nefarius\\ViGEmBus\Gen1')){
    Install-ViGEmBus
}

## Install Sunshine
Install-Sunshine

## Configure Sunshine
Set-SunshineConfig

Install-CLoudflareDDNS