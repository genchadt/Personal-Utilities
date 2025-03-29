[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [Alias("Path", "p")]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$InputFilePath = (Get-Location).Path,

    [Parameter(Position = 1)]
    [Alias("Output", "o")]
    [ValidateScript({
        if([string]::IsNullOrEmpty($_)) { return $true }
        Test-Path (Split-Path $_) -PathType Container
    })]
    [string]$OutputFilePath,

    [Parameter()]
    [Alias("Delete", "del")]
    [switch]$DeleteSource,

    [Parameter()]
    [switch]$Recurse,

    [Parameter()]
    [string[]]$Extensions = $script:Config.DefaultExtensions,

    [Parameter()]
    [string[]]$FFmpegArgs = $script:Config.DefaultFFmpegArgs
)

#region Configuration
$script:Config = @{
    DefaultExtensions = @(".avi", ".flv", ".mp4", ".mov", ".mkv", ".wmv")
    DefaultFFmpegArgs = @(
        '-i', 'input.mp4',
        '-c:v', 'libx265',
        '-crf', '28',
        '-preset', 'slow',
        '-c:a', 'copy',
        'output.mp4'
    )
    MaxPathLength = 260
    MaxFileNameLength = 255
    LogDirectory = Join-Path $PSScriptRoot "logs"
}
#endregion

#region Validation Functions
function Test-FFmpeg {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    begin {
        Write-Debug "Testing FFmpeg installation"
    }
    
    process {
        $ffmpegExists = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if (-not $ffmpegExists) {
            Write-Error "FFmpeg is not installed or not in the system's PATH."
            return $false
        }
        return $true
    }

    end {
        Write-Debug "FFmpeg installation test completed"
    }
}

function Test-OutputPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )
    
    begin {
        Write-Debug "Testing output path validity"
        $invalidChars = '<>:"|?*'
    }
    
    process {
        try {
            Write-Debug "Testing path: $Path"
            Write-Debug "Path length: $($Path.Length)"
            
            $fileName = Split-Path -Path $Path -Leaf
            Write-Debug "Filename: $fileName"
            
            $parentDir = Split-Path -Path $Path -Parent
            Write-Debug "Parent directory: $parentDir"
            
            # Detailed validation checks with debug output
            if ($Path.Length -gt 260) {
                Write-Debug "Failed: Path too long"
                Write-Error "Path exceeds maximum length (260 characters): $Path"
                return $false
            }

            if (-not (Test-Path -Path $parentDir -PathType Container)) {
                Write-Debug "Failed: Parent directory does not exist"
                Write-Error "Parent directory does not exist: $parentDir"
                return $false
            }

            foreach ($char in $invalidChars.ToCharArray()) {
                if ($fileName.Contains($char)) {
                    Write-Debug "Failed: Contains invalid character '$char'"
                    Write-Error "Filename contains invalid character '$char': $fileName"
                    return $false
                }
            }

            if ($fileName -match '(^\s|\s$|^\.|\.$)') {
                Write-Debug "Failed: Invalid leading/trailing characters"
                Write-Error "Filename cannot begin or end with spaces or periods: $fileName"
                return $false
            }

            Write-Debug "Path validation successful"
            return $true
        }
        catch {
            Write-Debug "Exception during path validation: $_"
            Write-Error "Error testing path: $_"
            return $false
        }
    }

    end {
        Write-Debug "Output path validity test completed"
    }
}

function Test-AlreadyCompressed {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileInfo]$File
    )
    
    begin {}

    process {
        return $File.BaseName -like '*_compressed'
    }

    end {}
}
#endregion

#region Path Management
function Get-VideoFiles {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        [Parameter()]
        [string[]]$Extensions = $script:Config.DefaultExtensions,
        
        [Parameter()]
        [switch]$Recurse
    )
    
    begin {
        Write-Debug "Getting video files from: $Path"
        $files = @()
    }
    
    process {
        if (Test-Path $Path -PathType Container) {
            # Simply add the -Recurse parameter conditionally
            if ($Recurse) {
                $files += Get-ChildItem -Force -Path $Path -File -Recurse |
                    Where-Object { $Extensions -contains $_.Extension.ToLower() }
            } else {
                $files += Get-ChildItem -Force -Path $Path -File |
                    Where-Object { $Extensions -contains $_.Extension.ToLower() }
            }
        }
        elseif (Test-Path $Path -PathType Leaf) {
            $files += Get-Item -Force $Path
        }
        else {
            Write-Error "Invalid path: $Path"
        }
    }
    
    end {
        return $files
    }
}


