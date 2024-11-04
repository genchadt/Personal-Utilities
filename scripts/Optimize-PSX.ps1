<#
.SYNOPSIS
    Optimize-PSX.PS1 - This script optimizes PSX/PS2 images for emulator use by extracting image files to the current working directory and compressing them to *.CHD format.

.DESCRIPTION
    The script extracts image files to the current working directory and then compresses them to *.CHD format using `chdman`. Ensure that 7-Zip and `chdman` are installed and added to the system PATH.

.PARAMETER DeleteArchive
    Deletes the source archive automatically without prompting.

.PARAMETER DeleteImage
    Deletes the source image automatically without prompting.

.PARAMETER Force
    Overwrites existing files without prompting.

.PARAMETER SilentMode
    Suppresses console output.

.PARAMETER SkipArchive
    Skips the extraction of archives.

.EXAMPLE
    .\Optimize-PSX.ps1
    Extracts image files to the current working directory and compresses them to *.CHD format.

.EXAMPLE
    .\Optimize-PSX.ps1 -SkipArchive
    Skips the extraction of archives and compresses existing image files to *.CHD format.

.EXAMPLE
    .\Optimize-PSX.ps1 -DeleteArchive -DeleteImage -Force
    Extracts image files, compresses them to *.CHD format, and deletes source files without prompting.

.INPUTS
    None

.OUTPUTS
    String
    Logs actions to the console.

.LINK
    7-Zip: https://www.7-zip.org
    chdman: https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman

.NOTES
    Administrative privileges are required to run this script.
    Ensure required programs are installed and added to PATH.
    Required programs: 7-Zip, chdman

    Script Version: 1.2.0
    Author: Chad
    Creation Date: 2023-12-07 03:30:00 GMT
    Last Updated: 2024-04-27 03:30:00 GMT
#>

###############################################
# Parameters
###############################################

param (
    [Alias("f")][switch]$Force,             # Force overwriting
    [Alias("silent")][switch]$SilentMode,   # Silent mode
    [Alias("sa")][switch]$SkipArchive,      # Skip archive extraction
    [switch]$DeleteArchive,                 # Delete the archive after extraction
    [switch]$DeleteImage                    # Delete the image after compression
)

###############################################
# Ensure Admin Privileges
###############################################

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires administrative privileges. Please run as Administrator."
    exit 1
}

###############################################
# Objects
###############################################

$ScriptAttributes = @{
    LogFile       = "logs\Optimize-PSX.log"
    StartTime     = Get-Date
    Version       = "1.2.0"
}

$FileOperations = @{
    ArchiveFileList      = @()
    CHDFileList          = @()
    ImageFileList        = @()
    FileSizeCHD          = 0
    FileSizeImage        = 0
    TotalFileConversions = 0
    TotalFileExtractions = 0
    TotalFileOperations  = 0
    DeletionCandidates   = @()
    InitialDirectorySize = 0
    FinalDirectorySize   = 0
}

###############################################
# Helper Functions
###############################################

function Write-Separator {
    [CmdletBinding()]
    param (
        [string]$Char = "=",
        [int]$Length = 50,
        [ConsoleColor]$Color = "DarkGray"
    )
    $line = $Char * $Length
    Write-Host $line -ForegroundColor $Color
}

###############################################
# Functions
###############################################

<#
.SYNOPSIS
    Extracts supported archive files in the specified path.

.DESCRIPTION
    Searches for archive files (.7z, .gz, .rar, .zip) in the specified path and extracts them using the 7Zip4Powershell module.
    Extracted image files are moved to the parent directory.

.PARAMETER Path
    The directory path where archives are located.

.EXAMPLE
    Expand-Archives -Path "C:\Games\Archives"

.NOTES
    Requires the 7Zip4Powershell module to be installed and imported.
