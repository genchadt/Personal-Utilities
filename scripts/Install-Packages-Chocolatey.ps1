param (
    [string]$packagesFile = ".\config\packages_choco.txt",
    [switch]$force
)

try {
    $packages = Get-Content $packagesFile -ErrorAction Stop

    foreach ($package in $packages) {
        if ($package.StartsWith("#")) {
            continue
        }

        $installCommand = if ($force) { "choco install $package -y"} else { "choco install $package" }
        Invoke-Expression $installCommand
    }

    Write-Host "Chocolatey packages installation complete."
} catch {
    Write-Host "An error occurred: $_"
    Add-Content -Path "errorLog.txt" -Value ("[" + (Get-Date) + "] Error: $_")
    exit 1
}