try {
    Invoke-RestMethod https://get.activated.win | Invoke-Expression
} catch {
    Write-Warning "Invoke-MAS: Failed to invoke MAS: $_"
}