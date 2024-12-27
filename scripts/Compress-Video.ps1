using namespace System.IO

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
}

function Test-AlreadyCompressed {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileInfo]$File
    )
    
    process {
        return $File.BaseName -like '*_compressed'
    }
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
        [string[]]$Extensions = $script:Config.DefaultExtensions
    )
    
    begin {
        Write-Debug "Getting video files from: $Path"
        $files = @()
    }
    
    process {
        if (Test-Path $Path -PathType Container) {
            $files += Get-ChildItem -Force -Path $Path -File |
                Where-Object { $Extensions -contains $_.Extension.ToLower() }
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
    supports multiple file extensions and allows for custom FFmpeg arguments. It
    also provides an option to delete the original files after compression.

.PARAMETER InputFilePath
    The path to the directory containing video files to compress. If not provided,
    the current directory is used.

.PARAMETER OutputFilePath
    The path to save the compressed video files. If not provided, the compressed
    files will be saved in the same directory as the original files.

.PARAMETER DeleteSource
    Deletes the original video files after compression.

.PARAMETER Force
    Forces compression of already compressed files.

.PARAMETER Extensions
    An array of file extensions to compress. Default is $script:DefaultExtensions.

.PARAMETER FFmpegArgs
    An array of FFmpeg arguments to use. Default is $script:DefaultFFmpegArgs.

.EXAMPLE
    Compress-Video -InputFilePath "C:\Videos" -OutputFilePath "C:\Compressed"

    Compresses all video files in "C:\Videos" and saves them in "C:\Compressed".

.EXAMPLE
    Compress-Video -InputFilePath "C:\Videos" -DeleteSource -Force

    Compresses all video files in "C:\Videos" and deletes the original files.

.EXAMPLE
    Compress-Video -InputFilePath "C:\Videos" -Extensions @("mp4", "mkv") -FFmpegArgs @("-c:v", "libx265", "-crf", "23")

    Compresses only MP4 and MKV files in "C:\Videos" using libx265 codec with a quality level of 23.
#>
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
        [Alias("Force", "f")]
        [switch]$Force,

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

        $LogFilePath = Join-Path $script:Config.LogDirectory "$($MyInvocation.MyCommand.Name)_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ss').log"
        if (-not (Test-Path $LogFilePath)) {
            New-Item -ItemType File -Path $LogFilePath | Out-Null
        }
        Start-Transcript -Path $LogFilePath
    }
    
    process {
        try {
            # Get video files
            $videoFiles = Get-VideoFiles -Path $InputFilePath -Extensions $Extensions

            foreach ($file in $videoFiles) {
                Write-Debug "Processing file: $($file.Name)"

                # Skip already compressed files unless forced
                if ((Test-AlreadyCompressed -File $file) -and -not $Force) {
                    Write-Warning "Skipping already compressed file: $($file.Name)"
                    continue
                }

                # Generate and validate output path
                $outputPath = New-CompressedPath -File $file -CustomPath $OutputFilePath
                if (-not (Test-OutputPath -Path $outputPath)) {
                    Write-Error "Invalid output path: $outputPath"
                    continue
                }

                # Perform compression
                $compressionResult = Invoke-FFmpeg -InputFile $file -OutputPath $outputPath -FFmpegArgs $FFmpegArgs -DeleteSource:$DeleteSource
                
                if ($compressionResult.Success) {
                    $metrics = Get-CompressionMetrics -CompressionResult $compressionResult
                    Write-Host "Compression complete: $($metrics.SavingsPercent)% reduction" -ForegroundColor Green
                    $results += $metrics
                }
            }
        }
        catch {
            Write-Error "Compression process failed: $_"
        }
    }
    
    end {
        if ($results.Count -gt 0) {
            $totalOriginalSize = ($results | Measure-Object -Property OriginalSize -Sum).Sum
            $totalCompressedSize = ($results | Measure-Object -Property CompressedSize -Sum).Sum
            Write-Host "Average savings: $([math]::Round($averageSavings, 2))%" -ForegroundColor Cyan
            Write-Host "Total space saved: ${totalSavedMB}MB" -ForegroundColor Cyan
    
            Write-Host "`nCompression Summary:" -ForegroundColor Cyan
            Write-Host "Files processed: $($results.Count)" -ForegroundColor Cyan
            Write-Host "Average savings: $($results | Measure-Object -Property SavingsPercent -Average | Select-Object -ExpandProperty Average)%" -ForegroundColor Cyan
            Write-Host "Total space saved: $([math]::Round(($results.OriginalSize.Sum() - $results.CompressedSize.Sum()) / 1MB, 2))MB" -ForegroundColor Cyan
        }

        Stop-Transcript

        [System.GC]::Collect()
    }
}
#endregion

Compress-Video @PSBoundParameters
