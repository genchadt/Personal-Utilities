<#
.SYNOPSIS
   Compress-Video.ps1 - A PowerShell script to simplify video compression using FFmpeg. 

.DESCRIPTION
   This script is designed to save file space while preserving as much qu ality as possible.

.PARAMETER VideoPath
   The optional path to the video file to be compressed. If not specified, the script prompts for each '.mp4' file in the current directory.

.PARAMETER IgnoreCompressed
   Determines whether the script should ignore already compressed files.

.PARAMETER DeleteSource
   Determines whether the source video file should be deleted after compression.

.EXAMPLE
   .\Compress-Video.ps1 -VideoPath "C:\Videos\video.mp4" -DeleteSource
   Compresses the video file "C:\Videos\video.mp4" and deletes the source file.

.EXAMPLE
   .\Compress-Video.ps1
   Prompts for each '.mp4' file in the current directory and compresses them based on user input.

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
# Imports
###############################################

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

###############################################
# Functions
###############################################

function Compress-Video {
   param(
      [string]$VideoPath,
      [switch]$IgnoreCompressed,
      [switch]$DeleteSource
   )

   $search_pattern = "*.mp4"
   $video_files = @()

   if (-not $VideoPath) {
      $VideoPath = Get-Location
      $video_files = Get-ChildItem -Force -Path "." -Filter $search_pattern -File
   } else {
      $video_files = @(Get-Item $VideoPath)
   }

   $confirmation_responses = @{}

   foreach ($file in $video_files) {
      if ($file.Name -like "*_compressed*") {
         if ($IgnoreCompressed) {
            Write-Console -Text "Skipping already compressed file: $($file.Name)" -MessageType Info
            continue
         } else {
            $confirmation_responses[$file.Name] = Read-Console -Text "The file '$($file.Name)' appears to be already compressed. Do you want to recompress it?" -Prompt "YN" -MessageType Warning
            if ($confirmation_responses[$file.Name] -ne 'Y') {
               Write-Console -Text "Skipping: $($file.Name)" -MessageType Info
               continue
            }
         }
      } else {
         $confirmation_responses[$file.Name] = 'Y' # Default to compress if not already compressed
      }
   }

   foreach ($file in $video_files) {
      if ($confirmation_responses[$file.Name] -ne 'Y') {
         continue
      }

      $output_path = Join-Path (Split-Path $file.FullName) "$($([System.IO.Path]::GetFileNameWithoutExtension($file.FullName)))_compressed.mp4"
      $bitrate = "1000k"
      $ffmpeg_args = '-i', $file.FullName, '-c:v', 'libx265', '-crf', '28', '-preset', 'slow', '-b:v', $bitrate, '-c:a', 'copy', $output_path

      try {
         Write-Console -Text "Compressing: $($file.FullName)" -MessageType Info
         & ffmpeg $ffmpeg_args
         if ($LASTEXITCODE -eq 0) {
            Write-Console -Text "Compression successful: $output_path" -MessageType Info
            if ($DeleteSource) {
               Remove-Item -Path $file.FullName -Force
               Write-Console -Text "Deleted source file: $($file.FullName)" -MessageType Info
            }
         } else {
            Write-Console -Text "FFmpeg failed with exit code: $LASTEXITCODE" -MessageType Error
         }
      } catch {
         Write-Console -Text "Issue encountered while attempting to compress $($file.FullName)." -MessageType Error
         ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace -Severity Error
      }
   }
}

$params = @{
   VideoPath = $VideoPath
   DeleteSource = $DeleteSource
   IgnoreCompressed = $IgnoreCompressed
}

if ($MyInvocation.InvocationName -ne '.') { Compress-Video @params }