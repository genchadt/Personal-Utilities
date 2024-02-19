. "$PSScriptRoot\TextHandling.ps1"

function ErrorHandling {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,

        [Parameter(Mandatory = $true)]
        [string]$StackTrace,

        [string]$ScriptName = $MyInvocation.ScriptName,

        [int]$ScriptLineNumber = $MyInvocation.ScriptLineNumber,

        [int]$OffsetInLine = $MyInvocation.OffsetInLine
    )

    Write-Divider -Strong
    Write-Console -Text "Error: $ErrorMessage"
    Write-Console -Text "StackTrace: $StackTrace"
    if ($ScriptName) {
        Write-Console -Text "Exception Source: $ScriptName"
    }
    if ($ScriptLineNumber -ne 0) {
        Write-Console -Text "Exception Line: $ScriptLineNumber"
    }
    if ($OffsetInLine -ne 0) {
        Write-Console -Text "Exception Offset: $OffsetInLine"
    }
    Write-Divider -Strong

    # Optionally, re-throw or handle the error based on script requirements
    # throw "Error executing command: $ErrorMessage"
    # Or log the error without stopping execution
    Write-Log -Message "An error occurred: $ErrorMessage"
}
