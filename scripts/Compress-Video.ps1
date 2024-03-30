<#
.SYNOPSIS
   Compress-Video.ps1 - A PowerShell script to compress video files in a given folder and its subfolders using the FFmpeg tool.

.DESCRIPTION
   This PowerShell script is designed to compress video files in a given folder and its subfolders using the FFmpeg tool. It provides options to specify the compression level and delete the source files after successful compression.

.PARAMETER FolderPath
   The path to the folder containing the video files to be compressed. If not provided, the script will use the current working directory.

.PARAMETER DeleteSourceFiles
   A switch parameter that determines whether the source video files should be deleted after successful compression.

.EXAMPLE
   .\Compress-Video.ps1 -FolderPath "C:\Videos" -DeleteSourceFiles
   Compresses all video files in the "C:\Videos" folder and its subfolders, and deletes the source files after successful compression.

.EXAMPLE
   .\Compress-Video.ps1
   Compresses all video files in the current working directory and its subfolders, without deleting the source files.

.NOTES
   - This script requires the FFmpeg tool to be installed and available in the system's PATH.
   - The compression settings (codec, CRF value, preset, etc.) can be adjusted in the `Compress-Video` function.
   - Supported video file extensions: .mp4, .avi, .mkv, .mov (can be modified in the `$VideoExtensions` array).
   - Error handling and logging functionalities are provided through the `ErrorHandling.psm1` and `TextHandling.psm1` modules.
   - The `SysOperation.psm1` module is also required but not used in the provided code.

.LINK
   FFmpeg: https://ffmpeg.org/

.INPUTS
   None

.OUTPUTS
   Console output with status messages and compressed video files in the respective folders.
#>

function Compress-Video {
    param(
        [string]$VideoPath,
        [switch]$DeleteSource
    )

    Write-Host "Attempting to compress: $VideoPath"

    $OutputPath = "$VideoPath_compressed.mp4"  # Simplified for testing
    $Bitrate = "1000k"

    Write-Host "Output path: $OutputPath"
    
    $ffmpegArgs = @('-i', $VideoPath, '-c:v', 'libx265', '-crf', '28', '-preset', 'slow', '-c:a', 'copy', $OutputPath)
    & ffmpeg $ffmpegArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Compressed video saved as: $OutputPath"
        if ($DeleteSource) {
            Remove-Item -Path $VideoPath -Force
            Write-Host "Deleted source file: $VideoPath"
        }
    } else {
        Write-Host "ffmpeg failed with exit code $LASTEXITCODE"
    }
}

function Process-Folder {
    param(
        [string]$FolderPath = (Get-Location),
        [switch]$DeleteSourceFiles
    )

    Write-Host "Processing Folder: $FolderPath"
    
    $VideoExtensions = @(".mp4", ".avi", ".mkv", ".mov")
    $files = Get-ChildItem -Path $FolderPath -Recurse -File -Force | Where-Object { $VideoExtensions -contains $_.Extension.ToLower() }
    
    if ($files.Count -eq 0) {
        Write-Host "No video files found."
        return
    }

    $files | ForEach-Object {
        Compress-Video -VideoPath $_.FullName -DeleteSource:$DeleteSourceFiles
    }
}

Process-Folder -DeleteSourceFiles:$false
