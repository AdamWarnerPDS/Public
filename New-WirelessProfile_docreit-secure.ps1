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

$workingDir = "C:\temp\"
$workingFileName = "docreit-secure.xml"
$workingPath = "$workingDir" + "$workingFileName"

if ( $(Test-Path $workingDir)  -eq $false ) {
    New-Item -ItemType Directory -Path $workingDir
}

$profileRaw | Out-File -FilePath $workingPath

netsh wlan add profile filename="$workingPath" user=all

# Avoid file access race condition
Start-Sleep -Seconds 5

# Cleanup xml file
Remove-Item -Path $workingPath