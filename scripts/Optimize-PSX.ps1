[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Position=0)]
    [string]$Path = $PWD,
    [switch]$Force,
    [switch]$SkipArchive,
    [switch]$DeleteArchive,
    [switch]$DeleteImage,
    [string]$ChdmanPath = "chdman",
    [string]$LogFile,
    [ValidateSet("Minimal", "Normal", "Verbose")]
    [string]$Verbosity = "Normal"
)

#region Configuration
$VALID_ARCHIVE_EXTENSIONS = @('.7z', '.gz', '.rar', '.zip')
$VALID_IMAGE_EXTENSIONS = @('.cue', '.gdi', '.iso', '.bin', '.raw')
$SCRIPT_VERSION = "1.1.0"
#endregion

#region Logging
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        [ConsoleColor]$ForegroundColor = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Only output DEBUG messages when Verbosity is Verbose
    if ($Level -eq "DEBUG" -and $Verbosity -ne "Verbose") {
        return
    }
    
    # Skip INFO messages when Verbosity is Minimal unless they're important
    if ($Level -eq "INFO" -and $Verbosity -eq "Minimal" -and !($Message -match "^(Converting|Extracting|Summary)")) {
        return
    }
    
    # Console output - only the message without timestamp or level prefix
    switch ($Level) {
        "WARNING" { 
            if ($Verbosity -ne "Minimal" -or $Message -match "^(Converting|Extracting|Summary)") {
                Write-Host $Message -ForegroundColor Yellow 
            }
        }
        "INFO"    { 
            if ($Verbosity -ne "Minimal" -or $Message -match "^(Converting|Extracting|Summary)") {
                Write-Host $Message -ForegroundColor $ForegroundColor 
            }
        }
        "ERROR"   { Write-Host $Message -ForegroundColor Red }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "DEBUG"   { Write-Host $Message -ForegroundColor DarkGray }
    }
    
    # For log file, keep the timestamp and level prefix for all messages
    if ($LogFile) {
        try {
            $logMessage = "[$timestamp] [$Level] $Message"
            Add-Content -LiteralPath $LogFile -Value $logMessage -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to write to log file: $_" -ForegroundColor Red
        }
    }
}

function Write-Separator {
    param (
        [string]$Char = "=",
        [int]$Length = 50
    )
    
    $line = $Char * $Length
    if ($Verbosity -ne "Minimal") {
        Write-Host $line -ForegroundColor DarkGray
    }
    
    if ($LogFile) {
        Add-Content -LiteralPath $LogFile -Value $line
    }
}
#endregion

#region Helpers
function Test-CommandExists {
    param([string]$Command)
    try { 
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch { return $false }
}

function Get-FolderSize {
    param([string]$Path)
    
    try {
        $size = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction Stop | 
            Measure-Object -Property Length -Sum -ErrorAction Stop).Sum
        return $size
    }
    catch {
        Write-Log "Error calculating folder size for '$Path': $_" -Level ERROR
        return 0
    }
}

function Format-FileSize {
    param([double]$SizeInBytes)
    
    if ($SizeInBytes -ge 1GB) {
        return "{0:N2} GB" -f ($SizeInBytes / 1GB)
    }
    elseif ($SizeInBytes -ge 1MB) {
        return "{0:N2} MB" -f ($SizeInBytes / 1MB)
    }
    elseif ($SizeInBytes -ge 1KB) {
        return "{0:N2} KB" -f ($SizeInBytes / 1KB)
    }
    else {
        return "{0:N0} Bytes" -f $SizeInBytes
    }
}
#endregion

