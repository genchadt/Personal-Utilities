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
                $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
                $item = Get-Item -LiteralPath $resolvedPath.Path -ErrorAction Stop

                $shell = New-Object -ComObject "Shell.Application"
                $recycleBin = $shell.Namespace(0xA) # 0xA is the recycle bin's shell ID
                $folder = $shell.Namespace($item.Directory.FullName)
                $file = $folder.ParseName($item.Name)

                if ($null -ne $file) {
                    $file.InvokeVerb("delete")
                    Write-Output "Moved to Recycle Bin: $Path"
                } else {
                    Write-Error "Failed to locate item for Recycle Bin operation: $Path"
                }
            } catch {
                Write-Error "Error moving item to Recycle Bin: $_.Exception.Message"
            }
        }
    }
}

Export-ModuleMember -Function Get-CurrentDirectorySize
Export-ModuleMember -Function Invoke-Command
Export-ModuleMember -Function Remove-ItemSafely