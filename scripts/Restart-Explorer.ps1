function Restart-Explorer {
<#
.SYNOPSIS
Restart-Explorer - Stops and restarts the Windows Explorer process.

.DESCRIPTION
Restart the Windows Explorer process, which is necessary after certain system
settings have been changed.
#>
    [CmdletBinding()]
    param ()

    Write-Verbose "Restarting Explorer.exe..."
    Stop-Process -Name explorer -Force

    Start-Sleep -Milliseconds 500

    Start-Process explorer.exe
}

Restart-Explorer @PSBoundParameters
