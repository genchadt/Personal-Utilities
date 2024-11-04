<#
.SYNOPSIS
Restart the Windows Explorer process.

.DESCRIPTION
Restart the Windows Explorer process, which is necessary after certain system
settings have been changed.
#>
function Restart-Explorer {
    # Restart the Windows Explorer process.
    Write-Host "Restarting Explorer.exe..."
    Stop-Process -Name explorer -Force
    # Give the process some time to shut down.
    Start-Sleep -Milliseconds 500
    # Start the Explorer process again.
    Start-Process explorer.exe
}

Restart-Explorer
