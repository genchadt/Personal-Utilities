[CmdletBinding()]
param (
    [array]$Entries
)

function Start-Web {
    [CmdletBinding()]
    param (
        [array]$Entries
    )

    foreach ($entry in $Entries) {
        Write-Debug "Processing entry: $entry"

        if (Test-Path $entry) {
            Write-Debug "Entry is an executable: $entry"
            try {
                $workingDir = Split-Path $entry
                Write-Debug "Attempting to start: $entry in $workingDir"
                $process = Start-Process -FilePath $entry -WorkingDirectory $workingDir -PassThru
                Write-Debug "Process started with ID: $($process.Id)"

            } catch {
                Write-Error "Start-Web: Failed to start $($entry): $_" -ErrorAction Continue
            }
        } else {
            try {
                Write-Debug "Entry is a command: $entry"
                Invoke-Expression $entry
            } catch {
                Write-Error "Start-Web: Failed to execute $($entry): $_" -ErrorAction Continue
            }
        }
    }
}

Start-Web -Entries @(
    "C:\nginx-1.27.2\nginx.exe",
    "cd S:\Dev\external\big-AGI && npm run build && npm run start"
)
