param (
    [string]$packagesFile = ".\config\packages_winget.txt",
    [switch]$force
)

try {
    $packages = Get-Content $packagesFile -ErrorAction Stop

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

    Write-Host "Winget packages installation complete."
} catch {
    Write-Host "An error occurred: $_"
    Add-Content -Path "errorLog.txt" -Value ("[" + (Get-Date) + "] Error: $_")
    exit 1
}
