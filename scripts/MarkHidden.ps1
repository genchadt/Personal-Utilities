Get-ChildItem -Recurse -Force | ForEach-Object {
    $path = $_.FullName
    $currentAttributes = (Get-Item $path -Force).Attributes

    # Check if the item is already hidden to prevent unnecessary actions
    if (-not ($currentAttributes -band [System.IO.FileAttributes]::Hidden)) {
        # Add Hidden attribute while keeping existing attributes
        Set-ItemProperty -Path $path -Name Attributes -Value ($currentAttributes -bor [System.IO.FileAttributes]::Hidden)
    }
}
