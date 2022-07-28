## From https://www.interfacett.com/blogs/how-to-remotely-enable-and-disable-rdp-remote-desktop/


function Enable-RDP() {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" –Value 0

    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

function Disable-RDP() {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" –Value 1

    Disable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

