param(
    [switch]$DeleteArchive,
    [switch]$DeleteImage,
    [switch]$Force,
    [switch]$NoLog,
    [switch]$NoPrompt,
    [switch]$SkipArchive
)

###############################################
# Helper Functions
###############################################

function ExecuteCommand($command) {
    Write-Host ">> Executing: $command"; Log "Executing: $command"

    try {
        $output = Invoke-Expression -Command $command -ErrorAction Stop
    } catch {
        Log "Error: $_"
        Log "StackTrace: $($_.StackTrace)"        
        throw "Error executing command: $command"
    }

    return $output
}

function Log($message) {
    if (!$NoLog) {
        $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
        $logPath = Join-Path -Path $scriptDirectory -ChildPath "logs\Optimize-PS1.log"
        
        if (!(Test-Path $logPath)) {
            New-Item -ItemType File -Path $logPath -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        $logEntry = "[$timestamp] $message"
        
        Add-Content -Path $logPath -Value $logEntry
    }
}

function Write-Divider {
    Write-Host ('-' * 15)
}

###############################################
# File operations
###############################################

function ArchiveMode($path) {
    Write-Host ">> Entering Archive Mode..."; Log "ARCHIVE MODE"
    Write-Divider
    $archives = Get-ChildItem -Recurse -Filter *.* | Where-Object { $_.Extension -match '\.7z|\.gz|\.rar' }
    
    if ($archives.Count -eq 0) {
        Write-Host "No archive files found!"; Log "Archive Mode skipped: No archive files found!"
        return
    }

    foreach ($archive in $archives) {
        Write-Host "Hashing archive: $($archive.FullName)"; Log "Hashing archive: $($archive.FullName)"
        $hashCommand = "7z h `"$($archive.FullName)`""
        ExecuteCommand $hashCommand
        Write-Divider
        Write-Host "Extracting archive: $($archive.FullName)"; Log "Extracting archive: $($archive.FullName)"
        $extractCommand = "7z e '.\$($archive.Name)' -y"
        ExecuteCommand $extractCommand
        Write-Divider

        # Move all .bin/.cue/.iso files to the parent folder
        $imageFiles = Get-ChildItem -Path $archive.Directory.FullName -Filter *.* -Include *.bin, *.cue, *.iso -Recurse
        foreach ($imageFile in $imageFiles) {
            $destinationPath = Join-Path $PWD $imageFile.Name
            Move-Item -Path $imageFile.FullName -Destination $destinationPath -Force
        }

        if ($DeleteArchive) {
            # Wait for the completion of the extraction before deleting the source archive
            Write-Host "Extraction completed. Deleting source archive: $($archive.FullName)"; Log "Deleting source archive: $($archive.FullName)"
            Start-Sleep -Seconds 1
            Log "Deleting source archive: $($archive.FullName)"
            Remove-Item -LiteralPath $archive.FullName
            Write-Divider
        }
    }
}

function ImageMode($path) {
    Write-Host ">> Entering Image Mode..."; Log "Entering Image Mode..."
    Write-Divider
    $images = Get-ChildItem -Recurse -Filter *.* | Where-Object { $_.Extension -match '\.cue|\.iso' }

    foreach ($image in $images) {
        $chdFilePath = Join-Path $image.Directory.FullName "$($image.BaseName).chd"
        $resolvedPath = (Resolve-Path -Path $chdFilePath -ErrorAction SilentlyContinue)?.Path

        if ($resolvedPath -eq $null) {
            $resolvedPath = Join-Path $image.Directory.FullName "$($image.BaseName).chd"
        }

        $forceOverwrite = $Force -or $F
        if (!$forceOverwrite -and !$NoPrompt -and (Test-Path $resolvedPath)) {
            $relativePath = (Resolve-Path -Path $chdFilePath -Relative).Path
            $overwrite = $null
            while ($overwrite -notin @('Y', 'N')) {
                $overwrite = Read-Host -Prompt "File .\$($relativePath) already exists. Do you want to overwrite? (Y/N)"
                $overwrite = $overwrite.ToUpper()
            }

            if ($overwrite -eq 'N') {
                Write-Host "Conversion skipped for $($image.FullName)"; Log "Skipping conversion for $($image.FullName)"
                Write-Divider
                continue
            }
        }

        $convertCommand = "chdman createcd -i '$($image.FullName)' -o '$resolvedPath'"
        
        # Add --force flag only if user confirms or $NoPrompt is specified
        if ($forceOverwrite -or $NoPrompt -or ($overwrite -eq 'Y')) {
            $convertCommand += " --force"
        }

        Log "Converting image: $($image.FullName)"
        ExecuteCommand $convertCommand
        Write-Divider

        if ($DeleteImage) {
            # Wait for the completion of the conversion before deleting the source image
            Write-Host "Conversion completed. Deleting source image: $($image.FullName)"; Log "Deleting source image: $($image.FullName)"            
            Start-Sleep -Seconds 1
        
            # Generate regex pattern for matching any .bin, .cue, or .iso files with the same base name
            $baseNameRegex = [regex]::Escape($image.BaseName)
            $pattern = "$baseNameRegex.*\.(bin|cue|iso)"
        
            # Delete corresponding .bin, .cue, and .iso files
            $matchingFiles = Get-ChildItem -Path $image.Directory.FullName -Filter "*.*" | Where-Object { $_.Name -match $pattern }
            foreach ($matchingFile in $matchingFiles) {
                Write-Host "Deleting corresponding file: $($matchingFile.FullName)"; Log "Deleting corresponding file: $($matchingFile.FullName)"
                Remove-Item -LiteralPath $matchingFile.FullName -Force
            }
        
            Write-Host "Source image and corresponding files deleted."; Log "Source image and corresponding files deleted."
            Write-Divider
        }             
    }
}



###############################################
# Main
###############################################

try {
    Write-Divider
    if ($SkipArchive) {
        ImageMode(Get-Location)
    } else {
        ArchiveMode(Get-Location)
        ImageMode(Get-Location)
    }

    Summarize
} catch {
    Write-Host "Error: $_"
}
