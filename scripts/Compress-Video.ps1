param(
   [string]$InputFilePath,
   [string]$OutputFilePath,
   [switch]$Recompress,
   [switch]$DeleteSource,
   [switch]$Force,
   [array]$Extensions,
   [array]$FFmpegArgs
)

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

.PARAMETER Recompress
   Allow recompression of files already marked as compressed.
   By default, prompts before recompressing files with "_compressed" in name.

.PARAMETER DeleteSource
   Delete source file after successful compression.
   Default is false.

.PARAMETER Force
   Skip confirmation prompts.
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
      [string]$OutputFilePath = $null,

      [Alias("r")]
      [switch]$Recompress = $false,

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
         '-i', $null,
         '-c:v', 'libx265',
         '-crf', '28',
         '-preset', 'slow',
         '-c:a', 'copy',
         $null
      )
   )

   if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
      Write-Error "FFmpeg is not installed or not in the system's PATH."
      return
   }

   if (-not (Test-Path -Path $InputFilePath)) {
      Write-Error "Input path does not exist: $InputFilePath"
      return
   }

   Write-Debug "InputFilePath: $InputFilePath"
   $video_files = Get-VideoFiles -InputPath $InputFilePath -Extensions $Extensions

   foreach ($file in $video_files) {
      if ($file.Name -like "*_compressed*" -and -not $Recompress -and -not $Force) {
         Write-Host "Skipping: $($file.Name) (already compressed)" -ForegroundColor Yellow
         continue
      }

      $output_path = New-OutputPath -File $file -OutputFilePath $OutputFilePath -IsSingleFile ($video_files.Count -eq 1)

      Compress-File -File $file -OutputPath $output_path -FFmpegArgs $FFmpegArgs -DeleteSource:$DeleteSource
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
      [string]$InputPath,
      [array]$Extensions
   )

   # Validate input path so we know if it's a file or directory or invalid in order to operate on it
   if (-not (Test-Path $InputPath)) {
      Write-Error "The provided input path does not exist: $InputPath"
      return @()
   }

   if (Test-Path $InputPath -PathType Container) {       # If input path is a directory: return all supported video files
      return Get-ChildItem -Force -Path $InputPath -File | 
            Where-Object { $Extensions -contains $_.Extension.ToLower() }
   } elseif (Test-Path $InputPath -PathType Leaf) {      # Else, if input path is a file: return a single video file
      return @(Get-Item -Force $InputPath)
   } else {                                               # Else, input path is invalid: return empty array
      Write-Error "The provided input path is not valid: $InputPath"
      return @()
   }
}

function New-OutputPath {
   [CmdletBinding()]
   param(
      [System.IO.FileInfo]$File,
      [string]$OutputFilePath,
      [bool]$IsSingleFile
   )

   # If output path is not specified, add "_compressed.mp4" to original filename
   if ($IsSingleFile -and $OutputFilePath) {
      return $OutputFilePath
   } else {
      return Join-Path (Split-Path $File.FullName) "$([System.IO.Path]::GetFileNameWithoutExtension($File.FullName))_compressed.mp4"
   }
}

function Compress-File {
   [CmdletBinding()]
   param(
      [System.IO.FileInfo]$File,
      [string]$OutputPath,
      [array]$FFmpegArgs,
      [switch]$DeleteSource
   )

   $FFmpegArgs[1] = $File.FullName
   $FFmpegArgs[-1] = $OutputPath

   try {
      Write-Host "Compressing: $($File.FullName)" -ForegroundColor Cyan
      Write-Verbose "FFmpeg command: ffmpeg $FFmpegArgs"
      & ffmpeg @FFmpegArgs

      if ($LASTEXITCODE -eq 0) {
         Write-Host "Compression successful: $OutputPath" -ForegroundColor Green
         LogCompressionResults -File $File -OutputPath $OutputPath

         if ($DeleteSource) {
            Remove-Item -Path $File.FullName -Force
            Write-Host "Deleted source file: $($File.FullName)" -ForegroundColor Yellow
         }
      } else {
         Write-Error "FFmpeg failed with exit code: $LASTEXITCODE"
         return
      }
   } catch {
      Write-Error "Compression failed: $($_.Exception.Message)"
      return
   }
}

function LogCompressionResults {
   [CmdletBinding()]
   param(
      [System.IO.FileInfo]$File,
      [string]$OutputPath
   )

   $originalSize = $File.Length
   $compressedSize = (Get-Item $OutputPath).Length
   $savings = [math]::Round(($originalSize - $compressedSize) / $originalSize * 100, 2)
   Write-Host "Size reduction: $savings% (From $([math]::Round($originalSize/1MB, 2))MB to $([math]::Round($compressedSize/1MB, 2))MB)" -ForegroundColor Green
}

Compress-Video @PSBoundParameters