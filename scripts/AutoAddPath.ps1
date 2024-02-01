# Define exclusion list with wildcards
$exclusionList = @(
    "$($PSScriptRoot)\ext\NKit_v1.4\*"
)

# Backup system PATH variables
regedit /e "$env:TEMP\PATH_Backup.reg" "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"

# Initialize variables
$systemPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine").ToLower()
$currentPath = Get-Item -LiteralPath $PSScriptRoot | Select-Object -ExpandProperty FullName

# Get all directories excluding those in the exclusion list and subdirectories
$directories = Get-ChildItem -Recurse -Directory | Where-Object { 
    $excluded = $false
    foreach ($excludePattern in $exclusionList) {
        if ($_.FullName -like $excludePattern) {
            $excluded = $true
            break
        }
    }
    -not $excluded
} | Select-Object -ExpandProperty FullName

# Filter out directories that already exist in the system PATH
$directories = $directories | Where-Object { -not ($systemPath -split ';').Contains($_.ToLower()) }

# Display paths to the user
Write-Host "Paths to be added to PATH:"
foreach ($path in $directories) {
    Write-Output $path
}

# Prompt user to add paths
$declineAll = $false
foreach ($path in $directories) {
    if (-not $declineAll) {
        if (-not (Test-Path $path)) {
            Write-Host "Path '$path' does not exist. Skipped."
            Continue
        }

        $response = Read-Host @"
Do you want to add '$path' to PATH? 
[Y]es: Add this path to the system PATH
[N]o: Skip this path
[A]ll: Add all paths to the system PATH without further prompts
[D]ecline all: Skip all paths and exit
"@
        switch ($response) {
            "Y" { [System.Environment]::SetEnvironmentVariable("Path", "$($systemPath);$path", "Machine") }
            "N" { Write-Host "Skipped '$path'." }
            "A" { [System.Environment]::SetEnvironmentVariable("Path", "$($systemPath);$($directories -join ';')", "Machine"); $declineAll = $true; break }
            "D" { $declineAll = $true; break }  # Decline all
            Default { Write-Host "Invalid choice. Skipped '$path'." }
        }
    } else {
        Write-Host "Skipped '$path' (Declined all)."
    }
}

# Confirm completion
Write-Host "Path modification complete."
