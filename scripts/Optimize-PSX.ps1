<#
.SYNOPSIS
    Optimize-PSX.PS1 - This script is designed to optimize PSX/PS2 images for emulator use. It extracts image files to CWD and then compresses to *.CHD format.

.DESCRIPTION
    !! This script must be run with Administrator privileges. !!
    This script extracts image files to CWD and then compresses them to *.CHD format. Ensure that 7-zip and chdman are installed!

.PARAMETER DeleteArchive
    Deletes the source archive automatically without prompting.

.PARAMETER DeleteImage
    Deletes the source image automatically without prompting.

.PARAMETER Help
    Displays this help message.

.PARAMETER Force
    Overwrites existing files without prompting.

.PARAMETER NoLog
    Does not write to the log file.

.PARAMETER SilentMode
    Suppresses console output.

.PARAMETER SkipArchive
    Skips the extraction of archives.

.EXAMPLE
    .\Optimize-PSX.ps1
    Extracts image files to CWD and then compresses them to *.CHD format.

.EXAMPLE
    .\Optimize-PSX.ps1 -SkipArchive
    Extracts image files to CWD and then compresses them to *.CHD format. Deletes the source archive automatically without prompting.

.EXAMPLE
    .\Optimize-PSX.ps1 -DeleteArchive -DeleteImage -Force
    Extracts image files to CWD and then compresses them to *.CHD format. Overwrites existing files and deletes sources without prompting.

.INPUTS
    None

.OUTPUTS
    String
    Logs actions to console and log file, if specified.