#region File Operations
function Compress-Images {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$Path,
        [ref]$TotalConversions,
        [ref]$FailedConversions,
        [switch]$Force
    )
    
    Write-Log "Converting Images to CHDs..." -Level INFO -ForegroundColor Cyan
    Write-Separator

    # Calculate 50% of available cores (minimum 1)
    $totalCores = [Environment]::ProcessorCount
    $coresToUse = [Math]::Max(1, [Math]::Floor($totalCores / 2))
    Write-Log "Using $coresToUse of $totalCores available CPU cores" -Level DEBUG

    # First look for .cue and .gdi files
    $primaryFiles = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.Extension -in @('.cue', '.gdi') }

    # Then look for standalone .iso files (no .cue or .gdi should exist)
    $isoFiles = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.Extension -eq '.iso' -and
            -not (Test-Path -LiteralPath (Join-Path $_.Directory "$($_.BaseName).cue")) -and
            -not (Test-Path -LiteralPath (Join-Path $_.Directory "$($_.BaseName).gdi"))
        }

    $images = @($primaryFiles) + @($isoFiles)

    if (-not $images -or $images.Count -eq 0) {
        Write-Log "No supported image files found!" -Level WARNING
        Write-Separator
        return
    }

    Write-Log "Found $($images.Count) image files to process" -Level INFO
    
    $totalImages = $images.Count
    $processedImages = 0
    $successfulConversions = 0
    $errorList = @()
    
    # Process images sequentially
    foreach ($image in $images) {
        $processedImages++
        Write-Progress -Activity "Converting images to CHD" -Status "$processedImages of $totalImages" -PercentComplete ($processedImages / $totalImages * 100)
        
        $chdFilePath = Join-Path $image.Directory.FullName "$($image.BaseName).chd"
        
        if ((-not $Force) -and (Test-Path -LiteralPath $chdFilePath)) {
            if (-not $PSCmdlet.ShouldContinue("CHD file already exists: $([System.IO.Path]::GetRelativePath($PWD, $chdFilePath))", "Overwrite existing CHD files?")) {
                Write-Log "Skipping conversion for $($image.Name)" -Level WARNING
                continue
            }
        }
        
        if (-not $PSCmdlet.ShouldProcess($image.FullName, "Convert to CHD")) {
            Write-Log "WhatIf: Would convert $($image.Name) to CHD" -Level INFO
            continue
        }
        
        try {
            Write-Log "Converting $($image.Name)..." -Level INFO -ForegroundColor Cyan
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $ChdmanPath
            
            # Choose appropriate command based on file type
            if ($image.Extension -eq '.gdi') {
                Write-Log "Detected Dreamcast GDI image..." -Level DEBUG
                # Get the first track's sector size from the GDI file
                $gdiContent = Get-Content -LiteralPath $image.FullName -ErrorAction Stop
                if ($gdiContent) {
                    $firstTrack = $gdiContent | Select-Object -Skip 1 | Select-Object -First 1
                    $sectorSize = if ($firstTrack -match '2352|2048') { $matches[0] } else { '2352' }
                    Write-Log "Detected sector size: $sectorSize" -Level DEBUG
                    $psi.Arguments = "createcd -i `"$($image.FullName)`" -o `"$chdFilePath`" --numprocessors $coresToUse"
                }
            } else {
                Write-Log "Detected CD image..." -Level DEBUG
                $psi.Arguments = "createcd -i `"$($image.FullName)`" -o `"$chdFilePath`" --numprocessors $coresToUse"
            }
            
            if ($Force) { 
                $psi.Arguments += " --force"
            }
            
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            
            Write-Log "Executing: $($psi.FileName) $($psi.Arguments)" -Level DEBUG
            
            $process = [System.Diagnostics.Process]::Start($psi)
            
            # Create variables to store output
            $stdout = New-Object System.Text.StringBuilder
            $stderr = New-Object System.Text.StringBuilder
            $progressLine = ""
            
            # Read output and error streams in a non-blocking way
            while (-not $process.HasExited) {
                if (-not $process.StandardOutput.EndOfStream) {
                    $line = $process.StandardOutput.ReadLine()
                    [void]$stdout.AppendLine($line)
                    
                    # If the line contains progress information, update the single-line display
                    if ($line -match '(compression ratio|input size|output size|compressing|processing)') {
                        # Clear the current line and display the new progress
                        Write-Host "`r$(' ' * $progressLine.Length)" -NoNewline
                        Write-Host "`r$line" -NoNewline
                        $progressLine = $line
                    }
                }
                
                if (-not $process.StandardError.EndOfStream) {
                    $line = $process.StandardError.ReadLine()
                    [void]$stderr.AppendLine($line)
                    # Don't display with WARNING level, just collect for error reporting
                }
                
                Start-Sleep -Milliseconds 100
            }
            
            # Clear the progress line when done
            if ($progressLine) {
                Write-Host "`r$(' ' * $progressLine.Length)" -NoNewline
                Write-Host "`r" -NoNewline
            }
            
            # Read any remaining output
            while (-not $process.StandardOutput.EndOfStream) {
                $line = $process.StandardOutput.ReadLine()
                [void]$stdout.AppendLine($line)
                
                if ($line -match '(compression ratio|input size|output size)') {
                    Write-Log $line -Level DEBUG
                }
            }
            
            # Collect any remaining error output
            $errorOutput = ""
            while (-not $process.StandardError.EndOfStream) {
                $line = $process.StandardError.ReadLine()
                [void]$stderr.AppendLine($line)
                $errorOutput += "$line`n"
            }
            
            if ($process.ExitCode -ne 0) {
                throw "chdman process exited with code $($process.ExitCode): $errorOutput"
            }
            
            $successfulConversions++
            Write-Log "Successfully created $([System.IO.Path]::GetRelativePath($PWD, $chdFilePath))" -Level SUCCESS
        }
        catch {
            Write-Log "Failed to convert $($image.FullName): $_" -Level ERROR
            $errorList += "File: $($image.FullName), Error: $_"
            $FailedConversions.Value++
        }
        finally {
            Write-Separator
        }
    }
    
    Write-Progress -Activity "Converting images to CHD" -Completed
    
    $TotalConversions.Value += $successfulConversions
    
    if ($errorList.Count -gt 0) {
        Write-Log "$($errorList.Count) conversion errors occurred:" -Level WARNING
        foreach ($error in $errorList) {
            Write-Log "  - $error" -Level DEBUG
        }
    }
}