#>
function Expand-Archives {
    param (
        [string]$Path
    )

    if (-not $SilentMode) {
        Write-Host "Entering Archive Mode..." -ForegroundColor Cyan
        Write-Separator
    }

    # Ensure the 7Zip4Powershell module is loaded
    if (!(Get-Module -Name 7Zip4Powershell)) {
        try {
            Import-Module -Name 7Zip4Powershell -ErrorAction Stop
            if (-not $SilentMode) {
                Write-Host "7Zip4Powershell module loaded successfully." -ForegroundColor Cyan
            }
        }
        catch {
            Write-Error "Failed to load 7Zip4Powershell module: $_"
            return
        }
    }

    # Get all supported archive files
    $archives = Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -match '\.7z$|\.gz$|\.rar$|\.zip$' }

    if ($archives.Count -eq 0) {
        if (-not $SilentMode) {
            Write-Host "Archive Mode skipped: No archive files found!" -ForegroundColor Cyan
            Write-Separator
        }
        return
    }

    foreach ($archive in $archives) {
        $extractDestination = Join-Path $archive.Directory.FullName $archive.BaseName
        $FileOperations.ArchiveFileList += $archive.FullName

        # Hash archive
        try {
            if (-not $SilentMode) {
                Write-Host "Hashing archive: $($archive.FullName)" -ForegroundColor Cyan
            }
            $hashValue = Get-FileHash -Algorithm SHA256 -LiteralPath $archive.FullName | Select-Object -ExpandProperty Hash
            if (-not $SilentMode) {
                Write-Host "SHA-256 hash: $hashValue" -ForegroundColor Cyan
                Write-Separator
            }
        }
        catch {
            Write-Error "Failed to hash archive '$($archive.FullName)': $_"
            continue
        }

        # Extract archive using 7Zip4Powershell
        try {
            if (-not $SilentMode) {
                Write-Host "Extracting archive: $($archive.FullName)" -ForegroundColor Cyan
            }

            # Use 7Zip4Powershell's Expand-7Zip cmdlet to extract the archive
            Expand-7Zip -ArchiveFileName $archive.FullName -TargetPath $extractDestination

            $FileOperations.TotalFileExtractions++
            $FileOperations.TotalFileOperations++

            if (-not $SilentMode) {
                Write-Host "Extraction complete." -ForegroundColor Green
                Write-Separator
            }
        }
        catch {
            Write-Error "Issue encountered while extracting archive '$($archive.FullName)': $_"
            continue
        }

        # Move all .bin/.cue/.iso/.gdi/.raw files to the parent folder
        $imageFiles = Get-ChildItem -Path $extractDestination -Recurse -Include *.bin, *.cue, *.gdi, *.iso, *.raw -File
        foreach ($imageFile in $imageFiles) {
            $destinationPath = Join-Path $PWD $imageFile.Name
            try {
                Move-Item -Path $imageFile.FullName -Destination $destinationPath -Force
                $FileOperations.TotalFileOperations++
                $FileOperations.ImageFileList += $imageFile.Name
                if (-not $SilentMode) {
                    Write-Host "Moved file: $($imageFile.FullName) to $destinationPath" -ForegroundColor Cyan
                }
            }
            catch {
                Write-Error "Failed to move file '$($imageFile.FullName)': $_"
            }
        }
    }

    # Update FileSizeImage
    $FileOperations.FileSizeImage = (Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -match '\.bin$|\.cue$|\.iso$|\.gdi$|\.raw$' } | Measure-Object -Property Length -Sum).Sum
}

<#
.SYNOPSIS
    Compresses image files to CHD format using chdman.

.DESCRIPTION
    Searches for image files (.cue, .gdi, .iso) in the specified path and compresses them to CHD format using chdman.

.PARAMETER Path
    The directory path where image files are located.

.EXAMPLE
    Compress-Images -Path "C:\Games\Images"

.NOTES
    Requires chdman to be installed and available in the system PATH.
#>
function Compress-Images {
    param (
        [string]$Path
    )

    if (-not $SilentMode) {
        Write-Host "Entering Image Mode..." -ForegroundColor Cyan
        Write-Separator
    }

    $images = Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -match '\.cue$|\.gdi$|\.iso$' }

    if ($images.Count -eq 0) {
        if (-not $SilentMode) {
            Write-Host "Image Mode skipped: No image files found!" -ForegroundColor Yellow
            Write-Separator
        }
        return
    }

    foreach ($image in $images) {
        $chdFilePath = Join-Path $image.Directory.FullName "$($image.BaseName).chd"
        $resolvedPath = Resolve-Path -Path $chdFilePath -ErrorAction SilentlyContinue

        if (-not $resolvedPath) {
            $resolvedPath = Join-Path $image.Directory.FullName "$($image.BaseName).chd"
        }

        $forceOverwrite = $Force
        if (-not $forceOverwrite -and (Test-Path -Path $chdFilePath)) {
            $relativePath = (Resolve-Path -Path $chdFilePath).Path -replace [regex]::Escape($PWD), '.\'
            $overwrite = ""
            while ($overwrite -notin @('Y', 'N')) {
                $overwrite = Read-Host "File $relativePath already exists. Do you want to overwrite? (Y/N)"
                $overwrite = $overwrite.ToUpper()
                if ($overwrite -notin @('Y', 'N')) {
                    Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Yellow
                }
            }

            if ($overwrite -eq 'N') {
                if (-not $SilentMode) {
                    Write-Host "Conversion skipped for $($image.FullName)" -ForegroundColor Yellow
                    Write-Separator
                }
                continue
            }
        }

        $convertCommand = "chdman createcd -i `"$($image.FullName)`" -o `"$chdFilePath`""
        if ($forceOverwrite) {
            $convertCommand += " --force"
        }

        if (-not $SilentMode) {
            Write-Host "Converting image: $($image.FullName)" -ForegroundColor Cyan
        }

        try {
            Invoke-Expression $convertCommand
            $FileOperations.CHDFileList += $chdFilePath
            $FileOperations.TotalFileConversions++
            $FileOperations.TotalFileOperations++

            if (-not $SilentMode) {
                Write-Host "Conversion complete for $($image.FullName)" -ForegroundColor Green
                Write-Separator
            }
        }
        catch {
            Write-Error "Failed to convert image '$($image.FullName)': $_"
        }
    }

    # Update FileSizeCHD
    $FileOperations.FileSizeCHD = (Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -eq '.chd' } | Measure-Object -Property Length -Sum).Sum
}

