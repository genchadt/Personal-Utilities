###############################################
# Globals
###############################################

$defaultPackagesFile = ".\config\packages_winget.txt"

###############################################
# Imports
###############################################

# Module existence check
$modules = @(
    "$PSScriptRoot\lib\ErrorHandling.psm1",
    "$PSScriptRoot\lib\SysOperation.psm1",
    "$PSScriptRoot\lib\TextHandling.psm1"
)

foreach ($module in $modules) {
    if (Test-Path $module) {
        Import-Module $module
    } else {
        Write-Host "Warning: Module '$module' not found. Some functions may not work properly." -ForegroundColor Yellow
    }
}

###############################################
# Functions
###############################################

function Install-Packages-Winget {
    param (
        [Parameter(Position=0)]
        [string]$packagesFile = $defaultPackagesFile,
        [switch]$force
    )
    
    # Parameter validation
    if (-not (Test-Path $packagesFile)) {
        Write-Host "Error: The specified packages file '$packagesFile' does not exist." -ForegroundColor Red
        return
    }
    
    try {
        $packages = Get-Configuration -FilePath $packagesFile
        if (-not $packages) {
            Write-Host "Error: No packages found in the specified file." -ForegroundColor Red
            return
        }
        
        # Filter out comments and empty lines
        $packages = $packages | Where-Object { -not ($_ -match '^\s*#') -and (-not [string]::IsNullOrWhiteSpace($_)) }

        # Install packages sequentially
        foreach ($package in $packages) {
            $installCommand = "winget install $package -e -i"
            if ($force) {
                $installCommand += " --force"
            }

            try {
                Invoke-Expression $installCommand
                Write-Host "Successfully installed: $package" -ForegroundColor Green
            } catch {
                Write-Host "Failed to install: $package" -ForegroundColor Red
                # Log the error details
                ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
            }
        }

        Write-Console "Winget packages installation complete."
    } catch {
        ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
    }    
}

if ($MyInvocation.InvocationName -ne '.') {
    param (
        [string]$packagesFile = ".\config\packages_winget.txt",
        [switch]$force
    )
    Install-Packages-Winget -packagesFile $packagesFile -force:$force
}