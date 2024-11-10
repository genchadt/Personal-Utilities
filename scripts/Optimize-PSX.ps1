[CmdletBinding()]
param (
    [switch]$Force,
    [switch]$SilentMode,
    [switch]$SkipArchive,
    [switch]$DeleteArchive,
    [switch]$DeleteImage
)

#region Helpers
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
#endregion

#region File Operations
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

        if (-not $Force -and (Test-Path -Path $chdFilePath)) {
            $relativePath = (Resolve-Path -Path $chdFilePath).Path -replace [regex]::Escape($PWD), '.\'
            $overwrite = Read-Host "File $relativePath already exists. Do you want to overwrite? (Y/N)" | ForEach-Object { $_.ToUpper() }
            if ($overwrite -eq 'N') {
                if (-not $SilentMode) {
                    Write-Host "Conversion skipped for $($image.FullName)" -ForegroundColor Yellow
                    Write-Separator
                }
                continue
            }
        }

        $convertCommand = "chdman createcd -i `"$($image.FullName)`" -o `"$chdFilePath`""
        if ($Force) {
            $convertCommand += " --force"
        }

        if (-not $SilentMode) {
            Write-Host "Converting image: $($image.FullName)" -ForegroundColor Cyan
        }

        try {
            Invoke-Expression $convertCommand
            if (-not $SilentMode) {
                Write-Host "Conversion complete for $($image.FullName)" -ForegroundColor Green
                Write-Separator
            }
        }
        catch {
            Write-Error "Failed to convert image '$($image.FullName)': $_"
        }
    }
}

function Expand-Archives {
    param (
        [string]$Path
    )

    if (-not $SilentMode) {
        Write-Host "Entering Archive Mode..." -ForegroundColor Cyan
        Write-Separator
    }

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

        try {
            if (-not $SilentMode) {
                Write-Host "Extracting archive: $($archive.FullName)" -ForegroundColor Cyan
            }

            Expand-7Zip -ArchiveFileName $archive.FullName -TargetPath $extractDestination

            if (-not $SilentMode) {
                Write-Host "Extraction complete." -ForegroundColor Green
                Write-Separator
            }
        }
        catch {
            Write-Error "Issue encountered while extracting archive '$($archive.FullName)': $_"
            continue
        }

        $imageFiles = Get-ChildItem -Path $extractDestination -Recurse -Include *.bin, *.cue, *.gdi, *.iso, *.raw -File
        foreach ($imageFile in $imageFiles) {
            $destinationPath = Join-Path $PWD $imageFile.Name
            try {
                Move-Item -Path $imageFile.FullName -Destination $destinationPath -Force
                if (-not $SilentMode) {
                    Write-Host "Moved file: $($imageFile.FullName) to $destinationPath" -ForegroundColor Cyan
                }
            }
            catch {
                Write-Error "Failed to move file '$($imageFile.FullName)': $_"
            }
        }
    }
}

function Remove-DeletionCandidates {
    param (
        [string]$Path
    )

    $archives = Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -match '\.7z$|\.gz$|\.rar$|\.zip$' }
    $images = Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -match '\.bin$|\.cue$|\.iso$|\.gdi$|\.raw$' }

    $deletionCandidates = $archives + $images

    if ($deletionCandidates.Count -eq 0) {
        if (-not $SilentMode) {
            Write-Host "No files to delete." -ForegroundColor Cyan
        }
        return
    }

    if (-not $SilentMode) {
        Write-Host "File Deletion Candidates:" -ForegroundColor Cyan
        Write-Separator
        $deletionCandidates | Select-Object FullName | Format-Table -AutoSize
        Write-Separator
    }

    $deleteAll = $false
    foreach ($candidate in $deletionCandidates) {
        if ($deleteAll -or $Force) {
            try {
                Remove-Item -Path $candidate.FullName -Force
                if (-not $SilentMode) {
                    Write-Host "Deleted: $($candidate.FullName)" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "Failed to delete '$($candidate.FullName)': $_"
            }
            continue
        }

        $userChoice = Read-Host "Delete '$($candidate.FullName)'? (Y)es/(A)ll/(N)o/(D)one" | ForEach-Object { $_.ToUpper() }
        switch ($userChoice) {
            'Y' {
                try {
                    Remove-Item -Path $candidate.FullName -Force
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
#endregion

#region Summarization
function Summarize {
    param (
        [int64]$InitialSize,
        [int64]$FinalSize,
        [int]$TotalExtractions,
        [int]$TotalConversions,
        [int]$TotalOperations
    )

    $EndTime = Get-Date
    $EstimatedRuntime = $EndTime - $ScriptAttributes.StartTime

    $sizeDifferenceBytes = $FinalSize - $InitialSize
    $sizeDifferenceMB = [math]::Round($sizeDifferenceBytes / 1MB, 2)
    $savedOrLost = if ($sizeDifferenceBytes -gt 0) { "Increased" } elseif ($sizeDifferenceBytes -lt 0) { "Saved" } else { "No Change" }

    $summaryData = @(
        [PSCustomObject]@{ Description = "File Size Difference"; Value = "$sizeDifferenceBytes bytes ($sizeDifferenceMB MB) $savedOrLost" }
        [PSCustomObject]@{ Description = "Total Archives Extracted"; Value = "$TotalExtractions" }
        [PSCustomObject]@{ Description = "Total Images Converted"; Value = "$TotalConversions" }
        [PSCustomObject]@{ Description = "Total Operations"; Value = "$TotalOperations" }
        [PSCustomObject]@{ Description = "Operations Completed in"; Value = "$($EstimatedRuntime.Minutes)m $($EstimatedRuntime.Seconds)s $($EstimatedRuntime.Milliseconds)ms" }
    )

    Write-Host "Optimization Summary:" -ForegroundColor Cyan
    $summaryData | Format-Table -AutoSize
    Write-Separator
}
#endregion

function Optimize-PSX {
    param (
        [string]$Path = $PWD
    )

    try {
        $initialDirectorySize = (Get-ChildItem -Path $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $totalExtractions = 0
        $totalConversions = 0
        $totalOperations = 0

        if (-not $SilentMode) {
            Write-Host "Optimize-PSX Script" -ForegroundColor Cyan
            Write-Host "Written in PowerShell" -ForegroundColor Cyan
            Write-Host "Uses 7-Zip: https://www.7-zip.org" -ForegroundColor Cyan
            Write-Host "Uses chdman: https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman" -ForegroundColor Cyan
            Write-Separator
        }

        if (-not $SkipArchive) {
            Expand-Archives -Path $Path
            $totalExtractions++
            if ($DeleteArchive) {
                Start-Sleep -Seconds 2
                $archivesToDelete = Get-ChildItem -Path $Path -Recurse -File | Where-Object { $_.Extension -match '\.7z$|\.gz$|\.rar$|\.zip$' }
                foreach ($archive in $archivesToDelete) {
                    try {
                        Remove-Item -Path $archive.FullName -Force
                        $totalOperations++
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
        $totalConversions++

        if ($DeleteArchive -or $DeleteImage) {
            Remove-DeletionCandidates -Path $Path
        }

        $finalDirectorySize = (Get-ChildItem -Path $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum

        Summarize -InitialSize $initialDirectorySize -FinalSize $finalDirectorySize -TotalExtractions $totalExtractions -TotalConversions $totalConversions -TotalOperations $totalOperations
    }
    catch {
        Write-Error "Optimization failed: $_"
    }
}

Optimize-PSX @PSBoundParameters