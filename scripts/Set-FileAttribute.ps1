param (
    [string]$Path,
    [switch]$Hidden,
    [switch]$System,
    [switch]$Add,
    [switch]$Remove,
    [switch]$Recurse,
    [switch]$Force
)

#region Helpers
function AddAttribute {
<#
.SYNOPSIS
    AddAttribute - Adds a specified attribute to the file or directory.

.DESCRIPTION
    This function adds a specified attribute to the file or directory.

.PARAMETER Attributes
    The attributes of the file or directory.

.PARAMETER AttributeToAdd
    The attribute to add.

.INPUTS
    System.IO.FileAttributes

.OUTPUTS
    System.IO.FileAttributes

.EXAMPLE
    $attributes = AddAttribute -Attributes $attributes -AttributeToAdd ([System.IO.FileAttributes]::Hidden)
#>
    param (
        [System.IO.FileAttributes]$Attributes,
        [System.IO.FileAttributes]$AttributeToAdd
    )

    if (-not $Attributes.HasFlag($AttributeToAdd)) {
        Write-Verbose "Adding attribute: $AttributeToAdd"
        return $Attributes -bor $AttributeToAdd
    } else {
        Write-Verbose "Attribute already present: $AttributeToAdd"
        return $Attributes
    }
}

function RemoveAttribute {
<#
.SYNOPSIS
    RemoveAttribute - Removes a specified attribute from the file or directory.

.DESCRIPTION
    This function removes a specified attribute from the file or directory.

.PARAMETER Attributes
    The attributes of the file or directory.

.PARAMETER AttributeToRemove
    The attribute to remove.

.INPUTS
    System.IO.FileAttributes

.OUTPUTS
    System.IO.FileAttributes

.EXAMPLE
    $attributes = RemoveAttribute -Attributes $attributes -AttributeToRemove ([System.IO.FileAttributes]::Hidden)
#>
    param (
        [System.IO.FileAttributes]$Attributes,
        [System.IO.FileAttributes]$AttributeToRemove
    )

    if ($Attributes.HasFlag($AttributeToRemove)) {
        Write-Verbose "Removing attribute: $AttributeToRemove"
        return $Attributes -band (-bnot $AttributeToRemove)
    } else {
        Write-Verbose "Attribute not present: $AttributeToRemove"
        return $Attributes
    }
}

function ToggleAttribute {
<#
.SYNOPSIS
    ToggleAttribute - Toggles a specified attribute on the file or directory.

.DESCRIPTION
    This function toggles a specified attribute on the file or directory.
    Binary toggle, so if the attribute is present, it will be removed, and vice versa.

.PARAMETER Attributes
    The attributes of the file or directory.

.PARAMETER AttributeToToggle
    The attribute to toggle.

.INPUTS
    System.IO.FileAttributes

.OUTPUTS
    System.IO.FileAttributes

.EXAMPLE
    $attributes = ToggleAttribute -Attributes $attributes -AttributeToToggle ([System.IO.FileAttributes]::Hidden)
#>
    param (
        [System.IO.FileAttributes]$Attributes,
        [System.IO.FileAttributes]$AttributeToToggle
    )

    if ($Attributes.HasFlag($AttributeToToggle)) {
        return $Attributes -band (-bnot $AttributeToToggle)
    } else {
        return $Attributes -bor $AttributeToToggle
    }
}
#endregion

#region Main
function Set-FileAttribute {
    <#
    .SYNOPSIS
        Set-FileAttribute - Sets file attributes.
    
    .DESCRIPTION
        This function sets file attributes on specified paths.
        Use it to toggle, add, or remove hidden and system attributes.
    
    .PARAMETER Path
        The path to the file or directory.
    
    .PARAMETER Hidden
        Toggles the hidden attribute on the file or directory.
    
    .PARAMETER System
        Toggles the system attribute on the file or directory.
    
    .PARAMETER Add
        Adds the specified attributes to the file or directory.
    
    .PARAMETER Remove
        Removes the specified attributes from the file or directory.
    
    .PARAMETER Recurse
        Recursively sets attributes on subdirectories and files.
    
    .PARAMETER Force
        Overwrites existing files without prompting.
    
    .EXAMPLE
        Set-FileAttribute -Path "C:\Users\username\Documents" -Hidden -Recurse -Force
    #>
    [CmdletBinding()]
    param (
        [Alias("p")]
        [Parameter(Position = 0)]
        [String]$Path = (Get-Location).Path,

        [Alias("h")]
        [Switch]$Hidden,

        [Alias("s")]
        [Switch]$System,

        [Alias("a")]
        [Switch]$Add,

        [Alias("r")]
        [Switch]$Remove,

        [Alias("rec")]
        [Switch]$Recurse,

        [Alias("f")]
        [Switch]$Force
    )

    # Determine paths to process
    $processPaths = $Force ? @($PWD) : $Path

    foreach ($itemPath in $processPaths) {
        if (-not (Test-Path $itemPath)) {
            Write-Error "Path '$itemPath' does not exist."
            continue
        }

        # Handle directories and files with recursion if specified
        $itemsToProcess = if ((Get-Item $itemPath -Force) -is [System.IO.DirectoryInfo] -and $Recurse) {
            Get-ChildItem -Path $itemPath -Recurse -Force
        } else {
            @((Get-Item $itemPath -Force))
        }

        try {
            foreach ($item in $itemsToProcess) {
                $currentAttributes = $item.Attributes
                Write-Verbose "Current attributes for '$($item.FullName)': $currentAttributes"

                $attributesToProcess = @()
                if ($Hidden) { $attributesToProcess += [System.IO.FileAttributes]::Hidden }
                if ($System) { $attributesToProcess += [System.IO.FileAttributes]::System }

                foreach ($attribute in $attributesToProcess) {
                    if ($Add) {
                        $item.Attributes = AddAttribute -Attributes $item.Attributes -AttributeToAdd $attribute
                        Write-Verbose "Added '$attribute' attribute to '$($item.FullName)'."
                    } elseif ($Remove) {
                        $item.Attributes = RemoveAttribute -Attributes $item.Attributes -AttributeToRemove $attribute
                        Write-Verbose "Removed '$attribute' attribute from '$($item.FullName)'."
                    } else {
                        $item.Attributes = ToggleAttribute -Attributes $item.Attributes -AttributeToToggle $attribute
                        Write-Verbose "Toggled '$attribute' attribute on '$($item.FullName)'."
                    }
                }
                
            }
        } catch {
            Write-Error "Failed to set attributes on '$itemPath': $_" -ErrorAction Continue
        }
    }
}
#endregion

Set-FileAttribute @PSBoundParameters