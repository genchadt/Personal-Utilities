try {
    & "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe" /update user
}
catch {
    Write-Warning "Failed to start Office update process: $_"
}