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

    Script Version: 1.1.2
    Author: Chad
    Creation Date: 2023-12-07 03:30:00 GMT
    Last Updated: 2024-02-04 03:30:00 GMT
#>

###############################################
# Parameters
###############################################

param (
    [alias("da")][switch]$DeleteArchive,    # Delete source archive(s)
    [alias("di")][switch]$DeleteImage,      # Delete source image(s)
    [alias("f")][switch]$Force,             # Force overwriting
    [alias("silent")][switch]$SilentMode,   # Silent mode
    [alias("sa")][switch]$SkipArchive       # Skip archive extraction
)

###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

try {
    if (!(Get-Module 7Zip4Powershell -ListAvailable)) { Install-Module 7Zip4Powershell }

    Import-Module 7Zip4Powershell
}
catch { 
    Write-Console "Issue encountered while importing 7Zip4Powershell!"
    ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace -Severity Error
}

###############################################
# Objects
###############################################

$ScriptAttributes = @{
    LogFile                     = "logs\Optimize-PSX.log"
    StartTime                   = $null
    Version                     = "1.1.2"
}

$FileOperations = @{
    CHDFileList                 = @()
    DeletionCandidates          = @()
    DeletedArchives             = @()
    DeletedImages               = @()
    FinalDirectorySize     = 0
    InitialDirectorySize   = 0
    TotalFileConversions        = 0
    TotalFileDeletions          = 0
    TotalFileExtractions        = 0
    TotalFileOperations         = 0
}

###############################################
# Functions
###############################################

