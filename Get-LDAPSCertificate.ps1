<#
MIT License

Copywrite 2022 Adam Warner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

[CmdletBinding]

# Most of these should be parameters someday

$VerbosePreference = "continue"

Import-Module Posh-ACME

$mainDomain = 'server.yourdomain.local'
$subjectAlternateNames = @('alias.yourdomain.local','sub.server.yourdomain.local')

# For Lets Encrypt, choices are staging "LE_STAGE" and production "LE_PROD"
$server = "LE_STAGE"
$contact = "youremail@yourdomain.local"
$contactString = "mailto:" + "$contact"

# Generated by: $secureString = ConvertTo-SecureString -String '<apitokenhere>' -AsPlainText -Force ; ConvertFrom-SecureString -SecureString $secureString
$apiKeySecure = "<see above comment>"
$apiKeySecureString = ConvertTo-SecureString $apiKeySecure

$plugin = "Cloudflare"
$pArgs = @{ CFToken = $apiKeySecureString }

$script:certChanged = $null


# Functions

Function Set-ACMEAccount() {
    $paAccounts = Get-PAAccount -list
    $desiredAccount = $paAccounts | Where-Object -Property contact -eq "$contactString"
    if ( $desiredAccount.contact.count -gt 0 ) {
	    Set-PAAccount $desiredAccount.id
	    Write-Host "Using existing account $($desiredAccount.id) with contact email $contact"
    }
    else {
	    New-PAAccount "$contact" -AcceptTOS
	    $paAccounts = Get-PAAccount -list
	    $desiredAccount = $paAccounts | Where-Object -Property contact -eq "$contactString"
	    Set-PAAccount $desiredAccount.id
	    Write-Host "Created new account $desiredAccount.id with contact email $contact"
    }
}

Function Get-ACMECertRenewal() {
    Param(
        [switch]$force
    )
	Write-Host "Renewing $mainDomain with SANs $subjectAlternateNames"
    if ($force) {
        Submit-Renewal -force $mainDomain -WarningVariable RenewalWarningVar -WarningAction Continue -ErrorVariable RenewalErrorVar -ErrorAction Continue
    }
    else {
    	Submit-Renewal $mainDomain -WarningVariable RenewalWarningVar -WarningAction Continue -ErrorVariable RenewalErrorVar -ErrorAction Continue
    }
    if ( $RenewalWarningVar -eq $null -and $RenewalErrorVar -eq $null ) {
        $script:certChanged = $true
    }
    Else {
        $script:certChanged = $false
    }

}

Function Get-NewACMECert() {
	if ( $plugin -eq "Cloudflare") {
		Write-Host "Creating new certificate for $mainDomain with SANs $subjectAlternateNames"
		# Use cloudflare
		# Reference: https://github.com/rmbolger/Posh-ACME/blob/main/Posh-ACME/Plugins/Cloudflare-Readme.md
		New-PACertificate -Domain $domain -Plugin $plugin -PluginArgs $pArgs -Force
        $script:certChanged = $true
	}
	else { 
		Write-Error "Invalid plugin"
        $script:certChanged = $false
		Exit 1
	}
}

Function Import-CertToNTDSStore() {
    # Import to NTDS cert store
    # From https://blog.devolutions.net/2021/03/how-to-configure-secure-ldap-ldaps-in-active-directory-with-lets-encrypt

    $Certificate = Get-PACertificate
    $CertPath = Split-Path -Path $Certificate.PfxFullChain -Parent

    Write-Host "Importing following certficiate into NTDS certificate store:"
    $Certificate | FL

    $CertificatePassword = $(ConvertTo-SecureString -AsPlainText 'poshacme' -Force)
    $ImportedCertificate = Import-PfxCertificate -FilePath $Certificate.PfxFullChain `
        -CertStoreLocation 'cert:\LocalMachine\My' -Password $CertificatePassword
    $CertificateThumbprint = $ImportedCertificate.Thumbprint

    $LocalCertStore = 'HKLM:/Software/Microsoft/SystemCertificates/My/Certificates'
    $NtdsCertStore = 'HKLM:/Software/Microsoft/Cryptography/Services/NTDS/SystemCertificates/My/Certificates'

    if (-Not (Test-Path $NtdsCertStore)) {
    New-Item $NtdsCertStore -Force
    }

    Copy-Item -Path "$LocalCertStore/$CertificateThumbprint" -Destination $NtdsCertStore

    $dse = [adsi]'LDAP://localhost/rootDSE'
    [void]$dse.Properties['renewServerCertificate'].Add(1)
    $dse.CommitChanges()
}


# Create domain list
$domain = @("$mainDomain")
foreach ( $s in $subjectAlternateNames ) {
	$domain = $domain + "$s"
}
[string]$domainDebugString = '$domain = @("' + ($domain -Join ",") + '")'
Write-Host "$domainDebugString"

Set-PAServer $server

Set-ACMEAccount

# Check Certificates and renew if they exist
$existingCerts = Get-PACertificate
if ( $existingCerts.Thumbprint.count -gt 0 ){
	if ( $(Compare-Object -ReferenceObject $($existingCerts).AllSANs -DifferenceObject $domain) -eq $null ){
        Write-Verbose "Target certificate is same as current certificate, renewing"
        #Get-ACMECertRenewal -force
        Get-AcmeCertRenewal
	}
	else {
        Write-Verbose "Target certificate is different than current certificate, creating new certificate"
		Get-NewACMECert
	}
}
else {
    Write-Verbose "No existing certificate, generating new certificate"
	Get-NewACMECert
}

# Debug force apply cert
#$script:certChanged = $true

if ( $script:certChanged -eq $true ) {
    Write-Verbose "New certificate detected, importing to NTDS store"
    Import-CertToNTDSStore
}
elseif ( $script:certChanged -eq $false ) {
    Write-Verbose "No new certificate detected, exiting"
    Exit 0
}

else { 
    Write-Error "Something went wrong"
    Exit 1
}
