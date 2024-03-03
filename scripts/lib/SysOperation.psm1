function Get-CurrentDirectorySize {
    $initialDirectorySizeBytes = (Get-ChildItem -Path . -Recurse -Force | Measure-Object -Property Length -Sum).Sum
    return $initialDirectorySizeBytes
}

function Invoke-Command {
    param (
        [string]$Command
    )

    Write-Console "Executing: $Command`n"

    try {
        $output = Invoke-Expression $Command -ErrorAction Stop
    } catch {
        ErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
    }

    Write-Log $output
    return $output
}