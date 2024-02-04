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
    Version = "1.1"
}

$FileOperations = @{
    InitialDirectorySizeBytes = 0
    TotalFileConversions = 0
    TotalFileDeletions = 0
    TotalFileExtractions = 0
    TotalFileOperations = 0
}

###############################################
# Helper Functions
###############################################

function ErrorHandling() {
    param (
        [string]$errorMessage,
        [string]$stackTraceValue
    )

    Write-Divider
    Write-Console "Error: $errorMessage"
    Write-Console "StackTrace: `n$stackTraceValue"
    Write-Console "Exception Source: $($Error[0].InvocationInfo.ScriptName)"
    Write-Console "Exception Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Console "Exception Offset: $($Error[0].InvocationInfo.OffsetInLine)"
    Write-Divider
    throw "Error executing command"
}

function Get-CurrentDirectorySize {
    $initialDirectorySizeBytes = (Get-ChildItem -Path . -Recurse -Force | Measure-Object -Property Length -Sum).Sum
    return $initialDirectorySizeBytes
}

function Invoke-Command() {
    param (
        [string]$Command
    )

    Write-Console "Executing: $Command"

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

function Read-Console() {
    param (
        [string]$Text
    )

    $response = Read-Host -Prompt "$Text (Y)es / (A)ccept All / (N)o / (D)ecline All"

    return $response
}

function Write-Console() {
    param (
        [string]$Text,
        [switch]$NoLog
    )

    Write-Host ">> $Text"
    if (!$NoLog) { Write-Log -Message $Text }
}

function Write-Divider {
    Write-Console ('-' * 15) -NoLog
}

function Write-Log() {
    param (
        [string]$Message
    )

    $scriptDirectory = $PSScriptRoot

    if ($null -eq $scriptDirectory) {
        $scriptDirectory = Get-Location
    }

    $logPath = Join-Path -Path $scriptDirectory -ChildPath "logs\Optimize-PSX.log"

    if (!(Test-Path $logPath)) {
        New-Item -ItemType File -Path $logPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"

    # Read existing content
    $existingContent = Get-Content -Path $logPath -Raw

    # Prepend the new log entry
    $updatedContent = "$logEntry`r`n$existingContent"

    # Write the updated content back to the file
    Set-Content -Path $logPath -Value $updatedContent
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

    $initialDirectorySizeBytes = Get-CurrentDirectorySize
    $totalFileOperations = 0

    Write-Console "Entering Archive Mode...";
    Write-Divider
    $archives = Get-ChildItem -Recurse -Filter *.* | Where-Object { $_.Extension -match '\.7z|\.gz|\.rar' }
    
    if ($archives.Count -eq 0) {
        Write-Console "Archive Mode skipped: No archive files found!"
        return
    }

    foreach ($archive in $archives) {
        Write-Console "Hashing archive: $archive"
        $fileHash = Get-FileHash -Path $archive.FullName -Algorithm SHA256; $totalFileOperations += 1
        Write-Console "Archive's SHA-256 file hash: $($fileHash.Hash)"
        Write-Divider
        Write-Console "Extracting archive: $($archive.FullName)"
        $extractCommand = "7z x `".\$($archive.Name)`""; if ($Force) { $extractCommand += " -y" }
        Invoke-Command $extractCommand; $totalFileOperations +=1
        Write-Divider

        # Move all .bin/.cue/.iso files to the parent folder
        $imageFiles = Get-ChildItem -Path $archive.Directory.FullName -Filter *.* -Include *.bin, *.cue, *.iso -Recurse
        foreach ($imageFile in $imageFiles) {
            $destinationPath = Join-Path $PWD $imageFile.Name
            Move-Item -Path $imageFile.FullName -Destination $destinationPath -Force; $totalFileOperations += 1
        }

        if ($DeleteArchive) {
            # Wait for the completion of the extraction before deleting the source archive
            Write-Console "Extraction completed. Deleting source archive: $($archive.FullName)"
            Start-Sleep -Seconds 1
            try {
                Remove-Item -LiteralPath $archive.FullName; $totalFileOperations += 1
            }
            catch {
                ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
            }

            Write-Divider
        }
    }

    $result = [PSCustomObject]@{
        TotalFileOperations = $totalFileOperations
        InitialDirectorySizeBytes = $initialDirectorySizeBytes
    }    

    return $result
}

function Compress-Images() {
    param (
        [string]$Path
    )

    Write-Console "Entering Image Mode..."
    Write-Divider
    $images = Get-ChildItem -Recurse -Filter *.* | Where-Object { $_.Extension -match '\.cue|\.iso' }

    foreach ($image in $images) {
        $chdFilePath = Join-Path $image.Directory.FullName "$($image.BaseName).chd"
        $resolvedPath = (Resolve-Path -Path $chdFilePath -ErrorAction SilentlyContinue)?.Path

        if ($null -eq $resolvedPath) {
            $resolvedPath = Join-Path $image.Directory.FullName "$($image.BaseName).chd"
        }        

        $forceOverwrite = $Force -or $F
        if (!$forceOverwrite -and (Test-Path $resolvedPath)) {
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
        
        # Add --force flag only if user confirms or $Force is specified
        if ($forceOverwrite -or $Force -or ($overwrite -eq 'Y')) {
            $convertCommand += " --force"
        }

        Write-Console "Converting image: $($image.FullName)"
        Invoke-Command $convertCommand
        Write-Divider

        if ($DeleteImage) {
            # Wait for the completion of the conversion before deleting the source image
            Write-Console "Conversion completed. Deleting source image: $($image.FullName)"           
            Start-Sleep -Seconds 1
        
            # Generate regex pattern for matching any .bin, .cue, or .iso files with the same base name
            $baseNameRegex = [regex]::Escape($image.BaseName)
            $pattern = "$baseNameRegex.*\.(bin|cue|iso)"
        
            # Delete corresponding .bin, .cue, and .iso files
            $matchingFiles = Get-ChildItem -Path $image.Directory.FullName -Filter "*.*" | Where-Object { $_.Name -match $pattern }
            foreach ($matchingFile in $matchingFiles) {
                Write-Console "Deleting corresponding file: $($matchingFile.FullName)"
                Remove-Item -LiteralPath $matchingFile.FullName -Force
            }
        
            Write-Console "Source image and corresponding files deleted."
            Write-Divider
        }             
    }
}

function Summarize() {
    param (
        [int]$InitialDirectorySizeBytes,
        [int]$FinalDirectorySizeBytes,
        [int]$TotalFileOperations
    )

    Write-Console "Entering Summarize Mode..."
    Write-Divider
    Write-Console "Initial Directory Size: $InitialDirectorySizeBytes bytes"
    Write-Console "Final Directory Size: $FinalDirectorySizeBytes bytes"
    Write-Divider
}

###############################################
# Main
###############################################

try {
    Write-Console "Optimize-PSX Script $($ScriptAttributes.Version)" -NoLog
    Write-Console "Written in PowerShell 7.4.1" -NoLog
    Write-Console "Uses 7-Zip: https://www.7-zip.org" -NoLog
    Write-Console "Uses chdman: https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman" -NoLog
    if (!$SkipArchive) {
        Expand-Archives(Get-Location)
    }
    Compress-Images(Get-Location)

    Summarize
} catch { ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace }
