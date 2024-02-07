function ErrorHandling() {
    param (
        [string]$errorMessage,
        [string]$stackTraceValue
    )

    Write-Divider
    Write-Console "Error: $errorMessage"
    Write-Console "StackTrace: `n$stackTraceValue"
    Write-Console "Exception Source: $($Error[0].InvocationInfo.ScriptName)"
    Write-Console "Exception Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Console "Exception Offset: $($Error[0].InvocationInfo.OffsetInLine)"
    Write-Divider
    throw "Error executing command"
}