function Expand-Archives {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$Path,
        [ref]$TotalExtractions,
        [ref]$FailedExtractions
    )

    Write-Log "Extracting Archives..." -Level INFO -ForegroundColor Cyan
    Write-Separator

    $archives = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.Extension -in $VALID_ARCHIVE_EXTENSIONS }

    if (-not $archives -or $archives.Count -eq 0) {
        Write-Log "No archive files found!" -Level INFO
        Write-Separator
        return
    }

    Write-Log "Found $($archives.Count) archives to extract" -Level INFO
    
    $totalArchives = $archives.Count
    $processedArchives = 0
    $successfulExtractions = 0
    $errorList = @()
    
    foreach ($archive in $archives) {
        $processedArchives++
        Write-Progress -Activity "Extracting archives" -Status "$processedArchives of $totalArchives" -PercentComplete ($processedArchives / $totalArchives * 100)
        
        $extractPath = Join-Path $archive.Directory.FullName $archive.BaseName
        
        if (-not $PSCmdlet.ShouldProcess($archive.FullName, "Extract archive")) {
            Write-Log "WhatIf: Would extract $($archive.Name) to $extractPath" -Level INFO
            continue
        }
        
        try {
            Write-Log "Extracting $($archive.Name)..." -Level INFO -ForegroundColor Cyan
            
            # Try to use 7Zip4Powershell if available
            if (Get-Module -Name 7Zip4Powershell -ListAvailable) {
                Import-Module 7Zip4Powershell -ErrorAction Stop
                Expand-7Zip -ArchiveFileName $archive.FullName -TargetPath $extractPath -ErrorAction Stop
            }
            # Fall back to built-in Expand-Archive for zip files
            elseif ($archive.Extension -eq '.zip') {
                Expand-Archive -LiteralPath $archive.FullName -DestinationPath $extractPath -Force -ErrorAction Stop
            }
            else {
                throw "Cannot extract $($archive.Extension) files. Install 7Zip4Powershell module with: Install-Module -Name 7Zip4Powershell"
            }
            
            $successfulExtractions++
            Write-Log "Extracted to $([System.IO.Path]::GetRelativePath($PWD, $extractPath))" -Level SUCCESS
            Write-Separator
        }
        catch {
            Write-Log "Failed to extract $($archive.FullName): $_" -Level ERROR
            $errorList += "File: $($archive.FullName), Error: $_"
            $FailedExtractions.Value++
        }
    }
    
    Write-Progress -Activity "Extracting archives" -Completed
    
    $TotalExtractions.Value += $successfulExtractions
    
    if ($errorList.Count -gt 0) {
        Write-Log "$($errorList.Count) extraction errors occurred:" -Level WARNING
        foreach ($error in $errorList) {
            Write-Log "  - $error" -Level DEBUG
        }
    }
}

