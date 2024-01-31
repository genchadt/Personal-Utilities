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
        Write-Divider
    } catch {
        Log "Error encountered:"
        Log "Error: $_"
        throw "Error executing command: $command"
    }

    # Print the full output to the console
    Write-Host "Output: $output"

    return $output
}

function Log($message) {
    if (!$NoLog) {
        $logPath = ".\logs\Optimize-PS1.log"
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
        Log "Extracting archive: $($archive.FullName)"
        $hashCommand = "7z h `"$($archive.FullName)`""
        ExecuteCommand $hashCommand
        $extractCommand = "7z e `"$($archive.FullName)`" -o`"$($PSScriptRoot)`""
        ExecuteCommand $extractCommand

        # Move all .bin/.cue/.iso files to the parent folder
        $imageFiles = Get-ChildItem -Path $archive.Directory.FullName -Filter *.* -Include *.bin, *.cue, *.iso -Recurse
        foreach ($imageFile in $imageFiles) {
            $destinationPath = Join-Path $PSScriptRoot $imageFile.Name
            Move-Item -Path $imageFile.FullName -Destination $destinationPath -Force
        }

        if ($DeleteArchive) {
            # Wait for the completion of the extraction before deleting the source archive
            Wait-Sleep -Seconds 2
            Log "Deleting source archive: $($archive.FullName)"
            Remove-Item -LiteralPath $archive.FullName
        }
    }
}

function ImageMode($path) {
    Write-Host ">> Entering Image Mode..."; Log "Entering Image Mode..."
    Write-Divider
    $images = Get-ChildItem -Recurse -Filter *.* | Where-Object { $_.Extension -match '\.cue|\.iso' }

    foreach ($image in $images) {
        $chdFilePath = "$($image.Directory.FullName)\$($image.BaseName).chd"

        if (Test-Path $chdFilePath) {
            $forceOverwrite = $Force -or $F
            if (!$forceOverwrite -and !$NoPrompt) {
                $overwrite = $null  # Initialize variable
                while ($overwrite -notin @('Y', 'N')) {
                    $overwrite = Read-Host -Prompt "File $($chdFilePath) already exists. Do you want to overwrite? (Y/N)"
                    $overwrite = $overwrite.ToUpper()
                }

                if ($overwrite -eq 'N') {
                    Log "Skipping conversion for $($image.FullName)"
                    continue
                }
            }
        }

        $convertCommand = "chdman createcd -i '$($image.FullName)' -o '$chdFilePath'"
        
        # Add --force flag only if user confirms or $NoPrompt is specified
        if ($forceOverwrite -or $NoPrompt -or ($overwrite -eq 'Y')) {
            $convertCommand += " --force"
        }

        Log "Converting image: $($image.FullName)"
        ExecuteCommand $convertCommand

        if ($DeleteImage) {
            # Wait for the completion of the conversion before deleting the source image
            WriteLog "Conversion completed. Deleting source image: $($image.FullName)"; Log "Deleting source image: $($image.FullName)"            
            Wait-Sleep -Seconds 1
            Remove-Item -LiteralPath $image.FullName
            WriteLog "Source image deleted."; Log "Source image deleted."
            Write-Divider
        }
    }
}

###############################################
# Main
###############################################

try {
    if ($!SkipArchive) {
        ArchiveMode(Get-Location)
    }

    ImageMode(Get-Location)

    Summarize
} catch {
    Write-Host "Error: $_"
}
