#region File System
function Get-ShortenedFileName {
    <#
    .SYNOPSIS
        Get-ShortenedFileName - Shortens a file name to a specified length.
    
    .PARAMETER FileName
        The file name to shorten.
    #>
        [CmdletBinding()]
        param (
            [string]$FileName,
            [int]$MaxLength = 20
        )
    
        if ($FileName.Length -le $MaxLength) {
            return $FileName
        }
    
        $extension = [System.IO.Path]::GetExtension($FileName)
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
        $shortenedName = $baseName.Substring(0, $MaxLength - $extension.Length) + $extension
    
        return $shortenedName
}
#endregion

#region Exports
Export-ModuleMember -Function Get-ShortenedFileName
#endregion