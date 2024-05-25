<#
    .SYNOPSIS
        Add-Paths.ps1 - This script is designed to add directories to the system PATH.

    .DESCRIPTION
        !! This script must be run with Administrator privileges. !!
        This script adds directories to the system PATH variable. Use with caution!

    .PARAMETER
#>

<# 
    .DESCRIPTION
        Backup the current system PATH

    .PARAMETER BackupPath
        The path to save the backup to. Defaults to $env:TEMP\PATH_Backup.reg
#>
function Backup-SystemPathVariable {
    param (
        [string]$BackupPath
    )

    if (-not $BackupPath) {
        $BackupPath = Join-Path -Path $env:TEMP -ChildPath "PATH_Backup.reg"
    }

    reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" $BackupPath
    Write-Host "System PATH backed up to $BackupPath"
}

<#
    .DESCRIPTION
        GetDirectories returns all directories in the specified base directory, excluding any directories in the exclusion list.

    .PARAMETER BaseDirectory
        The base directory to search for directories.

    .PARAMETER ExclusionList
        The list of directories to exclude from the search.

    .OUTPUTS
        The list of directories in the base directory that do not match any directories in the exclusion list.
#>
function GetDirectories([string]$BaseDirectory, [string[]]$ExclusionList) {
    $all_directories = Get-ChildItem -Path $BaseDirectory -Recurse -Directory | Select-Object -ExpandProperty FullName

    $filtered_directories = $all_directories | Where-Object {
        $path = $_
        $exclude = $ExclusionList | Where-Object { $path -like $_ }
        return -not $exclude
    }

    return $filtered_directories
}


<# 
    .DESCRIPTION
        ValidatePaths validates that the specified directories exist in the system PATH.

    .PARAMETER Directories
        The list of directories to validate.

    .OUTPUTS
        The list of directories that exist in the system PATH.
#>
function ValidatePaths([Parameter(Mandatory = $true)][string[]]$Directories) {
    $system_path = [System.Environment]::GetEnvironmentVariable("Path", "Machine").ToLower().Split(';')
    $valid_directories = @()

    foreach ($directory in $Directories) {
        if ((Test-Path $directory) -and -not $system_path.Contains($directory.ToLower())) {
            $valid_directories += $directory
        }
    }

    return $valid_directories | Select-Object -Unique
}

<# 
    .DESCRIPTION
        AddToPath adds directories to the system PATH.

    .PARAMETER PathsToAdd
        The list of directories to add to the system PATH.

    .NOTES
        !! This function modifies the system PATH variable !!
#>
function AddToPath([string]$PathsToAdd) {
    $currentsystem_path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $new_path = ($currentsystem_path.Split(';') + $PathsToAdd | Select-Object -Unique) -join ';'

    [System.Environment]::SetEnvironmentVariable("Path", $new_path, "Machine")
}

function Add-ToSystemPath {
    param (
        [switch]$Recurse,
        [string]$Path
    )
    $exclusion_list = @(
        "$($PSScriptRoot)\ext\NKit_v1.4\*"
    )

    # Backup system PATH
    Backup-SystemPathVariable

    # Get current directory
    $current_path = $PSScriptRoot

    # Construct list of directories to add while filtering out exclusions by name.
    $directories = GetDirectories($current_path, $exclusion_list)

    # Filter out directories that already exist in the system PATH and validate existence
    $valid_directories = ValidatePaths($directories)

    # Display paths to the user for review
    Write-Host "Paths to be added to PATH:"
    $valid_directories | ForEach-Object { Write-Output $_ }

    # Prompt user to add paths
    if ($valid_directories.Length -gt 0) {
        $confirmation = Read-Host "Add paths to PATH? (Y/N)"
        if ($confirmation -eq "Y") {
            AddToPath($valid_directories)
        } else {
            Write-Host "Operation cancelled."
        }
    } else {
        Write-Host "No paths to add to PATH."
    }
}

$params = @{
    Recurse = $Recurse
    Path = $Path
}

if ($MyInvocation.InvocationName -ne '.') { Add-ToSystemPath @params }