function Expand-Archives() {
    param (
        [string]$Path
    )

    $extractedFilesSize = 0

    Write-Console "Entering Archive Mode...";
    Write-Divider -Strong
    $archives = Get-ChildItem -Recurse -Filter *.* | Where-Object { $_.Extension -match '\.7z|\.gz|\.rar|\.zip' }
    
    if ($archives.Count -eq 0) {
        Write-Console "Archive Mode skipped: No archive files found!" -MessageType Info
        Write-Divider
        return
    }

    foreach ($archive in $archives) {
        $extractDestination = Join-Path $archive.Directory.FullName $archive.BaseName

        # Hash archive
        try {
            Write-Console "Hashing archive: `"$($archive.FullName)`""
            $hashValue = Get-FileHash -Algorithm SHA256 -LiteralPath $archive.FullName | Select-Object -ExpandProperty Hash
            Write-Console "SHA-256 hash: $hashValue"
            Write-Divider
        }
        catch { ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace }

        # Extract archive
        try {
            Write-Console "Extracting archive: `"$($archive.FullName)`""
            Expand-7Zip -ArchiveFileName $archive.FullName -TargetPath $extractDestination
            $FileOperations.TotalFileExtractions++; $FileOperations.TotalFileOperations++
            Write-Console "Extraction complete."
            Write-Divider -Strong
        }
        catch { 
            Write-Console "Issue encountered while extracting archive!"
            ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
        }

        # Determine total file size of all extracted files
        $extractedFiles = Get-ChildItem -Path $extractDestination -Recurse
        foreach ($extractedFile in $extractedFiles) {
            $extractedFilesSize += $extractedFile.Length
        }

        # Move all .bin/.cue/.iso files to the parent folder
        $imageFiles = Get-ChildItem -Path $extractDestination -Filter *.* -Include *.bin, *.cue, *.gdi, *.iso, *.raw -Recurse
        foreach ($imageFile in $imageFiles) {
            $destinationPath = Join-Path $PWD $imageFile.Name
            Move-Item -Path $imageFile.FullName -Destination $destinationPath -Force
            $FileOperations.TotalFileOperations++
        }

        if ($DeleteArchive) {
            $FileOperations.DeletionCandidates += $archive.FullName
        }
    
        if ($DeleteImage) {       
            $escapedBaseName = $image.BaseName -replace '\[.*\]', '.*'
            $pattern = "^$escapedBaseName.*\.(bin|cue|gdi|iso|raw)$"
        
            $matchingFiles = Get-ChildItem -Path $image.Directory.FullName -Filter "*.*" | Where-Object { $_.Name -match $pattern }
        
            foreach ($matchingFile in $matchingFiles) {
                $FileOperations.DeletionCandidates += $matchingFile.FullName
            }
            Write-Divider
            Write-Console "-DeleteArchive passed!" -MessageType Warning
            Write-Console "Source archives added to deletion candidates." -MessageType Warning
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

    if ($images.Count -eq 0) {
        Write-Console "Image Mode skipped: No image files found!" -MessageType Warning
        Write-Divider
        return
    }

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
                Write-Console
                $overwrite = Read-Console "File .\$($relativePath) already exists. Do you want to overwrite?" -Prompt YN -MessageType Warning
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

        $FileOperations.CHDFileList += $resolvedPath
        $FileOperations.TotalFileConversions++; $FileOperations.TotalFileOperations++

        if ($DeleteImage) {     
            $baseName = $image.BaseName -replace '[^\w\-\. ]', '*'

            # Delete corresponding files excluding .chd
            $matchingFiles = Get-ChildItem -LiteralPath $image.Directory.FullName -File -Recurse -Exclude "*.chd" |
                             Where-Object { $_.BaseName -like "$($baseName)*" -and $_.Extension -notin ".chd" }
            
            foreach ($matchingFile in $matchingFiles) {
                $FileOperations.DeletionCandidates += $matchingFile.FullName
                $FileOperations.TotalFileDeletions++; $FileOperations.TotalFileOperations++
            }
        }        
        
    }
}

function Remove-DeletionCandidates {
    Write-Console "File Deletion Candidates:"
    Write-Divider -Strong
    foreach ($candidate in $FileOperations.DeletionCandidates) {
        Write-Console "    + $candidate"
    }
    Write-Divider

    foreach ($candidate in $FileOperations.DeletionCandidates) {
        $userChoice = $null

        while ($userChoice -notin @('Y', 'A', 'N', 'D')) {
            $userChoice = Read-Console -Text "Are you sure you want to delete $candidate? (Y)es/(A)ll/(N)o/(D)one" -Prompt "YNAD" -MessageType Warning
            $userChoice = $userChoice.ToUpper()
        }

        switch ($userChoice) {
            'Y' { 
                Write-Console "Deleting $candidate"
                Remove-ItemSafely -Path $candidate
                $FileOperations.TotalFileDeletions++
                $FileOperations.TotalFileOperations++
            }
            'A' { 
                Write-Console "Deleting $candidate"
                Remove-ItemSafely -Path $candidate
                $FileOperations.TotalFileDeletions++
                $FileOperations.TotalFileOperations++
                continue
            }
            'N' { 
                Write-Console "Skipping $candidate"
            }
            'D' { 
                Write-Console "No further deletions to be made."
                return
            }
        }
    }
}

function Summarize {
    $InitialDirectorySize = $FileOperations.InitialDirectorySize
    $FinalDirectorySize = $FileOperations.FinalDirectorySize

    $SavedOrLost = if ($FinalDirectorySize.Bytes -lt $InitialDirectorySize.Bytes) { "Saved" } else { "Lost" }
    $SpaceDifferenceBytes = [math]::Abs($FinalDirectorySize.Bytes - $InitialDirectorySize.Bytes)
    $SpaceDifferenceMB = [math]::Round($SpaceDifferenceBytes / 1MB, 2)

    $StartTime = $ScriptAttributes.StartTime
    $EndTime = Get-Date
    $EstimatedRuntime = $EndTime - $StartTime

    # Define ANSI color codes
    $green = "`e[32m"
    $red = "`e[31m"
    $yellow = "`e[33m"
    $reset = "`e[0m"

    # Summary Data
    $summaryData = @(
        [PSCustomObject]@{ Description = "Initial Directory Size (Bytes)"; Value = "$green$($InitialDirectorySize.Bytes)$reset" }
        [PSCustomObject]@{ Description = "Initial Directory Size (KB)"; Value = "$green$($InitialDirectorySize.Kilobytes)$reset" }
        [PSCustomObject]@{ Description = "Initial Directory Size (MB)"; Value = "$green$($InitialDirectorySize.Megabytes)$reset" }
        [PSCustomObject]@{ Description = "Initial Directory Size (GB)"; Value = "$green$($InitialDirectorySize.Gigabytes)$reset" }
        [PSCustomObject]@{ Description = "Final Directory Size (Bytes)"; Value = "$red$($FinalDirectorySize.Bytes)$reset" }
        [PSCustomObject]@{ Description = "Final Directory Size (KB)"; Value = "$red$($FinalDirectorySize.Kilobytes)$reset" }
        [PSCustomObject]@{ Description = "Final Directory Size (MB)"; Value = "$red$($FinalDirectorySize.Megabytes)$reset" }
        [PSCustomObject]@{ Description = "Final Directory Size (GB)"; Value = "$red$($FinalDirectorySize.Gigabytes)$reset" }
        [PSCustomObject]@{ Description = "File Size Difference"; Value = "$yellow$SpaceDifferenceBytes bytes ($SpaceDifferenceMB MB) $SavedOrLost$reset" }
        [PSCustomObject]@{ Description = "Total Archives Extracted"; Value = "$($FileOperations.TotalFileExtractions)" }
        [PSCustomObject]@{ Description = "Total Images Converted"; Value = "$($FileOperations.TotalFileConversions)" }
        [PSCustomObject]@{ Description = "Total Files Deleted"; Value = "$($FileOperations.TotalFileDeletions)" }
        [PSCustomObject]@{ Description = "Total Operations"; Value = "$($FileOperations.TotalFileOperations)" }
        [PSCustomObject]@{ Description = "Operations Completed in"; Value = "$($EstimatedRuntime.Minutes)m $($EstimatedRuntime.Seconds)s $($EstimatedRuntime.Milliseconds)ms" }
    )

    # Output the summary using Format-Table
    $summaryData | Format-Table -AutoSize

    Write-Console "CHD Files Created Successfully:"
    foreach ($file in $FileOperations.CHDFileList) {
        Write-Console "    + $file"
    }
    Write-Divider -Strong
}

###############################################
# Main
###############################################

function Optimize-PSX() {
    param (
        [string]$Path
    )

    try {
        $ScriptAttributes.StartTime = Get-Date
        $initial_directory_size = Get-CurrentDirectorySize
        $FileOperations.InitialDirectorySize = $initial_directory_size.Kilobytes
    
        Write-Divider -Strong
        Write-Console "Optimize-PSX Script $($ScriptAttributes.Version)" -NoLog
        Write-Console "Written in PowerShell 7.4.1" -NoLog
        Write-Console "Uses 7-Zip: https://www.7-zip.org" -NoLog
        Write-Console "Uses chdman: https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman" -NoLog
        Write-Divider -Strong

        if (!$SkipArchive) {
            Expand-Archives(Get-Location)
            if ($DeleteArchive) {
                Start-Sleep -Seconds 2
                Get-Process | Where-Object { $_.ProcessName -like '7z*' } | Stop-Process -Force
            }
        } else {
            Write-Console "Archive Mode Skipped: User declined archive mode." -MessageType Warning
        }

        Compress-Images(Get-Location)

        if ($DeleteArchive -or $DeleteImage) {
            Remove-DeletionCandidates(Get-Location)
        }
    
        $final_directory_size = Get-CurrentDirectorySize
        $FileOperations.FinalDirectorySize = $final_directory_size.Kilobytes
    
        Summarize
    } catch { ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace }
}

if ($MyInvocation.InvocationName -ne '.') { Optimize-PSX -Path $Path -SkipArchive $SkipArchive -Force $Force -DeleteArchive $DeleteArchive -DeleteImage $DeleteImage }