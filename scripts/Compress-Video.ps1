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

###############################################
# Parameters
###############################################

param (
   [string]$VideoPath,
   [switch]$IgnoreCompressed,
   [switch]$DeleteSource
)

###############################################
# Functions
###############################################

function Compress-Video {
   param(
      [string]$VideoPath,
      [switch]$IgnoreCompressed,
      [switch]$DeleteSource
   )

   $extensions = ".avi", ".flv", ".mp4", ".mov", ".mkv", ".wmv"
   $video_files = @()

   # If no path is provided, work in the current directory
   if (-not $VideoPath) {
      $VideoPath = Get-Location
   }

   if (Test-Path $VideoPath -PathType Container) {
      # Get files matching the specified extensions
      $video_files = Get-ChildItem -Force -Path $VideoPath -File | Where-Object {
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

      # Add to list of files to be compressed
      $confirmation_responses[$file.Name] = 'Y'
   }

   foreach ($file in $video_files) {
      if ($confirmation_responses[$file.Name] -ne 'Y') {
         continue
      }

      $output_path = Join-Path (Split-Path $file.FullName) "$($([System.IO.Path]::GetFileNameWithoutExtension($file.FullName)))_compressed.mp4"

      # FFmpeg arguments
      $ffmpeg_args = @(
         '-i', $file.FullName,
         '-c:v', 'libx265',
         '-crf', '28',
         '-preset', 'slow',
         '-c:a', 'copy',
         $output_path
      )

      try {
         Write-Host "Compressing: $($file.FullName)" -ForegroundColor Cyan
         & ffmpeg @ffmpeg_args
         if ($LASTEXITCODE -eq 0) {
            Write-Host "Compression successful: $output_path" -ForegroundColor Green
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

###############################################
# Execution
###############################################

$params = @{
   VideoPath        = $VideoPath
   IgnoreCompressed = $IgnoreCompressed
   DeleteSource     = $DeleteSource
}

Compress-Video @params