.LINK
    7-Zip: [7-Zip Website](https://www.7-zip.org)
    chdman: [chdman Documentation](https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman)

.NOTES
    Administrative privileges are required to run this script.
    Ensure required programs are installed and added to PATH.
    Required programs: 7-zip, chdman

    Script Version: 1.1
    Author: Chad
    Creation Date: 2023-12-07 03:30:00 GMT
    Last Updated: 2024-02-04 03:30:00 GMT
#>

###############################################
# Imports
###############################################

. .\lib\TextHandling.ps1
. .\lib\ErrorHandling.ps1

###############################################
# Parameters
###############################################

param (
    [alias("da")][switch]$DeleteArchive,    # Delete the source archive
    [alias("di")][switch]$DeleteImage,      # Delete the source image
    [alias("f")][switch]$Force,             # Force overwriting
    [alias("nl")][switch]$NoLog,            # Do not write to log file
    [alias("silent")][switch]$SilentMode,   # Silent mode
    [alias("sa")][switch]$SkipArchive       # Skip archive extraction
)

###############################################
# Objects
###############################################

$ScriptAttributes = @{
    LogFile = "logs\Optimize-PSX.log"
    StartTime = $null
    Version = "1.1"
}

$FileOperations = @{
    CHDFileList = @()
    InitialDirectorySizeBytes = 0
    TotalFileConversions = 0
    TotalFileDeletions = 0
    TotalFileExtractions = 0
    TotalFileOperations = 0
}

###############################################
# Helper Functions
###############################################

function Get-CurrentDirectorySize {
    $initialDirectorySizeBytes = (Get-ChildItem -Path . -Recurse -Force | Measure-Object -Property Length -Sum).Sum
    return $initialDirectorySizeBytes
}

function Invoke-Command() {
    param (
        [string]$Command
    )

    Write-Console "Executing: $Command`n"

    try {
        $output = Invoke-Expression $Command -ErrorAction Stop
    } catch {
        ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
    }

    Write-Log $output
    return $output
}

function Measure-FileOperations() {
    param (
        [hashtable]$FileOperations
    )
}

###############################################
# File operations
###############################################

function Expand-Archives() {
    param (
        [string]$Path
    )

    try {
        if (!(Get-Module 7Zip4Powershell -ListAvailable)) { Install-Module 7Zip4Powershell }

        Import-Module 7Zip4Powershell
    }
    catch { ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace }

    Write-Console "Entering Archive Mode...";
    Write-Divider -Strong
    $archives = Get-ChildItem -Recurse -Filter *.* | Where-Object { $_.Extension -match '\.7z|\.gz|\.rar|\.zip' }
    
    if ($archives.Count -eq 0) {
        Write-Console "Archive Mode skipped: No archive files found!"
        Write-Divider
        return
    }

    foreach ($archive in $archives) {
        $extractDestination = Join-Path $archive.Directory.FullName $archive.BaseName

        try {
            $hashValue = Get-FileHash -Algorithm SHA256 -LiteralPath $archive.FullName | Select-Object -ExpandProperty Hash

            Write-Console "Hashing archive: `"$($archive.FullName)`""
            Write-Console "SHA-256 hash: $hashValue"
            Write-Divider
        }
        catch { ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace }

        
        Write-Console "Extracting archive: `"$($archive.FullName)`""
        Expand-7Zip -ArchiveFileName $archive.FullName -TargetPath $extractDestination
        $FileOperations.TotalFileExtractions++; $FileOperations.TotalFileOperations++
        Write-Console "Extraction complete."
        Write-Divider -Strong
    
        # Move all .bin/.cue/.iso files to the parent folder
        $imageFiles = Get-ChildItem -Path $extractDestination -Filter *.* -Include *.bin, *.cue, *.gdi, *.iso, *.raw -Recurse
        foreach ($imageFile in $imageFiles) {
            $destinationPath = Join-Path $PWD $imageFile.Name
            Move-Item -Path $imageFile.FullName -Destination $destinationPath -Force
            $FileOperations.TotalFileOperations++
        }

        Remove-Item -Path $extractDestination -Force -Recurse
        $FileOperations.TotalFileDeletions++; $FileOperations.TotalFileOperations++
    
        if ($DeleteImage) {
            # Wait for the completion of the conversion before deleting the source image
            Write-Console "Conversion completed. Deleting source image: $($image.FullName)"           
        
            $escapedBaseName = $image.BaseName -replace '\[.*\]', '.*'
            $pattern = "^$escapedBaseName.*\.(bin|cue|gdi|iso|raw)$"
        
            Write-Console "Constructed pattern: $pattern"
        
            # Delete corresponding .bin, .cue, and .iso files
            $matchingFiles = Get-ChildItem -Path $image.Directory.FullName -Filter "*.*" | Where-Object { $_.Name -match $pattern }
        
            foreach ($matchingFile in $matchingFiles) {
                Write-Console "Deleting corresponding file: $($matchingFile.FullName)"
                Remove-Item -LiteralPath $matchingFile.FullName -Force
                $FileOperations.TotalFileDeletions++; $FileOperations.TotalFileOperations++
            }
        
            Write-Console "Source image and corresponding files deleted."
            Write-Divider
        }        
        
    }
    
    return $result
}

function Compress-Images() {
    param (
        [string]$Path
    )

    Write-Console "Entering Image Mode..."
    Write-Divider -Strong
    $images = Get-ChildItem -Recurse -Filter *.* | Where-Object { $_.Extension -match '\.cue|\.gdi|\.iso' }

    foreach ($image in $images) {
        $chdFilePath = Join-Path $image.Directory.FullName "$($image.BaseName).chd"
        $resolvedPath = (Resolve-Path -Path `"$chdFilePath`" -ErrorAction SilentlyContinue)?.Path

        if ($null -eq $resolvedPath) {
            $resolvedPath = Join-Path $image.Directory.FullName "$($image.BaseName).chd"
        }        

        $forceOverwrite = $Force -or $F
        if (!$forceOverwrite -and (Test-Path `"$resolvedPath`")) {
            $relativePath = (Resolve-Path -Path $chdFilePath -Relative).Path
            $overwrite = $null
            while ($overwrite -notin @('Y', 'N')) {
                $overwrite = Read-Console "File .\$($relativePath) already exists. Do you want to overwrite?"
                $overwrite = $overwrite.ToUpper()
            }

            if ($overwrite -eq 'N') {
                Write-Console "Conversion skipped for $($image.FullName)"
                Write-Divider
                continue
            }
        }

        $convertCommand = "chdman createcd -i `"$($image.FullName)`" -o `"$resolvedPath`""
        
        if ($forceOverwrite -or $Force -or ($overwrite -eq 'Y')) {
            $convertCommand += " --force"
        }

        Write-Console "Converting image: $($image.FullName)"
        Invoke-Command $convertCommand
        Write-Divider

        $FileOperations.CHDFileList += $image.Name
        $FileOperations.TotalFileConversions++; $FileOperations.TotalFileOperations++

        if ($DeleteImage) {
            # Wait for the completion of the conversion before deleting the source image
            Write-Console "Conversion completed. Deleting source image: $($image.FullName)"           
            
            $baseName = $image.BaseName -replace '[^\w\-\. ]', '*'
            Write-Console "Sanitized base name: $baseName"
            
            # Delete corresponding files excluding .chd
            $matchingFiles = Get-ChildItem -LiteralPath $image.Directory.FullName -File -Recurse -Exclude "*.chd" |
                             Where-Object { $_.BaseName -like "$($baseName)*" -and $_.Extension -notin ".chd" }
            
            foreach ($matchingFile in $matchingFiles) {
                Write-Console "Deleting corresponding file: $($matchingFile.FullName)"
                Remove-Item -LiteralPath $matchingFile.FullName -Force
                $FileOperations.TotalFileDeletions++; $FileOperations.TotalFileOperations++
            }
            
            Write-Console "Source image and corresponding files deleted."
            Write-Divider
        }        
        
    }
}

function Summarize() {
    param (
        [long]$InitialDirectorySizeBytes,
        [long]$FinalDirectorySizeBytes
    )

    $InitialDirectorySizeMB = [math]::Round($InitialDirectorySizeBytes / 1MB, 2)
    $FinalDirectorySizeMB = [math]::Round($FinalDirectorySizeBytes / 1MB, 2)

    $SavedOrLost = if ($FinalDirectorySizeBytes -lt $InitialDirectorySizeBytes) { "Saved" } else { "Lost" }
    $SpaceDifference = [math]::Round([math]::Abs($FinalDirectorySizeBytes - $InitialDirectorySizeBytes) / 1MB, 2)

    $StartTime = $ScriptAttributes.StartTime
    $EndTime = Get-Date
    $EstimatedRuntime = $EndTime - $StartTime

    Write-Console "Summary"
    Write-Divider -Strong
    Write-Console "Initial Directory Size: $InitialDirectorySizeBytes bytes ($InitialDirectorySizeMB MB)"
    Write-Console "Final Directory Size: $FinalDirectorySizeBytes bytes ($FinalDirectorySizeMB MB)"
    Write-Divider
    Write-Console "Total Difference: $SpaceDifference MB $SavedOrLost"
    Write-Divider -Strong
    Write-Console "Total Archives Extracted: $($FileOperations.TotalFileExtractions)"
    Write-Console "Total Images Converted: $($FileOperations.TotalFileConversions)"
    Write-Console "Total Files Deleted: $($FileOperations.TotalFileDeletions)"
    Write-Divider
    Write-Console "Total Operations: $($FileOperations.TotalFileOperations)"
    Write-Divider -Strong
    Write-Console "CHD Files Created Successfully:"
    foreach ($file in $FileOperations.CHDFileList) {
        Write-Console " + $file"
    }
    Write-Divider
    Write-Console "Operations completed in $($EstimatedRuntime.Minutes)m $($EstimatedRuntime.Seconds)s $($EstimatedRuntime.Milliseconds)ms"
    Write-Divider -Strong
}

###############################################
# Main
###############################################

try {
    $ScriptAttributes.StartTime = Get-Date
    $CWDSizeBytes_Before    = Get-CurrentDirectorySize
    $CWDSizeBytes_Current   = 0

    Write-Console "Optimize-PSX Script $($ScriptAttributes.Version)" -NoLog
    Write-Console "Written in PowerShell 7.4.1" -NoLog
    Write-Console "Uses 7-Zip: https://www.7-zip.org" -NoLog
    Write-Console "Uses chdman: https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman" -NoLog
    Write-Divider -Strong
    if (!$Force -and ($DeleteArchive -or $DeleteImage)) {
        Write-Console "Warning: `$DeleteArchive and/or `$DeleteImage are enabled. These options permanently delete ALL source files in their respective directories."
        Write-Console "Are you sure you want to continue? (Y/N)"
        $response = Read-Host
        if ($response -ne "Y") {
            Write-Console "Exiting..."
            exit
        }
    }

    if (!$SkipArchive) {
        Expand-Archives(Get-Location)
        if ($DeleteArchive) {
            Start-Sleep -Seconds 2
            Get-Process | Where-Object { $_.ProcessName -like '7z*' } | Stop-Process -Force
        }
    }
    Compress-Images(Get-Location)

    $CWDSizeBytes_Current = Get-CurrentDirectorySize

    Summarize $CWDSizeBytes_Before $CWDSizeBytes_Current
} catch { ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace }
