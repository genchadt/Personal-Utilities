function Update-M365 {
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [string]$C2RClientPath = "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe",

        [Parameter(Position=1)]
        [string]$C2R_args = "/update user"
    )

    $C2RClientName = [System.IO.Path]::GetFileName($C2RClientPath)

    try {
        Write-Verbose "Attemping to launch $C2RClientName..."
        Write-Verbose "C2R Command: $C2RClientPath $C2R_args"
        & $C2RClientPath $C2R_args
    }
    catch {
        Write-Warning "Update-M365: Failed to start Office update process: $_"
    }    
}