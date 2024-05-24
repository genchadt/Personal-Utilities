function Get-Configuration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath)) {
        Write-Error "Configuration file not found at $FilePath."
        exit 1
    }

    try {
        if ($FilePath -match '\.json$') {
            return Read-JsonConfig -FilePath $FilePath
        } else {
            return Read-TextConfig -FilePath $FilePath
        }
    } catch {
        throw "Failed to process config file '$FilePath': $_"
    }
}

function Read-Json-Config($FilePath) {
    try {
        return Get-Content $FilePath -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to read JSON config file '$FilePath': $_"
    }
}

function Read-Text-Config {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    $processedLines = @()

    try {
        $lines = Get-Content $FilePath -ErrorAction Stop

        foreach ($line in $lines) {
            # Remove inline comments and trim each line
            $processedLine = $line -split '#' | Select-Object -First 1 | ForEach-Object { $_.Trim() }

            # Skip empty lines or lines that became empty after processing
            if (-not $processedLine) {
                continue
            }

            # Add processed line to the array
            $processedLines += $processedLine
        }

        return $processedLines
    } catch {
        throw "Failed to read text config file '$FilePath': $_"
    }
}

function Get-CurrentDirectorySize {
    $initial_directory_size_bytes = (Get-ChildItem -Path . -Recurse -Force | Measure-Object -Property Length -Sum).Sum
    return $initial_directory_size_bytes
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

function Remove-ItemSafely {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string]$Path
    )

    process {
        if ($PSCmdlet.ShouldProcess($Path, "Move to Recycle Bin")) {
            try {
                # Ensure the path resolves to an item
                $resolved_path = Resolve-Path -Path $Path -ErrorAction Stop
                $item = Get-Item -LiteralPath $resolved_path.Path -ErrorAction Stop

                $shell = New-Object -ComObject "Shell.Application"
                $folder = $shell.Namespace($item.Directory.FullName)
                $file = $folder.ParseName($item.Name)

                if ($null -ne $file) {
                    $file.InvokeVerb("delete")
                    Write-Output "Moved to Recycle Bin: $resolved_path.Path"
                } else {
                    Write-Error "Failed to locate item for Recycle Bin operation: $resolved_path.Path"
                }
            } catch {
                Write-Error "Error moving item to Recycle Bin: $_.Exception.Message"
            }
        }
    }
}

Export-ModuleMember -Function Get-Configuration
Export-ModuleMember -Function Get-CurrentDirectorySize
Export-ModuleMember -Function Invoke-Command
Export-ModuleMember -Function Remove-ItemSafely