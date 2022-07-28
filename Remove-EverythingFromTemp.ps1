$VerbosePreference = "continue"

$everythingFiles = (Get-ChildItem "C:\temp\Everything*")
if ( $null -ne $everythingFiles ) {
    & "c:\temp\everything.exe" "-uninstall-client-service"
    Start-Sleep -Seconds 5
    Stop-Process -Name Everything -Force   
    Start-Sleep -Seconds 5
}
$everythingFiles | Foreach-Object { Remove-Item "$($_.VersionInfo.FileName)" -Force -Recurse -ErrorAction SilentlyContinue }

$esFiles = @('C:\temp\es.exe','C:\temp\ES-1.1.0.20.zip','c:\temp\cli.c')
$esFiles | Foreach-Object { Remove-Item "$_" -Force -Recurse -ErrorAction SilentlyContinue }

Remove-Item "C:\temp\pseverything*" -Recurse -Force -ErrorAction Ignore

$filesFoundError = $false
if ( $(Get-ChildItem "C:\temp\Everything*") ) {
    Write-Error "Still seeing C:\temp\Everything*"
    $filesFoundError = $true
}

if ( $(Get-ChildItem "C:\temp\pseverything*") ) {
    Write-Error "Still seeing C:\temp\Everything*"
    $filesFoundError = $true
}

$esFiles | Foreach-Object { 
    if ( $(Test-Path "$_") ) { 
        $filesFoundError = $true
    } 
}


if ( $filesFoundError -eq $false ) {
    Write-Host "No files found"
    Exit 0
}
elseif ( $filesFoundError -eq $true) {
    Write-Error "Files remain"
    Exit 1
}