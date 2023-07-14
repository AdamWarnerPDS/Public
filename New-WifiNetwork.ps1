$profileRaw = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
	<name>docreit-secure</name>
	<SSIDConfig>
		<SSID>
			<hex>646F63726569742D736563757265</hex>
			<name>docreit-secure</name>
		</SSID>
	</SSIDConfig>
	<connectionType>ESS</connectionType>
	<connectionMode>auto</connectionMode>
	<MSM>
		<security>
			<authEncryption>
				<authentication>WPA3SAE</authentication>
				<encryption>AES</encryption>
				<useOneX>false</useOneX>
			</authEncryption>
			<sharedKey>
				<keyType>passPhrase</keyType>
				<protected>false</protected>
				<keyMaterial>Qt!JLi#frHyGSkGzPDAEx7V8xyEwAQ&amp;t</keyMaterial>
			</sharedKey>
		</security>
	</MSM>
	<MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3">
		<enableRandomization>false</enableRandomization>
		<randomizationSeed>1508594846</randomizationSeed>
	</MacRandomization>
</WLANProfile>
"@

# Schema https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpwl/34054c93-cfcd-44df-89d8-5f2ba7532b67
# element https://learn.microsoft.com/en-us/windows/win32/nativewifi/wlan-profileschema-wlanprofile-element
$WLANProfileName = "docreit-secure"
$ssidName = "$WLANProfileName"

# Get hex for ssid DON'T TOUCH
$bytes = ""
$hex = ""
$bytes = [System.Text.Encoding]::UTF8.GetBytes($ssidName)
foreach ( $b in $bytes ) {
    $h = '{0:x}' -f $b ; $hex += $h  
}
$ssidHex = $hex.ToUpper()

# Indicates whether the network is infrastructure ("ESS") or ad-hoc ("IBSS").
$connectionType = "ESS"

# Indicates whether connection to the wireless LAN should be automatic ("auto") or initiated ("manual") by user. This element is optional.
$connectionMode = "auto"







$workingDir = "C:\temp"
$workingFileName = "docreit-secure.xml"
$workingPath = "$workingDir" + "$workingFileName"


$profileRaw | Out-File -FilePath $workingPath