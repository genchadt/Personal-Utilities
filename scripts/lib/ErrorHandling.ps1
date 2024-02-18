function Write-Log {
    param (
        [string]$Message,
        [string]$Type = "Info" # Default type is Info. Other types could be Error, Warning, etc.
    )
    switch ($Type) {
        "Error" { Write-Host -ForegroundColor Red "ERROR: $Message" }
        "Warning" { Write-Host -ForegroundColor Yellow "WARNING: $Message" }
        default { Write-Host "INFO: $Message" }
    }
}

function Write-Divider {
    Write-Host "----------------------------------------"
}

function EnhancedErrorHandling {
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

    Write-Divider
    Write-Log -Message "Error: $ErrorMessage" -Type Error
    Write-Log -Message "StackTrace: $StackTrace" -Type Error
    if ($ScriptName) {
        Write-Log -Message "Exception Source: $ScriptName" -Type Error
    }
    if ($ScriptLineNumber -ne 0) {
        Write-Log -Message "Exception Line: $ScriptLineNumber" -Type Error
    }
    if ($OffsetInLine -ne 0) {
        Write-Log -Message "Exception Offset: $OffsetInLine" -Type Error
    }
    Write-Divider

    # Consider using Write-Error for non-terminating errors or throw for terminating errors with specific messages
    $exception = New-Object System.Exception "Error executing command: $ErrorMessage"
    $PSCmdlet.ThrowTerminatingError($exception)
}

# Example usage within a try-catch block
try {
    # Simulate an operation that could fail
    throw "Simulated failure"
} catch {
    EnhancedErrorHandling -ErrorMessage $_.Exception.Message -StackTrace $_.Exception.StackTrace
}
