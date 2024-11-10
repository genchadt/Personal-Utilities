function Send-ReforgerInput {
    <# .SYNOPSIS
        Send-ReforgerInput - Sends the "Enter" key to the Arma Reforger window to try and join games.

    .DESCRIPTION
        This script sends the "Enter" key to the game window to trigger the reforger input. Please BI build a queuing system so I can stop using this.

    .EXAMPLE
        Send-ReforgerInput
    #>
    [CmdletBinding()]
    param ()

    # Define the WinAPI class and setup constants for low-level keyboard input manipulation later
    Add-Type `
@'
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
'@

    # Get the process and window handle so we can send keys to it
    $imageName = "ArmaReforgerSteam.exe"
    $targetProcess = Get-Process | Where-Object { $_.ProcessName -eq $imageName.Split('.')[0] }
    if ($null -eq $targetProcess) { return }
    Write-Verbose "Found process: $($targetProcess.Name)"
    $hWnd = $targetProcess.MainWindowHandle
    if ([IntPtr]::Zero -eq $hWnd) { return }
    Write-Verbose "Found window: $($hWnd)"

    Write-Verbose "Sending Enter key to window..."
    try {
        while ($true) {
            # Low-level keyboard input
            [void][WinAPI]::PostMessage($hWnd, [WinAPI]::WM_KEYDOWN, [IntPtr][WinAPI]::VK_RETURN, [IntPtr]::Zero)
            [void][WinAPI]::PostMessage($hWnd, [WinAPI]::WM_KEYUP, [IntPtr][WinAPI]::VK_RETURN, [IntPtr]::Zero)
            Start-Sleep -Milliseconds 300
        }
    }
    catch {
        # If the user cancels, exit gracefully
        # I.e. user presses Ctrl + C
        if ($_.Exception.GetType().Name -eq "OperationCanceledException") {
            Write-Verbose "Operation cancelled."
            return
        }
        else {
            # Otherwise, exit with an error
            Write-Error "An error occurred: $($Error[0].Message)"
            return
        }
    }
}

Send-ReforgerInput @PSBoundParameters