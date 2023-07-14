<#
.SYNOPSIS
    Converts a string into a base32 encoded string
.DESCRIPTION
    Converts a string at parameter positon 0 or named parameter "-inputString" to a base32 encoded string
.NOTES
    Script by Adam Warner
    Conversion portion burrowed from https://humanequivalentunit.github.io/Base32-coding-the-scripting-way/  
.EXAMPLE
    PS> .\ConvertTo-Base32.ps1 "MyString"
    ===============================================================================
    $inputString:
    MyString

    $input as base32
    JUAHSACTAB2AA4QANEAG4ADHA000
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0,Mandatory = $true)]
    [String]$inputString
)
# Convert $inputString to a byte array
$bytes = [System.Text.Encoding]::Unicode.GetBytes($inputString)

# From https://humanequivalentunit.github.io/Base32-coding-the-scripting-way/
# Convert byte array $bytes to a string
$byteArrayAsBinaryString = -join $bytes.ForEach{
    [Convert]::ToString($_, 2).PadLeft(8, '0')
}

# Convert byte-string to base32 string
$encodedString = [regex]::Replace($byteArrayAsBinaryString, '.{5}', {
    param($Match)
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'[[Convert]::ToInt32($Match.Value, 2)]
})


$out = @"
===============================================================================
`$inputString:
$inputString

`$inputString as base32
$encodedString 
"@

Write-Host "$out"