<#
.SYNOPSIS
    Removes specified files based on user confirmation.

.DESCRIPTION
    Identifies archive and image files that are candidates for deletion, and prompts the user for confirmation to delete them.

.PARAMETER Path
    The directory path where deletion candidates are located.

.NOTES
    Files that can be deleted include archives and image files.
#>
function Remove-DeletionCandidates {
    param (
        [string]$Path
    )

    # Identify deletion candidates
    $archives = Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -match '\.7z$|\.gz$|\.rar$|\.zip$' }
    $images = Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -match '\.bin$|\.cue$|\.iso$|\.gdi$|\.raw$' }

    $FileOperations.DeletionCandidates = $archives + $images

    if ($FileOperations.DeletionCandidates.Count -eq 0) {
        if (-not $SilentMode) {
            Write-Host "No files to delete." -ForegroundColor Cyan
        }
        return
    }

    if (-not $SilentMode) {
        Write-Host "File Deletion Candidates:" -ForegroundColor Cyan
        Write-Separator
        $FileOperations.DeletionCandidates | Select-Object FullName | Format-Table -AutoSize
        Write-Separator
    }

    $deleteAll = $false
    foreach ($candidate in $FileOperations.DeletionCandidates) {
        if ($deleteAll -or $Force) {
            try {
                Remove-Item -Path $candidate.FullName -Force
                $FileOperations.TotalFileOperations++
                if (-not $SilentMode) {
                    Write-Host "Deleted: $($candidate.FullName)" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "Failed to delete '$($candidate.FullName)': $_"
            }
            continue
        }

        $userChoice = ""
        while ($userChoice -notin @('Y', 'A', 'N', 'D')) {
            $userChoice = Read-Host "Delete '$($candidate.FullName)'? (Y)es/(A)ll/(N)o/(D)one"
            $userChoice = $userChoice.ToUpper()
            if ($userChoice -notin @('Y', 'A', 'N', 'D')) {
                Write-Host "Invalid input. Please enter Y, A, N, or D." -ForegroundColor Yellow
            }
        }

        switch ($userChoice) {
            'Y' {
                try {
                    Remove-Item -Path $candidate.FullName -Force
                    $FileOperations.TotalFileOperations++
                    if (-not $SilentMode) {
                        Write-Host "Deleted: $($candidate.FullName)" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Error "Failed to delete '$($candidate.FullName)': $_"
                }
            }
            'A' {
                $deleteAll = $true
                try {
                    Remove-Item -Path $candidate.FullName -Force
                    $FileOperations.TotalFileOperations++
                    if (-not $SilentMode) {
                        Write-Host "Deleted: $($candidate.FullName)" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Error "Failed to delete '$($candidate.FullName)': $_"
                }
            }
            'N' {
                if (-not $SilentMode) {
                    Write-Host "Skipping deletion of: $($candidate.FullName)" -ForegroundColor Yellow
                }
            }
            'D' {
                if (-not $SilentMode) {
                    Write-Host "No further deletions will be made." -ForegroundColor Yellow
                }
                return
            }
        }
    }
}

<#
.SYNOPSIS
    Displays a summary of the operations performed.

.DESCRIPTION
    Calculates size differences, time taken, and displays the summary of the operations performed during the script execution.

.NOTES
    Outputs the summary to the console.
#>
function Summarize {
    $EndTime = Get-Date
    $EstimatedRuntime = $EndTime - $ScriptAttributes.StartTime

    # Calculate size differences
    $sizeDifferenceBytes = $FileOperations.FileSizeImage - $FileOperations.FileSizeCHD
    $sizeDifferenceMB = [math]::Round($sizeDifferenceBytes / 1MB, 2)
    if ($sizeDifferenceBytes -gt 0) {
        $savedOrLost = "Saved"
    }
    elseif ($sizeDifferenceBytes -lt 0) {
        $savedOrLost = "Increased"
        $sizeDifferenceMB = [math]::Abs($sizeDifferenceMB)
    }
    else {
        $savedOrLost = "No Change"
    }

    # Summary Data
    $summaryData = @(
        [PSCustomObject]@{ Description = "File Size Difference"; Value = "$sizeDifferenceBytes bytes ($sizeDifferenceMB MB) $savedOrLost" }
        [PSCustomObject]@{ Description = "Total Archives Extracted"; Value = "$($FileOperations.TotalFileExtractions)" }
        [PSCustomObject]@{ Description = "Total Images Converted"; Value = "$($FileOperations.TotalFileConversions)" }
        [PSCustomObject]@{ Description = "Total Operations"; Value = "$($FileOperations.TotalFileOperations)" }
        [PSCustomObject]@{ Description = "Operations Completed in"; Value = "$($EstimatedRuntime.Minutes)m $($EstimatedRuntime.Seconds)s $($EstimatedRuntime.Milliseconds)ms" }
    )

    # Output the summary using Format-Table
    Write-Host "Optimization Summary:" -ForegroundColor Cyan
    $summaryData | Format-Table -AutoSize

    # List created CHD files
    if ($FileOperations.CHDFileList.Count -gt 0) {
        Write-Host "CHD Files Created Successfully:" -ForegroundColor Green
        $FileOperations.CHDFileList | Select-Object | Format-Table -AutoSize
    }
    else {
        Write-Host "No CHD files were created." -ForegroundColor Yellow
    }

    Write-Separator
}

###############################################
# Main Logic
###############################################

<#
.SYNOPSIS
    Main function to optimize PSX/PS2 images.

.DESCRIPTION
    Orchestrates the extraction of archives, compression of images, and cleanup of files based on parameters.

.PARAMETER Path
    The directory path where the operations are to be performed.

.NOTES
    Calls other functions: Expand-Archives, Compress-Images, Remove-DeletionCandidates, Summarize.
#>
function Optimize-PSX {
    param (
        [string]$Path = $PWD
    )

    try {
        $ScriptAttributes.StartTime = Get-Date
        $initial_directory_size = (Get-ChildItem -Path $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $FileOperations.InitialDirectorySize = $initial_directory_size

        if (-not $SilentMode) {
            Write-Host "Optimize-PSX Script $($ScriptAttributes.Version)" -ForegroundColor Cyan
            Write-Host "Written in PowerShell" -ForegroundColor Cyan
            Write-Host "Uses 7-Zip: https://www.7-zip.org" -ForegroundColor Cyan
            Write-Host "Uses chdman: https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman" -ForegroundColor Cyan
            Write-Separator
        }

        if (-not $SkipArchive) {
            Expand-Archives -Path $Path
            if ($DeleteArchive) {
                Start-Sleep -Seconds 2
                $archivesToDelete = Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -match '\.7z$|\.gz$|\.rar$|\.zip$' }
                foreach ($archive in $archivesToDelete) {
                    try {
                        Remove-Item -Path $archive.FullName -Force
                        $FileOperations.TotalFileOperations++
                        if (-not $SilentMode) {
                            Write-Host "Deleted archive: $($archive.FullName)" -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Error "Failed to delete archive '$($archive.FullName)': $_"
                    }
                }
            }
        }
        else {
            if (-not $SilentMode) {
                Write-Host "Archive Mode Skipped: User declined archive extraction." -ForegroundColor Yellow
            }
        }

        Compress-Images -Path $Path

        if ($DeleteArchive -or $DeleteImage) {
            Remove-DeletionCandidates -Path $Path
        }

        $final_directory_size = (Get-ChildItem -Path $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $FileOperations.FinalDirectorySize = $final_directory_size

        Summarize
    }
    catch {
        Write-Error "Optimization failed: $_"
    }
}

$params = @{
    Force          = $Force
    SilentMode     = $SilentMode
    SkipArchive    = $SkipArchive
    DeleteArchive  = $DeleteArchive
    DeleteImage    = $DeleteImage
}
Optimize-PSX @params
