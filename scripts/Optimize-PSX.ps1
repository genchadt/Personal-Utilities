[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Position=0)]
    [string]$Path = $PWD,
    [switch]$Force,
    [switch]$SkipArchive,
    [switch]$DeleteArchive,
    [switch]$DeleteImage
)

#region Configuration
$VALID_ARCHIVE_EXTENSIONS = @('.7z', '.gz', '.rar', '.zip')
$VALID_IMAGE_EXTENSIONS = @('.cue', '.gdi', '.iso', '.bin', '.raw')
$CHDMAN_PATH = "chdman"
#endregion

#region Helpers
function Write-Separator {
    param (
        [string]$Char = "=",
        [int]$Length = 50,
        [ConsoleColor]$Color = "DarkGray"
    )
    $line = $Char * $Length
    Write-Host $line -ForegroundColor $Color
}

function Test-CommandExists {
    param([string]$Command)
    try { 
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch { return $false }
}
#endregion

#region File Operations
function Compress-Images {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$Path,
        [ref]$TotalConversions,
        [switch]$Force
    )
    
    Write-Host "`nConverting Images to CHDs..." -ForegroundColor Cyan
    Write-Separator

    # First look for .cue and .gdi files, using -LiteralPath to handle special characters
    $primaryFiles = Get-ChildItem -LiteralPath $Path -Recurse -File | 
        Where-Object { $_.Extension -in @('.cue', '.gdi') }

    # Then look for standalone .iso files (no .cue or .gdi should exist)
    $isoFiles = Get-ChildItem -LiteralPath $Path -Recurse -File | 
        Where-Object { 
            $_.Extension -eq '.iso' -and
            -not (Test-Path -LiteralPath (Join-Path $_.Directory "$($_.BaseName).cue")) -and
            -not (Test-Path -LiteralPath (Join-Path $_.Directory "$($_.BaseName).gdi"))
        }

    $images = @($primaryFiles) + @($isoFiles)

    if (-not $images) {
        Write-Host "No supported image files found!" -ForegroundColor Yellow
        Write-Separator
        return
    }

    foreach ($image in $images) {
        $chdFilePath = Join-Path $image.Directory.FullName "$($_.BaseName).chd"
        
        if ((-not $Force) -and (Test-Path -LiteralPath $chdFilePath)) {
            $message = "CHD file already exists: $([System.IO.Path]::GetRelativePath($PWD, $chdFilePath))"
            if (-not $PSCmdlet.ShouldContinue($message, "Overwrite existing CHD files?")) {
                Write-Host "Skipping conversion for $($image.Name)" -ForegroundColor Yellow
                continue
            }
        }

        try {
            Write-Host "Converting $($image.Name)..." -ForegroundColor Cyan
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $CHDMAN_PATH

            # Choose appropriate command based on file type
            if ($image.Extension -eq '.gdi') {
                Write-Host "Detected Dreamcast GDI image..." -ForegroundColor Cyan
                # Get the first track's sector size from the GDI file
                $gdiContent = Get-Content -LiteralPath $image.FullName
                if ($gdiContent) {
                    $firstTrack = $gdiContent | Select-Object -Skip 1 | Select-Object -First 1
                    $sectorSize = if ($firstTrack -match '2352|2048') { $matches[0] } else { '2352' }
                    Write-Host "Detected sector size: $sectorSize" -ForegroundColor DarkGray
                    $psi.Arguments = "createcd -i `"$($image.FullName)`" -o `"$chdFilePath`""
                }
            } else {
                Write-Host "Detected CD image..." -ForegroundColor Cyan
                $psi.Arguments = "createcd -i `"$($image.FullName)`" -o `"$chdFilePath`""
            }

            if ($Force) { 
                $psi.Arguments += " --force"
            }
            
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            
            Write-Host "Executing: $($psi.FileName) $($psi.Arguments)" -ForegroundColor DarkGray
            
            $process = [System.Diagnostics.Process]::Start($psi)
            
            # Create tasks to read output streams asynchronously
            $outputTask = $process.StandardOutput.ReadLineAsync()
            $errorTask = $process.StandardError.ReadLineAsync()
            
            # Continue reading output until process exits
            while (-not $process.HasExited) {
                if ($outputTask.IsCompleted) {
                    $line = $outputTask.Result
                    if ($line) { Write-Host $line }
                    $outputTask = $process.StandardOutput.ReadLineAsync()
                }
                if ($errorTask.IsCompleted) {
                    $line = $errorTask.Result
                    if ($line) { Write-Host $line -ForegroundColor Red }
                    $errorTask = $process.StandardError.ReadLineAsync()
                }
                Start-Sleep -Milliseconds 100
            }
            
            # Read any remaining output
            while (-not $process.StandardOutput.EndOfStream) {
                $line = $process.StandardOutput.ReadLine()
                if ($line) { Write-Host $line }
            }
            while (-not $process.StandardError.EndOfStream) {
                $line = $process.StandardError.ReadLine()
                if ($line) { Write-Host $line -ForegroundColor Red }
            }
            
            if ($process.ExitCode -ne 0) {
                throw "chdman process exited with code $($process.ExitCode)"
            }
            
            $TotalConversions.Value++
            Write-Host "Successfully created $([System.IO.Path]::GetRelativePath($PWD, $chdFilePath))" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to convert $($image.FullName): $_"
        }
        finally {
            Write-Separator
        }
    }
}

