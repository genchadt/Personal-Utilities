###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

###############################################
# Functions
###############################################

function Install-Packages-Chocolatey {
    param (
        [string]$packagesFile = ".\config\packages_choco.txt",
        [switch]$force
    )
    
    try {
        $packages = Read-ConfigFile -FilePath $packagesFile
    
        foreach ($package in $packages) {
            if ($package.StartsWith("#")) {
                continue
            }
    
            $installCommand = if ($force) { "choco install $package -y"} else { "choco install $package" }
            Invoke-Expression $installCommand
        }
    
        Write-Host "Chocolatey packages installation complete."
    } catch {
        ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
    }
}

if ($MyInvocation.InvocationName -ne '.') { Install-Packages-Chocolatey }