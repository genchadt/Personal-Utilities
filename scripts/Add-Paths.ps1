function Backup-SystemPath {
    $backupPath = Join-Path -Path $env:TEMP -ChildPath "PATH_Backup.reg"
    reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" $backupPath
    Write-Host "System PATH backed up to $backupPath"
}

function Get-ValidDirectories {
    param (
        [string]$BaseDirectory,
        [string[]]$ExclusionList
    )

    $allDirectories = Get-ChildItem -Path $BaseDirectory -Recurse -Directory | Select-Object -ExpandProperty FullName

    $filteredDirectories = $allDirectories | Where-Object {
        $path = $_
        $exclude = $ExclusionList | Where-Object { $path -like $_ }
        return -not $exclude
    }

    return $filteredDirectories
}

function Find-NonExistingAndDuplicatePaths {
    param (
        [string[]]$Directories
    )

    $systemPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine").ToLower().Split(';')
    $validDirectories = @()

    foreach ($dir in $Directories) {
        if ((Test-Path $dir) -and -not $systemPath.Contains($dir.ToLower())) {
            $validDirectories += $dir
        }
    }

    return $validDirectories | Select-Object -Unique
}

function Add-PathsToSystemPath {
    param (
        [string[]]$PathsToAdd
    )

    $currentSystemPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $newPath = ($currentSystemPath.Split(';') + $PathsToAdd | Select-Object -Unique) -join ';'

    $confirmation = Read-Host "Confirm adding specified paths to system PATH? [Y/N]"
    if ($confirmation -eq 'Y') {
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Host "System PATH updated successfully."
    } else {
        Write-Host "Operation cancelled."
    }
}

# Main Script

# Define exclusion list with wildcards
$exclusionList = @(
    "$($PSScriptRoot)\ext\NKit_v1.4\*"
)

# Backup system PATH variables
Backup-SystemPath

# Initialize variables
$currentPath = Get-Item -LiteralPath $PSScriptRoot | Select-Object -ExpandProperty FullName

# Get all directories excluding those in the exclusion list and subdirectories
$directories = Get-ValidDirectories -BaseDirectory $currentPath -ExclusionList $exclusionList

# Filter out directories that already exist in the system PATH and validate existence
$validDirectories = Find-NonExistingAndDuplicatePaths -Directories $directories

# Display paths to the user for review
Write-Host "Paths to be added to PATH:"
$validDirectories | ForEach-Object { Write-Output $_ }

# Prompt user to add paths
if ($validDirectories.Count -gt 0) {
    Add-PathsToSystemPath -PathsToAdd $validDirectories
} else {
    Write-Host "No new valid paths to add."
}