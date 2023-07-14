Clear-Host


<#
Script to load audio files to the Axis Camera M5525E
Created by Mack Robinson
Last Modified 1.19.2023
#>

#Get Credential for API call

$Cred = Get-Credential

#Set Variables to Null

$TestSet=@() #Limited number of units to test
$SNVMC=@() #Sentara Northern Virginia Medical Center
$SNG=@() #Sentara Norfolk General
$SWRMC=@() #Sentara Williamsburg Regional Medical Center
$SOH=@() #Sentara Obici Hospital
$SLH=@() # Sentara Leigh Hospital
$Entry=@()
$FilePath=@()
$FileContents=@()
$FileEnc=@()
$FileBytes=@()
$Boundary=@()
$Body=@()


#Read in Values for Devices by Name and IP Address

<#
Sample of CSV Files

HostName CSV
Fname    FQDN                IPAddress      APName       APIP
host1    host1.domain.com    192.168.1.10   CiscoAP1     192.168.1.100

#>

$TestSet= Import-Csv 'C:\Scripts\Telesitter\TestSet.csv'
$SNVMC = Import-Csv 'C:\Scripts\Telesitter\NorthernVirginia.csv'
$SNG = Import-Csv 'C:\Scripts\Telesitter\Norfolk General.csv'
$SWRMC = Import-Csv 'C:\Scripts\Telesitter\Williamsburg.csv'
$SOH = Import-Csv 'C:\Scripts\Telesitter\Obici.csv' 
$SLH = Import-Csv 'C:\Scripts\Telesitter\Leigh.csv'
$SPAH = Import-Csv 'C:\Scripts\Telesitter\SPAH.csv'

#Read Audio file list
<#
AudioFile CSV
AudioFile  Position  FileName      FilePath
alert      M0        alert.wav     c:\scripts\project\alert.wav
#>

$AFL = Import-Csv 'C:\Scripts\Telesitter\AudioFileLoad.csv'

#Define Post API Base URI

$PAPI = "/axis-cgi/mediaclip.cgi?action=upload&media=audio&name="
$LF = "`r`n"

ForEach ($Item in $TestSet)
    {
       
       Write-Host $Item.Fname
       ForEach ($Entry in $AFL)
       {
            #$Uri = "http://"+$Item.FQDN+$PAPI+$Entry.AudioFile+"&Content-Type:multipart/form-data;boundary=--$Boundary"
            $Headers = @{
                'action' = 'upload'
                'media' = 'audio'
                'name' = $Entry.AudioFile
                         }
            $FilePath = $Entry.FilePath
            $FileContents = Get-Item $FilePath
            $FileBytes = [System.IO.File]::ReadAllBytes($FilePath);
            $FileEnc = [System.Text.Encoding]::GetEncoding('UTF-8').GetString($fileBytes)
            $Boundary = [System.Guid]::NewGuid().ToString()
            $Uri = "http://"+$Item.FQDN+$PAPI+$Entry.AudioFile#+"&Content-Type:multipart/form-data;boundary=--$Boundary"
            $Body = ( 
                        
                        
                        "--$boundary",
                        ('Content-Disposition: form-data; name="Content-Type"; filename="'+$Entry.FileName+'"'),
                        'Content-Type: audio/basic$LF',
                        $FileEnc,
                        "--$boundary--$LF" 
                    ) -join $LF
            
            Write-Host "Processing the the WAV file: "$Entry.AudioFile" for "$Item.Fname" using the URL "$Uri
            #Write-Host $Body
            $UploadAudio = Invoke-WebRequest -Uri $Uri -Credential $cred -Method Post -ContentType "multipart/form-data; boundary=--$Boundary" -Body $Body -Verbose
            $UploadAudio
       }
       
     } 

