<#
.SYNOPSIS
    Send-ReforgerInput - Sends the "Enter" key to the Arma Reforger window to try and join games.

.DESCRIPTION
    This script sends the "Enter" key to the game window to trigger the reforger input. Please BI build a queuing system so I can stop using this.

.EXAMPLE
    .\Invoke-ReforgerInput.ps1
#>
function Send-ReforgerInput {
    <# .SYNOPSIS
        Send-ReforgerInput - Sends the "Enter" key to the Arma Reforger window to try and join games.

    .DESCRIPTION
        This script sends the "Enter" key to the game window to trigger the reforger input. Please BI build a queuing system so I can stop using this.

    .EXAMPLE
        Send-ReforgerInput
    #>

    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class WinAPI {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        public const uint WM_KEYDOWN = 0x0100;
        public const uint WM_KEYUP = 0x0101;
        public const int VK_RETURN = 0x0D;
    }
"@

    # Replace with your process image name (e.g., "notepad.exe" or "yourapp.exe")
    $processName = "ArmaReforgerSteam.exe"

    # Get the process
    $process = Get-Process | Where-Object { $_.ProcessName -eq $processName.Split('.')[0] }

    if ($null -eq $process) {
        Write-Output "Process not found."
        return
    }

    # Get the main window handle of the process
    $hWnd = $process.MainWindowHandle

    if ($hWnd -eq [IntPtr]::Zero) {
        Write-Output "No main window found for process: $processName"
        return
    }

    # Check if the window is visible (optional check)
    if (-not [WinAPI]::IsWindowVisible($hWnd)) {
        Write-Output "Window is not visible."
        return
    }

    # Send "Enter" key directly to the window handle without bringing it to the foreground
    Write-Host "Sending 'Enter' key..."
    while ($true) {
        # Send "Enter" key down message
        [void][WinAPI]::PostMessage($hWnd, [WinAPI]::WM_KEYDOWN, [IntPtr][WinAPI]::VK_RETURN, [IntPtr]::Zero)
        # Send "Enter" key up message
        [void][WinAPI]::PostMessage($hWnd, [WinAPI]::WM_KEYUP, [IntPtr][WinAPI]::VK_RETURN, [IntPtr]::Zero)
        
        # Wait before sending the next "Enter" press
        Start-Sleep -Milliseconds 300
    }
}

Send-ReforgerInput