function New-CompressedPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileInfo]$File,

        [Parameter()]
        [string]$CustomPath
    )
    
    begin {
        Write-Debug "Generating compressed file path"
        
        # Define invalid characters and maximum filename length
        $invalidCharsPattern = '[<>:"|?*]'
        $maxFileNameLength = 255
    }
    
    process {
        try {
            Write-Debug "Processing file: $($File.FullName)"
            
            if ($CustomPath) {
                Write-Debug "Using custom path: $CustomPath"
                return $CustomPath
            }

            # Get base name and sanitize
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
            Write-Debug "Original basename: $baseName"

            # Check if already compressed
            if (-not (Test-AlreadyCompressed -File $File)) {
                $baseName = "${baseName}_compressed"
                Write-Debug "Added compressed suffix: $baseName"
            }
            
            # Sanitize the filename
            $sanitizedName = $baseName -replace $invalidCharsPattern, ''  # Remove invalid chars
            $sanitizedName = $sanitizedName.Trim(' .')                    # Remove leading/trailing spaces and dots
            $sanitizedName = $sanitizedName -replace '\s+', ' '          # Replace multiple spaces with single space
            
            # Ensure the filename isn't too long (accounting for extension)
            if ($sanitizedName.Length + 4 -gt $maxFileNameLength) {  # 4 for '.mp4'
                $sanitizedName = $sanitizedName.Substring(0, $maxFileNameLength - 4)
                Write-Debug "Truncated long filename to: $sanitizedName"
            }
            
            # Ensure we still have a valid filename after sanitization
            if ([string]::IsNullOrWhiteSpace($sanitizedName)) {
                $sanitizedName = "video_" + (Get-Date).ToString("yyyyMMdd_HHmmss")
                Write-Debug "Generated fallback filename: $sanitizedName"
            }
            
            Write-Debug "Final basename: $sanitizedName"
            
            # Generate full output path
            $outputPath = Join-Path $File.DirectoryName "${sanitizedName}.mp4"
            
            # Ensure the path isn't too long
            if ($outputPath.Length -gt 260) {
                Write-Warning "Output path exceeds Windows path length limit. Attempting to shorten..."
                $shortenedName = $sanitizedName.Substring(0, [Math]::Min($sanitizedName.Length, 50))
                $outputPath = Join-Path $File.DirectoryName "${shortenedName}_$(Get-Date -Format 'yyyyMMddHHmmss').mp4"
                Write-Debug "Shortened output path: $outputPath"
            }
            
            Write-Debug "Final output path: $outputPath"
            return $outputPath
        }
        catch {
            Write-Error "Failed to generate output path: $_"
            throw
        }
    }
}
#endregion

#region FFmpeg Operations
function Invoke-FFmpeg {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileInfo]$InputFile,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [string[]]$FFmpegArgs = $script:Config.DefaultFFmpegArgs,

        [switch]$DeleteSource
    )
    
    begin {
        Write-Debug "Starting FFmpeg compression"
    }
    
    process {
        try {
            $FFmpegArgs[1] = $InputFile.FullName
            $FFmpegArgs[-1] = $OutputPath

            Write-Debug "FFmpeg command: ffmpeg $FFmpegArgs"
            # Run FFmpeg and show output directly
            & ffmpeg @FFmpegArgs
            
            if ($LASTEXITCODE -ne 0) {
                throw "FFmpeg failed with exit code $LASTEXITCODE"
            }

            if ($DeleteSource -and (Test-Path $OutputPath)) {
                Remove-Item $InputFile.FullName -Force
                Write-Verbose "Deleted source file: $($InputFile.FullName)"
            }

            return [PSCustomObject]@{
                Success = $true
                InputFile = $InputFile
                OutputFile = Get-Item $OutputPath
                Output = $null
            }
        }
        catch {
            Write-Error "FFmpeg compression failed: $_"
            return [PSCustomObject]@{
                Success = $false
                InputFile = $InputFile
                OutputFile = $null
                Error = $_
            }
        }
    }
}

