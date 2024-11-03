function Set-FileAttribute {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Alias("p")]
        [Parameter(
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [String[]]$Path = $PWD,

        [Alias("h")]
        [Switch]$Hidden,

        [Alias("v")]
        [Switch]$Visible,

        [Alias("r")]
        [Switch]$Recurse,

        [Alias("f")]
        [Switch]$Force,

        [Alias("s")]
        [Switch]$System
    )

    begin {
        # Validate parameter compatibility
        if ($Hidden -and $Visible) {
            Write-Error "Cannot specify both -Hidden and -Visible flags."
            return
        }
    }

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

                        # Modify Hidden attribute based on -Hidden and -Visible switches
                        if ($Hidden) {
                            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
                            Write-Verbose "Set 'Hidden' attribute on '$($item.FullName)'."
                        } elseif ($Visible) {
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

# Example usage with parameter splatting
$params = @{
    Path = $Path
    Hidden = $Hidden
    Visible = $Visible
    Recurse = $Recurse
    Force = $Force
    System = $System
}
Set-FileAttribute @params
