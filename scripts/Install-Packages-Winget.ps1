###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

###############################################
# Main Loop
###############################################

param (
    [string]$packagesFile = ".\config\packages_winget.txt",
    [switch]$force
)

try {
    $packages = Read-ConfigFile -FilePath $packagesFile

    foreach ($package in $packages) {
        if ($package.StartsWith("#")) {
            continue
        }

        $installCommand = "winget install $package -e -i"
        if ($force) {
            $installCommand += " --force"
        }
        Invoke-Expression $installCommand
    }

    Write-Console "Winget packages installation complete."
} catch {
    ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
}