function Remove-DeletionCandidates {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$Path,
        [ref]$FilesDeleted
    )

    $candidates = @()
    
    if ($DeleteArchive) {
        $archiveCandidates = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | 
            Where-Object { $_.Extension -in $VALID_ARCHIVE_EXTENSIONS }
        $candidates += $archiveCandidates
        
        if ($archiveCandidates.Count -gt 0) {
            Write-Log "Found $($archiveCandidates.Count) archive files for deletion" -Level INFO
        }
    }
    
    if ($DeleteImage) {
        $imageCandidates = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | 
            Where-Object { $_.Extension -in $VALID_IMAGE_EXTENSIONS }
        $candidates += $imageCandidates
        
        if ($imageCandidates.Count -gt 0) {
            Write-Log "Found $($imageCandidates.Count) image files for deletion" -Level INFO
        }
    }

    if (-not $candidates -or $candidates.Count -eq 0) {
        Write-Log "No files marked for deletion." -Level INFO
        return
    }

    Write-Log "File Deletion Candidates:" -Level INFO -ForegroundColor Cyan
    Write-Separator
    
    if ($Verbosity -ne "Minimal") {
        $candidates | ForEach-Object { Write-Host $_.FullName }
    }
    
    $totalFiles = $candidates.Count
    $processedFiles = 0
    $deletedFiles = 0
    
    foreach ($file in $candidates) {
        $processedFiles++
        Write-Progress -Activity "Deleting files" -Status "$processedFiles of $totalFiles" -PercentComplete ($processedFiles / $totalFiles * 100)
        
        if ($Force -or $PSCmdlet.ShouldProcess($file.FullName, "Delete file")) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $deletedFiles++
                Write-Log "Deleted $([System.IO.Path]::GetRelativePath($PWD, $file.FullName))" -Level SUCCESS
            }
            catch {
                Write-Log "Failed to delete $($file.FullName): $_" -Level ERROR
            }
        }
    }
    
    Write-Progress -Activity "Deleting files" -Completed
    $FilesDeleted.Value += $deletedFiles
}
#endregion

