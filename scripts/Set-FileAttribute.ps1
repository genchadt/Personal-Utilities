function Set-FileAttribute {
<#
.SYNOPSIS
    Set-FileAttribute - Sets file attributes.

.DESCRIPTION
    This function sets file attributes on specified paths.
    Use it to add/remove hidden and system attributes.

.PARAMETER Path
    The path to the file or directory.

.PARAMETER Hidden
    Adds the hidden attribute to the file or directory.

.PARAMETER System
    Adds the system attribute to the file or directory.

.PARAMETER Recurse
    Recursively sets attributes on subdirectories.

.PARAMETER Force
    Overwrites existing files without prompting.

.EXAMPLE
    Set-FileAttribute -Path "C:\Users\username\Documents" -Hidden -Recurse -Force
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Alias("p")]
        [Parameter(Position = 0)]
        [String[]]$Path = $PWD,

        [Alias("h")]
        [Switch]$Hidden,

        [Alias("s")]
        [Switch]$System,

        [Alias("r")]
        [Switch]$Recurse,

        [Alias("f")]
        [Switch]$Force
    )

    process {
        # Determine paths to process
        $processPaths = $Force ? @($PWD) : $Path
        foreach ($itemPath in $processPaths) {
            try {
                if (-not (Test-Path $itemPath)) {
                    throw "Path '$itemPath' does not exist."
                }

                # Handle directories and files with recursion if specified
                $itemsToProcess = if ((Get-Item $itemPath -Force) -is [System.IO.DirectoryInfo] -and $Recurse) {
                    Get-ChildItem -Path $itemPath -Recurse -Force
                } else {
                    @((Get-Item $itemPath -Force))
                }

                foreach ($item in $itemsToProcess) {
                    if ($PSCmdlet.ShouldProcess($item.FullName, "Set File Attributes")) {
                        # Retrieve current attributes
                        $currentAttributes = $item.Attributes

                        # Modify System attribute based on the presence of -System
                        if ($System) {
                            if ($currentAttributes.HasFlag([System.IO.FileAttributes]::System)) {
                                $item.Attributes = $currentAttributes -band (-bnot [System.IO.FileAttributes]::System)
                                Write-Verbose "Removed 'System' attribute from '$($item.FullName)'."
                            } else {
                                $item.Attributes = $currentAttributes -bor [System.IO.FileAttributes]::System
                                Write-Verbose "Set 'System' attribute on '$($item.FullName)'."
                            }
                        }

                        # Set or remove Hidden attribute based on -Hidden switch
                        if ($Hidden) {
                            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
                            Write-Verbose "Set 'Hidden' attribute on '$($item.FullName)'."
                        } else {
                            $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
                            Write-Verbose "Removed 'Hidden' attribute from '$($item.FullName)'."
                        }
                    }
                }
            } catch {
                Write-Error $_.Exception.Message
            }
        }
    }
}

$params = @{
    Path    = $Path
    Hidden  = $Hidden
    System  = $System
    Recurse = $Recurse
    Force   = $Force
    Debug   = $Debug
    Verbose = $Verbose

}
Set-FileAttribute @params