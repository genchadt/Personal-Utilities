<#
.SYNOPSIS
    ErrorHandling - Chad's custom error handling script.

.DESCRIPTION
    This function captures and logs detailed error information, including the error message, stack trace, script name, line number, and offset within the line. It is designed to be integrated into scripts for improved error handling and debugging.

.PARAMETER ErrorMessage
    The error message to be logged.

.PARAMETER StackTrace
    The stack trace associated with the error.

.PARAMETER ScriptName
    The name of the script where the error occurred. Defaults to the name of the currently running script.

.PARAMETER ScriptLineNumber
    The line number in the script where the error occurred.

.PARAMETER OffsetInLine
    The offset within the line where the error occurred.

.EXAMPLE
    ErrorHandling -ErrorMessage "File not found" -StackTrace $error[0].stacktrace
    Logs an error with the message "File not found" and the current stack trace.

.INPUTS
    String
    Error message and stack trace as strings. Script name, line number, and offset are also input as optional parameters for more detailed error information.

.OUTPUTS
    None
    The function does not return output but logs error details to the console and optionally to a log file through the Write-Log function.

.LINK
    Write-Log: [Your internal documentation or source code link for Write-Log]
    Write-Divider: [Your internal documentation or source code link for Write-Divider]
    Write-Console: [Your internal documentation or source code link for Write-Console]

.NOTES
    Ensure that supporting functions like Write-Log, Write-Divider, and Write-Console are available and sourced before using ErrorHandling function.
    This function is part of a larger framework designed to standardize error handling across PowerShell scripts.

    Author: Chad
    Creation Date: 2023-12-07 03:30:00 GMT
    Last Updated: 2024-02-04 03:30:00 GMT
#>

###############################################
# Imports
###############################################

Import-Module "$PSScriptRoot/../lib/TextHandling.psm1"

###############################################
# Functions
###############################################

function ErrorHandling {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,

        [Parameter(Mandatory = $true)]
        [string]$StackTrace,

        [string]$ScriptName = $MyInvocation.ScriptName,

        [int]$ScriptLineNumber = $MyInvocation.ScriptLineNumber,

        [int]$OffsetInLine = $MyInvocation.OffsetInLine,

        [ValidateSet("Info", "Warning", "Error")]
        [string]$Severity = "Error",

        [switch]$LogToFile
    )

    try {
        Write-Divider -Strong
        Write-Console -Text "Error: $ErrorMessage" -MessageType $Severity
        Write-Console -Text "StackTrace: $StackTrace" -MessageType $Severity
        if ($ScriptName) {
            Write-Console -Text "Exception Source: $ScriptName" -MessageType $Severity
        }
        if ($ScriptLineNumber -ne 0) {
            Write-Console -Text "Exception Line: $ScriptLineNumber" -MessageType $Severity
        }
        if ($OffsetInLine -ne 0) {
            Write-Console -Text "Exception Offset: $OffsetInLine" -MessageType $Severity
        }
        Write-Divider -Strong

        if ($LogToFile) {
            Write-Log -Message "An error occurred: $ErrorMessage" -Severity $Severity
        }
    } catch {
        Write-Console -Text "ErrorHandling function encountered an error: $_" -MessageType Error
    }
}

Export-ModuleMember -Function ErrorHandling