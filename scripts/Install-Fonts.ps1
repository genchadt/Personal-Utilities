###############################################
# Install-Fonts
#
# Installs fonts recursively from the current directory.
###############################################

###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

Write-Console "Starting font installations..."
$fontsFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
$fontFiles = Get-ChildItem -Recurse -Filter *.ttf

foreach ($file in $fontFiles) {
    $fileName = $file.Name
    $fontPath = $file.FullName
    $destinationPath = "C:\Windows\fonts\$fileName"

    if (-not(Test-Path -Path $destinationPath)) {
        Write-Console "Installing font: $fileName"
        $fontsFolder.CopyHere($fontPath, 0x10) # The 0x10 flag is for silent operation, adjust as needed
    } else {
        Write-Console "Font already installed: $fileName"
    }
}
