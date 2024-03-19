###############################################
# Parameters
###############################################

param (
    [alias("p")][string[]]$Path = $PWD,
    [alias("h")][switch]$Hidden,
    [alias("v")][switch]$Visible,
    [alias("r")][switch]$Recurse,
    [alias("f")][switch]$Force
)

###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot\lib\ErrorHandling.psm1"
Import-Module "$PSScriptRoot\lib\TextHandling.psm1"
Import-Module "$PSScriptRoot\lib\SysOperation.psm1"

###############################################
# Main Loop
###############################################

if ($args.Count -eq 0 -and !$Force) {
    Write-Error "Please specify at least one path or use the -Force parameter."
}

try {
    # Check if both -Hidden and -Visible are specified
    if ($Hidden -and $Visible) {
        throw "Cannot specify both -Hidden and -Visible flags."
    }

    # Check if the script is run with -Force parameter
    if ($Force) {
        $ForcePath = $PWD
        if ($Hidden) {
            # Set visibility of files and subdirectories to hidden
            Get-ChildItem -Path $ForcePath -Recurse -Force | ForEach-Object {
                $_.Attributes += "Hidden"  # Add Hidden attribute
            }
        }
        else {
            # Set visibility of files and subdirectories to visible
            Get-ChildItem -Path $ForcePath -Recurse -Force | ForEach-Object {
                $_.Attributes = $_.Attributes -bxor [System.IO.FileAttributes]::Hidden  # Remove Hidden attribute
            }
        }
    }    
    else {
        # Iterate through each path
        foreach ($itemPath in $Path) {
            # Check if the path exists
            if (-not (Test-Path $itemPath)) {
                throw "Path '$itemPath' does not exist."
            }

            # Check if the path points to a single file
            if (Test-Path $itemPath -PathType Container) {
                # Toggle visibility of the file if $Hidden or $Visible is not specified
                if (-not ($Hidden -or $Visible)) {
                    $currentAttributes = (Get-Item $itemPath -Force).Attributes
                    $newAttributes = $currentAttributes -bxor [System.IO.FileAttributes]::Hidden  # Toggle the Hidden attribute
                    Set-ItemProperty -Path $itemPath -Name Attributes -Value $newAttributes
                } elseif ($Hidden) {
                    # Set visibility of file to hidden
                    $newAttributes = (Get-Item $itemPath -Force).Attributes -bor [System.IO.FileAttributes]::Hidden
                    Set-ItemProperty -Path $itemPath -Name Attributes -Value $newAttributes
                } elseif ($Visible) {
                    # Set visibility of file to visible
                    $newAttributes = (Get-Item $itemPath -Force).Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
                    Set-ItemProperty -Path $itemPath -Name Attributes -Value $newAttributes
                }
            }
            else {
                if ($Hidden -or $Visible) {
                    # If it's a directory and -Hidden or -Visible are specified, recursively set all files and subdirectories of the path to the same visibility (including the path itself)
                    if ($Recurse) {
                        Get-ChildItem -Path $itemPath -Recurse -Force | ForEach-Object {
                            $currentAttributes = (Get-Item $_.FullName -Force).Attributes
                            $newAttributes = $currentAttributes -bxor [System.IO.FileAttributes]::Hidden  # Toggle the Hidden attribute
                            Set-ItemProperty -Path $_.FullName -Name Attributes -Value $newAttributes
                        }
                    }
                    else {
                        Get-ChildItem -Path $itemPath -Force | ForEach-Object {
                            $currentAttributes = (Get-Item $_.FullName -Force).Attributes
                            $newAttributes = $currentAttributes -bxor [System.IO.FileAttributes]::Hidden  # Toggle the Hidden attribute
                            Set-ItemProperty -Path $_.FullName -Name Attributes -Value $newAttributes
                        }
                    }
                }
            }
        }
    }
} catch {
    # Handle errors using ErrorHandling function
    ErrorHandling -ErrorMessage $_ -StackTraceValue $_.StackTrace
}
