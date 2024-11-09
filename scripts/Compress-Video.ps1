<#
.SYNOPSIS
   Compress-Video.ps1 - A PowerShell script to simplify video compression using FFmpeg.

.DESCRIPTION
   This script is designed to save file space while preserving as much quality as possible.

.PARAMETER VideoPath
   The optional path to the video file to be compressed. If not specified, the script processes all supported video files in the current directory.

.PARAMETER IgnoreCompressed
   Determines whether the script should ignore already compressed files.

.PARAMETER DeleteSource
   Determines whether the source video file should be deleted after compression.

.EXAMPLE
   .\Compress-Video.ps1 -VideoPath "C:\Videos\video.mp4" -DeleteSource
   Compresses the video file "C:\Videos\video.mp4" and deletes the source file.

.EXAMPLE
   .\Compress-Video.ps1
   Processes all supported video files in the current directory.

.NOTES
   Requires FFmpeg in the system's PATH. Modify compression settings in the `Compress-Video` function.
#>
[CmdletBinding()]
param (
   [Alias("path")]
   [Parameter(Position = 0, Mandatory = $true)]
   [ValidateScript({Test-Path $_})]
   [string]$VideoPath = (Get-Location).Path,

   [Parameter(Position = 1, Mandatory = $false)]
   [switch]$IgnoreCompressed = $false,

   [Parameter(Position = 2, Mandatory = $false)]
   [switch]$DeleteSource = $false,

   [array]$extensions = @(
      ".avi",
      ".flv",
      ".mp4",
      ".mov",
      ".mkv",
      ".wmv"),

   [array]$ffmpeg_args = @(
      '-i', $null,
      '-c:v', 'libx265',
      '-crf', '28',
      '-preset', 'slow',
      '-c:a', 'copy',
      $null
   )
)

function Compress-Video {
   param(
      [CmdletBinding()]
      [string]$VideoPath,
      [switch]$IgnoreCompressed,
      [switch]$DeleteSource,
      [array]$extensions,
      [array]$ffmpeg_args
   )

   $video_files = @()

   # Script won't work without ffmpeg
   if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
      Write-Error "FFmpeg is not installed or not in the system's PATH."
      Write-Error "Please install FFmpeg or add it to PATH and try again."
      return
   }
   
   if (Test-Path $VideoPath -PathType Container) {
      Write-Verbose "Searching for video files matching extension rules in: $VideoPath"
      $video_files = Get-ChildItem -Force -Path $VideoPath -File | Where-Object {
         Write-Verbose "Extension: $($_.Extension)"
         $extensions -contains $_.Extension.ToLower()
      }
   } elseif (Test-Path $VideoPath -PathType Leaf) {
      $video_files = @(Get-Item -Force $VideoPath)
   } else {
      Write-Error "The specified path does not exist: $VideoPath"
      return
   }

   $confirmation_responses = @{}

   foreach ($file in $video_files) {
      if ($file.Name -like "*_compressed*") {
         if ($IgnoreCompressed) {
            Write-Host "Skipping already compressed file: $($file.Name)" -ForegroundColor Green
            continue
         } else {
            $response = Read-Host "The file '$($file.Name)' appears to be already compressed. Do you want to recompress it? (Y/N)"
            if ($response -ne 'Y') {
               Write-Host "Skipping: $($file.Name)" -ForegroundColor Yellow
               continue
            }
         }
      }

      $confirmation_responses[$file.Name] = 'Y'
   }

   foreach ($file in $video_files) {
      if ($confirmation_responses[$file.Name] -ne 'Y') {
         # User asked not to compress this file
         continue
      }

      $output_path = Join-Path (Split-Path $file.FullName) "$($([System.IO.Path]::GetFileNameWithoutExtension($file.FullName)))_compressed.mp4"

      # Placeholders for path arguments were null... until now!
      $ffmpeg_args[1] = $file.FullName
      $ffmpeg_args[-1] = $output_path

      try {
         Write-Host "Compressing: $($file.FullName)" -ForegroundColor Cyan
         Write-Verbose "FFmpeg command: ffmpeg $ffmpeg_args"
         & ffmpeg @ffmpeg_args
         if ($LASTEXITCODE -eq 0) {
            Write-Host "Compression successful: $output_path" -ForegroundColor Green

            $originalSize = (Get-Item $file.FullName).Length
            $compressedSize = (Get-Item $output_path).Length
            $savings = [math]::Round(($originalSize - $compressedSize) / $originalSize * 100, 2)
            Write-Host "Size reduction: $savings% (From $([math]::Round($originalSize/1MB, 2))MB to $([math]::Round($compressedSize/1MB, 2))MB)" -ForegroundColor Green

            if ($DeleteSource) {
               Remove-Item -Path $file.FullName -Force
               Write-Host "Deleted source file: $($file.FullName)" -ForegroundColor Yellow
            }
         } else {
            Write-Error "FFmpeg failed with exit code: $LASTEXITCODE"
         }
      } catch {
         Write-Error "Issue encountered while attempting to compress $($file.FullName): $($_.Exception.Message)"
         Write-Debug "StackTrace: $($_.Exception.StackTrace)"
      }
   }
}

$params = @{
   VideoPath = $VideoPath
   IgnoreCompressed = $IgnoreCompressed
   DeleteSource = $DeleteSource
   ffmpeg_args = $ffmpeg_args
   extensions = $extensions
}
Compress-Video @params