#region Main Function
function Optimize-PSX {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$Path = $PWD,
        [switch]$SkipArchive,
        [switch]$Force,
        [switch]$DeleteArchive,
        [switch]$DeleteImage,
        [string]$ChdmanPath = "chdman",
        [string]$LogFile,
        [ValidateSet("Minimal", "Normal", "Verbose")]
        [string]$Verbosity = "Normal"
    )

    begin {
        # Initialize log file if specified
        if ($LogFile) {
            try {
                $logFolder = Split-Path -Parent $LogFile
                if ($logFolder -and !(Test-Path -LiteralPath $logFolder)) {
                    New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
                }
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Set-Content -LiteralPath $LogFile -Value "[$timestamp] Optimize-PSX v$SCRIPT_VERSION log started" -Force
            }
            catch {
                Write-Host "Failed to initialize log file: $_" -ForegroundColor Red
                $LogFile = $null
            }
        }
        
        Write-Log "Starting Optimize-PSX v$SCRIPT_VERSION" -Level INFO -ForegroundColor Cyan
        
        # Verify external dependencies
        if (-not (Test-CommandExists $ChdmanPath)) {
            $errorMsg = "chdman not found. Install MAME tools and add to system PATH or specify the path with -ChdmanPath."
            Write-Log $errorMsg -Level ERROR
            throw $errorMsg
        }
        
        # Verify 7Zip module if needed
        if (-not $SkipArchive -and -not (Get-Module -Name 7Zip4Powershell -ListAvailable)) {
            Write-Log "7Zip4Powershell module not found. Basic ZIP extraction will be available, but other formats require this module." -Level WARNING
            Write-Log "Install with: Install-Module -Name 7Zip4Powershell" -Level INFO
        }
        
        try {
            $Path = Resolve-Path -LiteralPath $Path -ErrorAction Stop
            Write-Log "Processing path: $Path" -Level INFO
        }
        catch {
            Write-Log "Invalid path specified: $_" -Level ERROR
            throw "Invalid path specified: $_"
        }
        
        $startTime = Get-Date
        $initialSize = Get-FolderSize -Path $Path
        
        [int]$totalExtractions = 0
        [int]$failedExtractions = 0
        [int]$totalConversions = 0
        [int]$failedConversions = 0
        [int]$filesDeleted = 0
        
        # Track image and CHD sizes for ratio calculation
        [long]$totalImageSize = 0
        [long]$totalChdSize = 0
    }

    process {
        try {
            Write-Log "`nOptimize-PSX Processing: $Path`n" -Level INFO -ForegroundColor Cyan
            Write-Log "Components:" -Level INFO
            Write-Log "- 7-Zip: https://www.7-zip.org" -Level INFO
            Write-Log "- chdman: https://www.mamedev.org/" -Level INFO
            Write-Separator

            if (-not $SkipArchive) {
                Expand-Archives -Path $Path -TotalExtractions ([ref]$totalExtractions) -FailedExtractions ([ref]$failedExtractions)
            }

            # Capture image sizes before conversion
            $imageFiles = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | 
                Where-Object { $_.Extension -in $VALID_IMAGE_EXTENSIONS }
            
            foreach ($image in $imageFiles) {
                $totalImageSize += $image.Length
            }
            
            # Perform the conversions
            Compress-Images -Path $Path -TotalConversions ([ref]$totalConversions) -FailedConversions ([ref]$failedConversions) -Force:$Force
            
            # Capture CHD sizes after conversion
            $chdFiles = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | 
                Where-Object { $_.Extension -eq '.chd' }
            
            foreach ($chd in $chdFiles) {
                $totalChdSize += $chd.Length
            }

            if ($DeleteArchive -or $DeleteImage) {
                Remove-DeletionCandidates -Path $Path -FilesDeleted ([ref]$filesDeleted)
            }
            
            $finalSize = Get-FolderSize -Path $Path
            $savedSize = $initialSize - $finalSize
            $savedSizePercentage = if ($initialSize -gt 0) { ($savedSize / $initialSize) * 100 } else { 0 }
            $timeSpan = (Get-Date) - $startTime
            
            # Calculate compression ratio for converted files
            $compressionRatio = if ($totalImageSize -gt 0) { 
                [math]::Round(($totalChdSize / $totalImageSize) * 100, 2) 
            } else { 0 }
            
            $compressionSavings = if ($totalImageSize -gt 0) {
                [math]::Round(100 - $compressionRatio, 2)
            } else { 0 }
            
            Write-Log "`nOptimization Summary:" -Level INFO -ForegroundColor Cyan
            Write-Separator
            
            # Create a more readable summary display
            $sizeChangeText = if ($savedSize -ge 0) { "Reduced" } else { "Increased" }
            $absoluteSavedSize = [Math]::Abs($savedSize)
            $absolutePercentage = [Math]::Abs($savedSizePercentage)
            $changeDirection = if ($savedSize -ge 0) { "saved" } else { "added" }

            Write-Log "Storage Impact:" -Level INFO -ForegroundColor Yellow
            Write-Log "  Initial Size: $(Format-FileSize $initialSize)" -Level INFO
            Write-Log "  Final Size:   $(Format-FileSize $finalSize)" -Level INFO
            Write-Log "  $sizeChangeText by:  $(Format-FileSize $absoluteSavedSize) ($([Math]::Round($absolutePercentage, 2))% $changeDirection)" -Level INFO

            Write-Log "`nCompression Metrics:" -Level INFO -ForegroundColor Yellow
            if ($totalConversions -gt 0) {
                Write-Log "  Original Images Size: $(Format-FileSize $totalImageSize)" -Level INFO
                Write-Log "  Final CHD Size:      $(Format-FileSize $totalChdSize)" -Level INFO
                Write-Log "  Compression Ratio:   $compressionRatio% (smaller is better)" -Level INFO
                
                if ($compressionRatio -lt 100) {
                    Write-Log "  Space Savings:       $compressionSavings% saved from original images" -Level SUCCESS
                } else {
                    Write-Log "  Space Impact:        $(100 - $compressionSavings)% added to original images" -Level INFO
                }
            } else {
                Write-Log "  No images were converted to CHD" -Level INFO
            }

            Write-Log "`nOperation Results:" -Level INFO -ForegroundColor Yellow
            Write-Log "  Archives Extracted: $totalExtractions" -Level INFO
            if ($failedExtractions -gt 0) {
                Write-Log "  Failed Extractions: $failedExtractions" -Level WARNING
            }
            Write-Log "  Images Converted:   $totalConversions" -Level INFO
            if ($failedConversions -gt 0) {
                Write-Log "  Failed Conversions: $failedConversions" -Level WARNING
            }
            if ($filesDeleted -gt 0) {
                Write-Log "  Files Deleted:      $filesDeleted" -Level INFO
            }

            Write-Log "`nTotal Processing Time: $($timeSpan.ToString('hh\:mm\:ss'))" -Level INFO

            # Still keep the object for logging purposes
            $summary = [PSCustomObject]@{
                'Initial Size' = Format-FileSize $initialSize
                'Final Size' = Format-FileSize $finalSize
                'Space Change' = "$(Format-FileSize $absoluteSavedSize) $changeDirection"
                'Change %' = "$([Math]::Round($absolutePercentage, 2))%"
                'Original Images Size' = Format-FileSize $totalImageSize
                'Final CHD Size' = Format-FileSize $totalChdSize
                'Compression Ratio' = "$compressionRatio%"
                'Space Savings' = "$compressionSavings%"
                'Archives Extracted' = $totalExtractions
                'Failed Extractions' = $failedExtractions
                'Images Converted' = $totalConversions
                'Failed Conversions' = $failedConversions
                'Files Deleted' = $filesDeleted
                'Total Time' = "$($timeSpan.ToString('hh\:mm\:ss'))"
            }
            
            if ($LogFile) {
                $summary | Format-Table | Out-String | Add-Content -LiteralPath $LogFile
            }
            
            # Display errors summary if any
            if ($failedExtractions -gt 0 -or $failedConversions -gt 0) {
                Write-Log "Warning: Some operations failed. Check the log for details." -Level WARNING
            }
        }
        catch {
            Write-Log "Optimization failed: $_" -Level ERROR
            throw $_
        }
    }
    
    end {
        Write-Log "Optimize-PSX completed in $($timeSpan.ToString('hh\:mm\:ss'))" -Level INFO
    }
}
#endregion

# Execute the script with the provided parameters
Optimize-PSX @PSBoundParameters
