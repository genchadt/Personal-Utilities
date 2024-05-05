<#
.SYNOPSIS
   Compress-Video.ps1 - A PowerShell script to compress video files using FFmpeg.

.DESCRIPTION
   This script compresses video files in a specified folder and its subfolders, with options to specify compression level and delete source files after compression.

.PARAMETER FolderPath
   The path to the folder containing video files. Defaults to the current working directory.

.PARAMETER DeleteSourceFiles
   Determines whether the source video files should be deleted after compression.

.EXAMPLE
   .\Compress-Video.ps1 -FolderPath "C:\Videos" -DeleteSourceFiles
   Compresses and deletes the source files in "C:\Videos".

.EXAMPLE
   .\Compress-Video.ps1
   Compresses video files in the current directory without deleting them.

.NOTES
   Requires FFmpeg in the system's PATH. Modify compression settings in the `Compress-Video` function.
#>

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
      [switch]$DeleteSourceFiles
   )
   
   $output_path = $VideoPath -replace '\.[^.]+$', '_compressed.mp4'
   $bitrate = "1000k"  # You can adjust this value according to your needs.
   $ffmpeg_args = '-i', $VideoPath, '-c:v', 'libx265', '-crf', '28', '-preset', 'slow', '-b:v', $bitrate, '-c:a', 'copy', $output_path
   
   try {
      Write-Host "Compressing: $VideoPath"
      & ffmpeg $ffmpeg_args
      if ($LASTEXITCODE -eq 0) {
         Write-Host "Compression successful: $output_path"
         if ($DeleteSourceFiles) {
            Remove-Item -Path $VideoPath -Force
            Write-Host "Deleted source file: $VideoPath"
         }
      } else {
      Write-Host "FFmpeg failed with exit code: $LASTEXITCODE"
   }
   } catch {
      Write-Console "Issue encountered while attempting to compress $VideoPath." -MessageType Error
      ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace -Severity Error
   }
}

function Use-Compression {
   param(
      [string]$FolderPath = (Get-Location).Path,
      [switch]$DeleteSourceFiles
   )
   
   Write-Host "Processing folder: $FolderPath"
   $files = Get-ChildItem -Path $FolderPath -Recurse -File -Force | Where-Object { $_.Extension -in $video_extensions }
   
   foreach ($file in $files) {
      Compress-Video -VideoPath $file.FullName -DeleteSourceFiles:$DeleteSourceFiles
   }
}

if ($MyInvocation.InvocationName -ne '.') {
   Use-Compression @PSBoundParameters
}