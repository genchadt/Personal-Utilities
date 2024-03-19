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

$jobs = @()

foreach ($file in $fontFiles) {
    $job = Start-Job -ScriptBlock {
        param($file, $fontsFolder)
        $fileName = $file.Name
        $fontPath = $file.FullName
        $destinationPath = "C:\Windows\fonts\$fileName"

        if (-not(Test-Path -Path $destinationPath)) {
            Write-Console "Installing font: $fileName"
            $fontsFolder.CopyHere($fontPath)
        } else {
            Write-Console "Font already installed: $fileName"
        }
    } -ArgumentList $file, $fontsFolder
    $jobs += $job
}

# Wait for all jobs to complete
$jobs | Wait-Job

# Output any results from the jobs
$jobs | ForEach-Object {
    Receive-Job -Job $_
}

# Clean up the jobs
$jobs | Remove-Job
