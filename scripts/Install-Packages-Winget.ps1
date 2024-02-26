param (
    [string]$packagesFile = ".\config\packages_winget.txt",
    [switch]$force
)

try {
    $packages = Get-Content $packagesFile -ErrorAction Stop

    foreach ($package in $packages) {
        $installCommand = "winget install $package"
        if ($force) {
            $installCommand += " --force"
        }
        Invoke-Expression $installCommand
    }

    Write-Host "Winget packages installation complete."
} catch {
    Write-Host "An error occurred: $_"
    Add-Content -Path "errorLog.txt" -Value ("[" + (Get-Date) + "] Error: $_")
    exit 1
}
