<#
.SYNOPSIS
Extract-Archives is a PowerShell script designed to automate the extraction of files from archive formats, including .7z, .zip, and .rar, within a specified directory. It provides various options for customization and logging.

.DESCRIPTION
Extract-Archives simplifies the process of extracting files from archives. It supports the following features:
- Recursive search in subdirectories using the -r switch.
- Specifying the directory to search in using the -Directory parameter.
- Defining the archive types to extract (default: .7z, .zip, .rar) using the -FileTypes parameter.
- Logging actions to a file with the -LogToFile switch.
- Setting the log file path (default: extractLog.txt in the script's directory) with the -LogPath parameter.
- Running the script in silent mode without console output using the -SilentMode switch.
- Deciding on overwrite actions (Overwrite, Skip, or Ask) with the -OverwriteMode parameter.

.PARAMETERS
    -Directory
        Specifies the directory to start the extraction process. By default, it uses the current directory.

    -Recursive
        Enables recursive search in subdirectories for archive files.

    -OutputDirectory
        Specifies the directory to which extracted files will be saved.

    -FileTypes
        Defines the archive file types to extract. The default value is "\.(7z|zip|rar)$".

    -LogToFile
        Enables logging of actions to a file.

    -LogPath
        Sets the log file path. The default is "extractLog.txt" in the script's directory.

    -SilentMode
        Runs the script without displaying console output.

    -OverwriteMode
        Allows you to decide on overwrite actions when files or directories already exist ("Overwrite," "Skip," or "Ask").

.EXAMPLE
1. Extract all supported archive files in the current directory and its subdirectories:
   .\Extract-Archives.ps1 -r

.EXAMPLE
2. Extract all supported archive files in a specific directory and log actions to a file:
   .\Extract-Archives.ps1 -Directory 'C:\Path\To\Directory' -LogToFile

.EXAMPLE
3. Extract only .zip files and overwrite existing files without asking:
   .\Extract-Archives.ps1 -FileTypes '.zip' -OverwriteMode 'Overwrite'

.INPUTS
    String, SwitchParameters
    Inputs include the -Directory, -Recursive, -OutputDirectory, -FileTypes, -LogToFile, -LogPath, -SilentMode, and -OverwriteMode parameters.

.OUTPUTS
    File, String
    Outputs extracted files into folders named after their archive. Logs actions to console and log file, if specified.


.NOTES
    !!! MAKE BACKUPS BEFORE USING THIS SCRIPT !!!
    BE CAUTIOUS when using the -deleteSource parameter, as it deletes source files automatically.
    7-Zip MUST be installed with the $PATH environment variable(s) configured. https://www.7-zip.org/

    Script Version: 1.0
    Author: Slice
    Creation Date: 2023-12-07 03:30:00 GMT
#>

param(
    [string]$Directory = (Get-Location).Path,
    [switch]$Recursive = $false,
    [string]$OutputDirectory,
    [string]$FileTypes = "\.(7z|zip|rar)$",
    [switch]$LogToFile,
    [string]$LogPath = "$PSScriptRoot\extractLog.txt",
    [switch]$SilentMode,
    [ValidateSet("Overwrite", "Skip", "Ask")]
    [string]$OverwriteMode = "Ask"
)

function Write-OutputLog {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    if (-not $SilentMode) {
        Write-Host $Message
    }

    if ($LogToFile) {
        Add-Content -Path $LogPath -Value ("[" + (Get-Date) + "] " + $Message)
    }
}

# Determine the search criteria based on the provided arguments
$allFiles = if ($Recursive) {
    Get-ChildItem -Path $Directory -Recurse -File
} else {
    Get-ChildItem -Path $Directory -File
}

$filteredFiles = $allFiles | Where-Object { $_.Extension -match $FileTypes }

if (-not $filteredFiles) {
    Write-OutputLog "No matching files found."
    exit
}

$yesToAll = $false

foreach ($file in $filteredFiles) {
    Write-OutputLog "Processing file: $($file.FullName)"

    $destination = if ($OutputDirectory) {
        $OutputDirectory
    } else {
        Join-Path -Path $file.Directory -ChildPath $file.BaseName
    }

    if ((Test-Path $destination) -and ($OverwriteMode -eq "Skip")) {
        Write-OutputLog "Directory $destination already exists. Skipping..."
        continue
    }

    try {
        if ($OverwriteMode -eq "Ask" -and (Test-Path $destination) -and (-not $yesToAll)) {
            $userInput = Read-Host "Directory $destination already exists. Overwrite? (Y/N/A for Yes to All)"
            if ($userInput -eq 'A') {
                $yesToAll = $true
            } elseif ($userInput -ne 'Y') {
                continue
            }
        }

        & '7z' x "`"$($file.FullName)`"" "-o`"$destination`"" -y
        if ($LASTEXITCODE -ne 0) {
            Write-OutputLog "Error extracting $($file.FullName). 7z exit code: $LASTEXITCODE"
        } else {
            Write-OutputLog "Successfully extracted $($file.FullName)"
        }
    } catch {
        Write-OutputLog "Error extracting $($file.FullName). Error details: $_"
    }
}

Write-OutputLog "Extraction process completed!"
