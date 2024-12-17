[CmdletBinding()]
param(
    [string]$InputFilePath,
    [string]$OutputFilePath,
    [switch]$DeleteSource,
    [switch]$Force,
    [array]$Extensions,
    [array]$FFmpegArgs
)

#region Helpers
function Assert-FFmpeg {
    [CmdletBinding()]
    param()

    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
        throw "Assert-FFmpeg: FFmpeg is not installed or not in the system's PATH."
    }
}

function Get-VideoFiles {
    <#
    .SYNOPSIS
        Get-VideoFiles - Returns an array of video files based on input path and extensions.

    .DESCRIPTION
        Returns an array of video files based on input path and extensions.
        If input path is a directory, returns all supported video files within.
        If input path is a file, returns a single video file.

    .PARAMETER InputPath
        Path to video file or directory to process.
        If directory, processes all supported video files within.
        If not specified, processes current directory.

    .PARAMETER Extensions
        Array of video file extensions to process.

    .OUTPUTS
        System.IO.FileInfo[] - Array of matching video files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [array]$Extensions
    )

    if (Test-Path $InputPath -PathType Container) {       # If input path is a directory: return all supported video files
        return Get-ChildItem -Force -Path $InputPath -File |
            Where-Object { $Extensions -contains $_.Extension.ToLower() }
    } elseif (Test-Path $InputPath -PathType Leaf) {      # Else, if input path is a file: return a single video file
        return @(Get-Item -Force $InputPath)
    } else {                                              # Else, input path is invalid. Throw error
        throw "The provided input path is not valid: $InputPath"
    }
}

function New-OutputPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,

        [string]$OutputFilePath
    )

    # Add "_compressed" to file name so we can recognize files previously compressed
    if (-not $OutputFilePath) {
        return Join-Path (Split-Path $File.FullName) "$([System.IO.Path]::GetFileNameWithoutExtension($File.FullName))_compressed.mp4"
    } else {
        return $OutputFilePath
    }
}
#endregion

#region File Operations
function Invoke-FFmpeg {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [array]$FFmpegArgs,

        [switch]$DeleteSource
    )

    $FFmpegArgs[1] = $File.FullName
    $FFmpegArgs[-1] = $OutputPath

    Write-Debug "Invoking FFmpeg: $($File.FullName)"
    Write-Debug "FFmpeg command: ffmpeg $FFmpegArgs"

    $ffmpegOutput = & ffmpeg @FFmpegArgs 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Debug "Invoke-FFmpeg: Operation completed successfully."
        if ($DeleteSource) {
            Remove-Item $File.FullName -Force
            Write-Debug "Invoke-FFmpeg: Deleted source file: $($File.FullName)"
        }
    } else {
        throw "Invoke-FFmpeg: FFmpeg exited with code $LASTEXITCODE. Output: $($ffmpegOutput -join "`n")"
    }
}
#endregion

#region Summarization
function Measure-Compression {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$InputFile,

        [Parameter(Mandatory)]
        [System.IO.FileInfo]$OutputFile
    )

    $originalSize = $InputFile.Length
    $compressedSize = $OutputFile.Length
    $savings = [math]::Round(($originalSize - $compressedSize) / $originalSize * 100, 2)
    Write-Host "Size reduction: $savings% (From $([math]::Round($originalSize/1MB, 2))MB to $([math]::Round($compressedSize/1MB, 2))MB)" -ForegroundColor Green
}
#endregion

#region Main
function Compress-Video {
    <#
    .SYNOPSIS
        Compress-Video - Compresses video files using FFmpeg with H.265 encoding.

    .DESCRIPTION
        Compresses video files using FFmpeg with H.265 encoding to reduce file size while maintaining quality.
        Can process either a single file or all supported video files in a directory.

    .PARAMETER InputFilePath
        Path to video file or directory to process.
        If directory, processes all supported video files within.
        If not specified, processes current directory.

    .PARAMETER OutputFilePath
        Optional output path for single file compression.
        Ignored when processing a directory.
        Default adds "_compressed.mp4" to original filename.

    .PARAMETER DeleteSource
        Delete source file after successful compression.
        Default is false.

    .PARAMETER Force
        Force compression without Skip confirmation prompts.
        Default is false.

    .PARAMETER Extensions
        Array of video file extensions to process.
        Default: .avi, .flv, .mp4, .mov, .mkv, .wmv

    .PARAMETER FFmpegArgs
        FFmpeg command arguments array.
        Default encoding settings:
        - Video: H.265/HEVC (libx265)
        - CRF: 28 (quality factor)
        - Preset: slow (better compression)
        - Audio: copy (unchanged)

    .EXAMPLE
        .\Compress-Video.ps1
        Processes all video files in current directory.

    .EXAMPLE
        .\Compress-Video.ps1 -i "video.mp4" -o "compressed.mp4"
        Compresses single video with custom output name.

    .EXAMPLE
        .\Compress-Video.ps1 "C:\Videos" -del
        Compresses all videos in directory and deletes originals.

    .NOTES
        Requires FFmpeg in system PATH.
    #>
    [CmdletBinding()]
    param (
        [Alias("i")]
        [Parameter(Position = 0)]
        [string]$InputFilePath = (Get-Location).Path,

        [Alias("o")]
        [Parameter(Position = 1)]
        [string]$OutputFilePath,

        [Alias("del")]
        [switch]$DeleteSource = $false,

        [Alias("f")]
        [switch]$Force = $false,

        [array]$Extensions = @(
            ".avi",
            ".flv",
            ".mp4",
            ".mov",
            ".mkv",
            ".wmv"),

        [array]$FFmpegArgs = @(
            '-i', 'null',
            '-c:v', 'libx265',
            '-crf', '28',
            '-preset', 'slow',
            '-c:a', 'copy',
            'null'
        )
    )

    try {
        Assert-FFmpeg

        if (-not (Test-Path -Path $InputFilePath)) {
            throw "Input path does not exist: $InputFilePath"
        }

        Write-Debug "InputFilePath: $InputFilePath"
        Write-Debug "OutputFilePath: $OutputFilePath"

        $video_files = Get-VideoFiles -InputPath $InputFilePath -Extensions $Extensions

        if ($video_files.Count -eq 0) {
            Write-Warning "No video files found in: $InputFilePath."
            return
        }

        foreach ($file in $video_files) {
            Write-Debug "Operating on File: $file"

            if ($file.Name -like "*_compressed*" -and -not $Force) {
                Write-Warning "Skipping: $($file.Name) (already compressed)"
                continue
            }

            $output_path = New-OutputPath -File $file -OutputFilePath $OutputFilePath
            Invoke-FFmpeg -File $file -OutputPath $output_path -FFmpegArgs $FFmpegArgs -DeleteSource:$DeleteSource
            Measure-Compression -InputFile $file -OutputFile (Get-Item $output_path)
        }
    } catch [System.IO.IOException] {
        Write-Error "File system error: $($_.Exception.Message)" -RecommendedAction "Check file permissions and try again."
        return
    } catch [System.Exception] {
        Write-Error "Compression failed: $($_.Exception.Message)"
        return
    }
}
#endregion

Compress-Video @PSBoundParameters