function Expand-Archives {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$Path,
        [ref]$TotalExtractions
    )

    Write-Host "`nExtracting Archives..." -ForegroundColor Cyan
    Write-Separator

    # Check for 7Zip module
    if (-not (Get-Module -Name 7Zip4Powershell -ListAvailable)) {
        Write-Error "7Zip4Powershell module is required for archive extraction. Install with: Install-Module -Name 7Zip4Powershell"
        return
    }
    Import-Module 7Zip4Powershell -ErrorAction Stop

    $archives = Get-ChildItem -Path $Path -Recurse -File | 
        Where-Object { $_.Extension -in $VALID_ARCHIVE_EXTENSIONS }

    if (-not $archives) {
        Write-Host "No archive files found!" -ForegroundColor Cyan
        Write-Separator
        return
    }

    foreach ($archive in $archives) {
        $extractPath = Join-Path $archive.Directory.FullName $archive.BaseName
        
        try {
            if ($PSCmdlet.ShouldProcess($archive.FullName, "Extract archive")) {
                Write-Host "Extracting $($archive.Name)..." -ForegroundColor Cyan
                Expand-7Zip -ArchiveFileName $archive.FullName -TargetPath $extractPath
                $TotalExtractions.Value++
                Write-Host "Extracted to $([System.IO.Path]::GetRelativePath($PWD, $extractPath))" -ForegroundColor Green
                Write-Separator
            }
        }
        catch {
            Write-Error "Failed to extract $($archive.FullName): $_"
            continue
        }
    }
}

function Remove-DeletionCandidates {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$Path
    )

    $candidates = @()
    if ($DeleteArchive) {
        $candidates += Get-ChildItem -Path $Path -Recurse -File | 
            Where-Object { $_.Extension -in $VALID_ARCHIVE_EXTENSIONS }
    }
    if ($DeleteImage) {
        $candidates += Get-ChildItem -Path $Path -Recurse -File | 
            Where-Object { $_.Extension -in $VALID_IMAGE_EXTENSIONS }
    }

    if (-not $candidates) {
        Write-Host "No files marked for deletion." -ForegroundColor Cyan
        return
    }

    Write-Host "`nFile Deletion Candidates:" -ForegroundColor Cyan
    Write-Separator
    $candidates | ForEach-Object { Write-Host $_.FullName }

    foreach ($file in $candidates) {
        if ($Force -or $PSCmdlet.ShouldProcess($file.FullName, "Delete file")) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force
                Write-Host "Deleted $([System.IO.Path]::GetRelativePath($PWD, $file.FullName))" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to delete $($file.FullName): $_"
            }
        }
    }
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
        [switch]$DeleteImage
    )

    begin {
        if (-not (Test-CommandExists $CHDMAN_PATH)) {
            throw "chdman not found in PATH. Install from MAME tools and add to system PATH."
        }

        $Path = Resolve-Path $Path
        $startTime = Get-Date
        $initialSize = (Get-ChildItem -Path $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
        [int]$totalExtractions = 0
        [int]$totalConversions = 0
    }

    process {
        try {
            Write-Host "`nOptimize-PSX Processing: $Path`n" -ForegroundColor Cyan
            Write-Host "Components:"
            Write-Host "- 7-Zip: https://www.7-zip.org"
            Write-Host "- chdman: https://www.mamedev.org/" 
            Write-Separator

            if (-not $SkipArchive) {
                Expand-Archives -Path $Path -TotalExtractions ([ref]$totalExtractions)
            }

            Compress-Images -Path $Path -TotalConversions ([ref]$totalConversions)

            if ($DeleteArchive -or $DeleteImage) {
                Remove-DeletionCandidates -Path $Path
            }

            $finalSize = (Get-ChildItem -Path $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $totalOperations = $totalExtractions + $totalConversions
            $timeSpan = (Get-Date) - $startTime

            Write-Host "`nOptimization Summary:" -ForegroundColor Cyan
            Write-Separator
            [PSCustomObject]@{
                'Initial Size (MB)' = [math]::Round($initialSize / 1MB, 2)
                'Final Size (MB)' = [math]::Round($finalSize / 1MB, 2)
                'Space Saved (MB)' = [math]::Round(($initialSize - $finalSize) / 1MB, 2)
                'Archives Extracted' = $totalExtractions
                'Images Converted' = $totalConversions
                'Total Time' = "$($timeSpan.ToString('mm\:ss\.fff'))"
            } | Format-Table -AutoSize
        }
        catch {
            Write-Error "Optimization failed: $_"
            exit 1
        }
    }
}
#endregion

Optimize-PSX @PSBoundParameters
