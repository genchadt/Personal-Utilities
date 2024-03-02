<#
.SYNOPSIS
    TextHandling.ps1 - Text handling functions for PowerShell scripts.

.DESCRIPTION
    The script includes functions to read user input, write messages to the console with different importance levels (Info, Warning, Error), create visual dividers, and log messages to a file. It's designed to standardize console interactions and logging within PowerShell scripts.

.FUNCTION Read-Console
    Reads input from the user with a customizable prompt.

    .PARAMETER Text
        The message to display before the prompt.

    .PARAMETER Prompt
        Custom prompt text. If not specified, a default prompt is provided.

    .EXAMPLE
        Read-Console -Text "Proceed?" -Prompt "(Y/N)"
        Displays "Proceed? (Y/N)" and waits for user input.

.FUNCTION Write-Console
    Writes formatted messages to the console with specified importance levels.

    .PARAMETER Text
        The text of the message to display.

    .PARAMETER MessageType
        The type of message (Info, Warning, Error) which determines the text color.

    .PARAMETER NoLog
        If set, the message will not be logged to the file.

    .EXAMPLE
        Write-Console -Text "Operation completed" -MessageType Info
        Writes an informational message to the console.

.FUNCTION Write-Divider
    Creates a visual divider in the console output.

    .PARAMETER Strong
        If set, creates a stronger divider using '=' instead of '-'.

    .PARAMETER Char
        Character to use for the divider. Defaults to '-'.

    .EXAMPLE
        Write-Divider -Strong
        Outputs a strong visual divider.

.FUNCTION Write-Log
    Logs a message to a file in the 'logs' directory relative to the script's location.

    .PARAMETER Message
        The message to log.

    .EXAMPLE
        Write-Log -Message "User selected option 1"
        Adds a timestamped entry to the log file.

.INPUTS
    None

.OUTPUTS
    String
    Messages are output to the console or logged to a file, depending on the function used.

.LINK
    PowerShell documentation for Read-Host: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host
    PowerShell documentation for Write-Host: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/write-host
    PowerShell documentation for About_Functions: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions

.NOTES
    These utilities are designed to be reusable across different PowerShell scripts, providing a consistent approach to console interactions and logging.

    Script Version: 1.0
    Author: Your Name
    Creation Date: YYYY-MM-DD
#>

###############################################
# Functions
###############################################

function Read-Console() {
    param (
        [string]$Text,
        [string]$Prompt
    )

    if ($Prompt) {
        $response = Read-Host -Prompt "$Text $Prompt"
    } 
    else {
        $response = Read-Host -Prompt "$Text (Y)es / (A)ccept All / (N)o / (D)ecline All"
    }

    return $response
}

function Write-Console() {
    param (
        [string]$Text,
        [ValidateSet("Info", "Warning", "Error")]
        [string]$MessageType = "Info",
        [switch]$NoLog
    )

    # Set the color based on the message type
    switch ($MessageType) {
        "Info" { $color = "White" }
        "Warning" { $color = "Yellow" }
        "Error" { $color = "Red" }
        default { $color = "White" }
    }

    # Format the message and write it to the console
    $Text = ">> $Text"
    Write-Host $Text -ForegroundColor $color

    # If logging is enabled, write the message to the log file
    if (!$NoLog) { Write-Log -Message $Text }
}

function Write-Divider {
    param (
        [switch]$Strong,
        [string]$Char = '-'
    )

    if (!$SilentMode) { 
        if($Strong) { $Char = '=' }
        Write-Host ($Char * 15)
    }
}

function Write-Log() {
    param (
        [string]$Message
    )

    $logFileName = "{0}.log" -f ($MyInvocation.MyCommand.Name -replace '\.ps1$', '')
    $logPath = Join-Path -Path $PSScriptRoot -ChildPath "logs\$logFileName"

    if (-not (Test-Path $logPath)) {
        New-Item -ItemType File -Path $logPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"

    Add-Content -Path $logPath -Value $logEntry
}
