function Backup-system_path {
    $backup_path = Join-Path -Path $env:TEMP -ChildPath "PATH_Backup.reg"
    reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" $backup_path
    Write-Host "System PATH backed up to $backup_path"
}

function Get-valid_directories {
    param (
        [string]$BaseDirectory,
        [string[]]$ExclusionList
    )

    $all_directories = Get-ChildItem -Path $BaseDirectory -Recurse -Directory | Select-Object -ExpandProperty FullName

    $filtered_directories = $all_directories | Where-Object {
        $path = $_
        $exclude = $ExclusionList | Where-Object { $path -like $_ }
        return -not $exclude
    }

    return $filtered_directories
}

function Find-NonExistingAndDuplicatePaths {
    param (
        [string[]]$Directories
    )

    $system_path = [System.Environment]::GetEnvironmentVariable("Path", "Machine").ToLower().Split(';')
    $valid_directories = @()

    foreach ($dir in $Directories) {
        if ((Test-Path $dir) -and -not $system_path.Contains($dir.ToLower())) {
            $valid_directories += $dir
        }
    }

    return $valid_directories | Select-Object -Unique
}

function Add-PathsTosystem_path {
    param (
        [string[]]$PathsToAdd
    )

    $currentsystem_path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $new_path = ($currentsystem_path.Split(';') + $PathsToAdd | Select-Object -Unique) -join ';'

    $confirmation = Read-Host "Confirm adding specified paths to system PATH? [Y/N]"
    if ($confirmation -eq 'Y') {
        [System.Environment]::SetEnvironmentVariable("Path", $new_path, "Machine")
        Write-Host "System PATH updated successfully."
    } else {
        Write-Host "Operation cancelled."
    }
}

function Add-Paths {
    # Define exclusion list with wildcards
    $exclusionList = @(
        "$($PSScriptRoot)\ext\NKit_v1.4\*"
    )

    # Backup system PATH variables
    Backup-system_path

    # Initialize variables
    $current_path = Get-Item -LiteralPath $PSScriptRoot | Select-Object -ExpandProperty FullName

    # Get all directories excluding those in the exclusion list and subdirectories
    $directories = Get-valid_directories -BaseDirectory $current_path -ExclusionList $exclusionList

    # Filter out directories that already exist in the system PATH and validate existence
    $valid_directories = Find-NonExistingAndDuplicatePaths -Directories $directories

    # Display paths to the user for review
    Write-Host "Paths to be added to PATH:"
    $valid_directories | ForEach-Object { Write-Output $_ }

    # Prompt user to add paths
    if ($valid_directories.Count -gt 0) {
        Add-PathsTosystem_path -PathsToAdd $valid_directories
    } else {
        Write-Host "No new valid paths to add."
    }
}

if ($MyInvocation.InvocationName -ne '.') { Add-Paths }