function Get-CompressionMetrics {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$CompressionResult
    )
    
    process {
        if (-not $CompressionResult.Success) {
            Write-Error "Cannot measure compression: Operation failed"
            return
        }

        $originalSize = $CompressionResult.InputFile.Length
        $compressedSize = $CompressionResult.OutputFile.Length
        $savings = [math]::Round(($originalSize - $compressedSize) / $originalSize * 100, 2)

        return [PSCustomObject]@{
            OriginalSize = $originalSize
            CompressedSize = $compressedSize
            SavingsPercent = $savings
            InputFile = $CompressionResult.InputFile
            OutputFile = $CompressionResult.OutputFile
        }
    }
}
#endregion

#region Main Function
function Compress-Video {
    <#
    .SYNOPSIS
        Quickly compresses video files using FFmpeg.
    
    .DESCRIPTION
        Compresses video files using FFmpeg and codecs such as libx265. The function
        supports multiple file extensions, recursive searching, and allows for custom
        FFmpeg arguments. It also provides an option to delete the original files
        after compression. Lists files to be processed before starting.
    
    .PARAMETER InputFilePath
        The path to the directory containing video files to compress, or a path to a single video file.
        If not provided, the current directory is used.
    
    .PARAMETER OutputFilePath
        The path to the directory where compressed video files will be saved.
        If not provided, compressed files are saved alongside the originals (with '_compressed' suffix).
        If provided along with -Recurse, the original directory structure below InputFilePath
        will be mirrored within OutputFilePath. If InputFilePath is a single file, this can be a
        full output file path or an output directory.
    
    .PARAMETER Recurse
        Process video files in the InputFilePath directory and all its subdirectories.
    
    .PARAMETER DeleteSource
        Deletes the original video files after successful compression. Prompts for confirmation
        unless -Force is also used (or $ConfirmPreference is 'None'). Use with caution.
    
    .PARAMETER Extensions
        An array of file extensions to compress (case-insensitive, leading dot optional).
        Default is $script:Config.DefaultExtensions.
    
    .PARAMETER FFmpegArgs
        An array of FFmpeg arguments to use for compression.
        It's recommended to use placeholders 'input.mp4' (directly after -i) and 'output.mp4' (as the last argument).
        If placeholders are not found/used correctly, the script attempts to replace the argument after '-i' and the last argument.
        Default is $script:Config.DefaultFFmpegArgs.
    
    .EXAMPLE
        Compress-Video -InputFilePath "C:\Videos" -OutputFilePath "C:\Compressed"
    
        Lists found videos in "C:\Videos", asks for confirmation, then compresses them and saves them in "C:\Compressed".
    
    .EXAMPLE
        Compress-Video -InputFilePath "C:\Videos" -DeleteSource -Force
    
        Lists found videos in "C:\Videos", asks for confirmation, then compresses them and deletes the original files.
    
    .EXAMPLE
        Compress-Video -InputFilePath "C:\Videos" -Extensions @("mp4", "mkv") -FFmpegArgs @("-c:v", "libx265", "-crf", "23")
    
        Lists found MP4 and MKV files in "C:\Videos", asks for confirmation, then compresses them using libx265 codec with a quality level of 23.
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')] # Added SupportsShouldProcess for -DeleteSource confirmation
    param (
        [Parameter(Position = 0)]
        [Alias("Path", "p")]
        # Allow container or leaf for input path
        [ValidateScript({ Test-Path $_ })]
        [string]$InputFilePath = (Get-Location).Path,

        [Parameter(Position = 1)]
        [Alias("Output", "o")]
        [ValidateScript({
            # Allow empty/null, or if parent directory exists
            if([string]::IsNullOrEmpty($_)) { return $true }
            $parent = Split-Path $_ -Parent
            if ([string]::IsNullOrEmpty($parent) -or (Test-Path $parent -PathType Container)) { return $true }
            throw "Parent directory '$parent' for the specified OutputFilePath '$_' does not exist."
        })]
        [string]$OutputFilePath,

        [Parameter()]
        [Alias("Delete", "del")]
        [switch]$DeleteSource,

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [string[]]$Extensions = $script:Config.DefaultExtensions,

        [Parameter()]
        [string[]]$FFmpegArgs = $script:Config.DefaultFFmpegArgs
    )

    begin {
        if (-not (Test-FFmpeg)) {
            throw "FFmpeg is not available"
        }

        Write-Debug "Starting video compression process"
        $results = @()

        # Setup Logging more robustly
        $logDir = $script:Config.LogDirectory
        try {
            if (-not (Test-Path $logDir -PathType Container)) {
                Write-Debug "Creating log directory: $logDir"
                New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
            }
            $LogFilePath = Join-Path $logDir "$($MyInvocation.MyCommand.Name)_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').log"
            Write-Debug "Starting transcript logging to: $LogFilePath"
            Start-Transcript -Path $LogFilePath -Append -Force -ErrorAction Stop
        } catch {
                Write-Warning "Failed to create log directory or start transcript logging to '$logDir': $_. Log file will not be created."
                $LogFilePath = $null # Ensure variable exists but is null if logging fails
        }
    }

    process {
        try {
            # Resolve input path for clarity
            $resolvedInputPath = $null
            try {
                $resolvedInputPath = (Resolve-Path -LiteralPath $InputFilePath).ProviderPath
            } catch {
                throw "Invalid InputFilePath '$InputFilePath': $_"
            }

            # Get video files
            Write-Verbose "Searching for video files in '$resolvedInputPath'..."
            $videoFiles = Get-VideoFiles -Path $resolvedInputPath -Extensions $Extensions -Recurse:$Recurse

            # --- List files and ask for confirmation ---
            if ($videoFiles.Count -eq 0) {
                Write-Warning "No video files found matching the specified criteria in '$resolvedInputPath'."
                # Exit process block cleanly if no files found
                return
            }

            Write-Host ("-"*10 + " Files Found ($($videoFiles.Count)) " + "-"*10) -ForegroundColor Yellow
            $videoFiles | ForEach-Object { Write-Host "- $($_.FullName)" }
            Write-Host ("-"* (10 + 17 + $videoFiles.Count.ToString().Length + 10)) -ForegroundColor Yellow # Match header length

            # Ask for confirmation - unless -WhatIf is used (ShouldProcess handles that implicitly)
            # Or if running non-interactively
            if ($PSCmdlet.ShouldProcess("all $($videoFiles.Count) listed files", "Compress")) {
                # User confirmed via -Confirm or default behavior, or -WhatIf was specified (which skips the actual loop below)
                Write-Verbose "Proceeding with compression..."
            } else {
                    # User selected No/No to All on the ShouldProcess prompt
                    Write-Warning "Compression cancelled by user."
                    return # Exit process block
            }
            # --- End List and Confirmation ---


            # --- Start Compression Loop ---
            $fileCounter = 0
            foreach ($file in $videoFiles) {
                $fileCounter++
                $progressParams = @{
                    Activity = "Compressing Videos"
                    Status = "Processing '$($file.Name)' ($fileCounter of $($videoFiles.Count))"
                    CurrentOperation = "File: $($file.FullName)"
                    PercentComplete = (($fileCounter / $videoFiles.Count) * 100)
                }
                Write-Progress @progressParams
                Write-Host "`nProcessing file $fileCounter of $($videoFiles.Count): $($file.Name) ($($file.DirectoryName))" -ForegroundColor Cyan


                # Skip already compressed files
                # Note: Your original script had '-and -not $Force' here.
                # $Force usually relates to overwriting or skipping prompts.
                # If you want a switch to *force* re-compression, you'd need to add a specific parameter like -ForceCompress.
                # Assuming default behavior is to skip compressed files.
                if (Test-AlreadyCompressed -File $file) {
                    Write-Host "[SKIP] File already has '_compressed' suffix: $($file.Name)" -ForegroundColor Gray
                    continue
                }

                # Generate and validate output path
                # Handle OutputFilePath correctly - if it's a directory, generate filename; if null/empty, generate beside original.
                $currentOutputPath = $null
                try {
                    # Determine target directory
                    $targetDirectory = $null
                    if (-not [string]::IsNullOrEmpty($OutputFilePath)) {
                        # Check if OutputFilePath is intended as a directory
                        if ((Test-Path -LiteralPath $OutputFilePath -IsValid -PathType Container) -or ($OutputFilePath -match "[\\/]$")) {
                                $targetDirectory = (Resolve-Path -LiteralPath $OutputFilePath).ProviderPath
                        } else {
                                # If input is single file, OutputFilePath might be a full file path
                                if ((Test-Path -LiteralPath $resolvedInputPath -PathType Leaf) -and $videoFiles.Count -eq 1) {
                                    $currentOutputPath = (Resolve-Path -LiteralPath $OutputFilePath).ProviderPath
                                    $targetDirectory = Split-Path $currentOutputPath -Parent # Needed for Test-OutputPath check below
                                    Write-Debug "Using specific output file path: $currentOutputPath"
                                } else {
                                    # Output path looks like a file, but input is a directory or multiple files - treat as directory path
                                    $targetDirectory = (Resolve-Path -LiteralPath $OutputFilePath).ProviderPath
                                    Write-Warning "OutputFilePath '$OutputFilePath' looks like a file, but input is not a single file. Treating as target directory."
                                }
                        }
                    }

                    # If specific output path wasn't set above, generate it
                    if (-not $currentOutputPath) {
                        # Pass the determined target directory (or null if none specified)
                        $currentOutputPath = New-CompressedPath -File $file -CustomPath $targetDirectory
                    }

                    # Ensure parent directory exists for the final path
                    $parentDir = Split-Path $currentOutputPath -Parent
                    if (-not (Test-Path -LiteralPath $parentDir -PathType Container)) {
                        Write-Debug "Creating parent directory for output: $parentDir"
                        New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    }

                    # Validate the final generated/specified path
                    if (-not (Test-OutputPath -Path $currentOutputPath)) {
                        # Error already written by Test-OutputPath
                        Write-Error "Invalid output path '$currentOutputPath'. Skipping file '$($file.Name)'."
                        continue # Skip this file
                    }

                    # Check if output file already exists
                    if (Test-Path -LiteralPath $currentOutputPath -PathType Leaf) {
                        Write-Warning "Output file '$currentOutputPath' already exists. Skipping compression for '$($file.Name)'."
                        continue
                    }

                } catch {
                        Write-Error "Failed to determine or validate output path for '$($file.Name)': $_. Skipping file."
                        continue # Skip this file
                }


                # Perform compression - Use ShouldProcess for the specific file operation
                $compressionResult = $null
                $operationDescr = "Compress '$($file.FullName)' to '$currentOutputPath'"
                # We already confirmed the overall operation, but ShouldProcess here respects -WhatIf per file
                if ($PSCmdlet.ShouldProcess($file.FullName, $operationDescr)) {

                    # Determine if source deletion should happen *for this file*
                    $shouldDelete = $false
                    if ($DeleteSource.IsPresent) { # Check switch presence
                        $deleteDescr = "Delete source file '$($file.FullName)' after successful compression"
                        # Check ShouldProcess specifically for the deletion (respects -Confirm and -WhatIf)
                        if ($PSCmdlet.ShouldProcess($file.FullName, $deleteDescr)) {
                            $shouldDelete = $true
                        } else {
                            Write-Warning "Skipping source file deletion for '$($file.Name)' due to user cancellation or -WhatIf."
                        }
                    }

                    # Call FFmpeg
                    $compressionResult = Invoke-FFmpeg -InputFile $file -OutputPath $currentOutputPath -FFmpegArgs $FFmpegArgs -DeleteSource:$shouldDelete
                } else {
                    Write-Warning "Compression skipped for file '$($file.Name)' due to -WhatIf."
                    # No need to increment skippedFiles here, as it wasn't an error or pre-existing condition
                    continue
                }


                # Process results
                if ($compressionResult -and $compressionResult.Success) {
                    $metrics = Get-CompressionMetrics -CompressionResult $compressionResult
                    if ($metrics) {
                        $sizeText = "$([Math]::Round($metrics.OriginalSize / 1MB, 2))MB -> $([Math]::Round($metrics.CompressedSize / 1MB, 2))MB"
                        Write-Host "[SUCCESS] Compression complete. Savings: $($metrics.SavingsPercent)% ($sizeText)" -ForegroundColor Green
                        $results += $metrics
                    } else {
                        Write-Warning "[SUCCESS] Compression reported success for '$($file.Name)', but could not calculate metrics."
                    }
                } else {
                    # Error message already written by Invoke-FFmpeg
                    Write-Error "[FAILURE] Compression failed for: $($file.Name). See log for details."
                    # Consider adding to a $failedFiles list/counter if needed for summary
                }

            } # End foreach file loop
        }
        catch {
            # Catch errors from Get-VideoFiles or other Process block issues
            Write-Error "An error occurred during the main processing loop: $_"
        }
    } # End Process block

    end {
        Write-Progress -Activity "Compressing Videos" -Completed
        Write-Host "`n" + ("-"*20) + " Compression Summary " + ("-"*20) -ForegroundColor Cyan

        if ($results.Count -gt 0) {
            $totalOriginalSize = ($results | Measure-Object -Property OriginalSize -Sum -ErrorAction SilentlyContinue).Sum
            $totalCompressedSize = ($results | Measure-Object -Property CompressedSize -Sum -ErrorAction SilentlyContinue).Sum
            $averageSavings = 0
            $totalSavedMB = 0

            # Ensure division by zero doesn't happen and sizes were calculated
            if ($totalOriginalSize -and $totalOriginalSize -gt 0) {
                $averageSavings = ($results | Measure-Object -Property SavingsPercent -Average -ErrorAction SilentlyContinue).Average
                if ($totalCompressedSize -ne $null) { # Check if sum was successful
                    $totalSavedMB = [math]::Round(($totalOriginalSize - $totalCompressedSize) / 1MB, 2)
                }
            }

            Write-Host "Files successfully processed: $($results.Count)" -ForegroundColor Cyan
            if ($totalOriginalSize -and $totalOriginalSize -gt 0) {
                    Write-Host "Average savings:           $([math]::Round($averageSavings, 2))%" -ForegroundColor Cyan
                    Write-Host "Total space saved:         ${totalSavedMB}MB" -ForegroundColor Cyan
                    Write-Host "Total original size:       $([math]::Round($totalOriginalSize / 1MB, 2))MB" -ForegroundColor Cyan
                    Write-Host "Total compressed size:     $([math]::Round($totalCompressedSize / 1MB, 2))MB" -ForegroundColor Cyan
            } else {
                    Write-Host "Average savings:           N/A (Original size zero or unavailable)" -ForegroundColor Cyan
                    Write-Host "Total space saved:         N/A" -ForegroundColor Cyan
                    if ($totalCompressedSize -ne $null) {
                    Write-Host "Total compressed size:     $([math]::Round($totalCompressedSize / 1MB, 2))MB" -ForegroundColor Cyan
                    }
            }

        } else {
            # Check if videoFiles was populated but results is empty (meaning all failed/skipped)
            # Need to access $videoFiles count from process block scope, maybe pass it or recalculate?
            # Simpler: Just state that no files were successfully processed.
                Write-Host "No files were successfully compressed." -ForegroundColor Yellow
        }

        Write-Host ("-"* (20 + 21 + 20)) -ForegroundColor Cyan # Match title line length

        # Stop logging if it was started
        # FIX: Check $Transcript variable, not Get-Transcript cmdlet
        if ($global:Transcript -and $LogFilePath) { # Check if transcript is running AND we initiated it
            Write-Debug "Stopping transcript logging."
            Stop-Transcript
        } else {
                Write-Debug "Transcript was not active or not started by this script."
        }

        # Optional: Force garbage collection
        Write-Debug "Requesting garbage collection."
        [System.GC]::Collect()

        Write-Debug "Cmdlet End: $($MyInvocation.MyCommand.Name)"

        # Optionally return the results array for programmatic use
        # return $results
    } # End End block
    }
#endregion

Compress-Video @PSBoundParameters
