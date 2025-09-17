<#
.SYNOPSIS
    Selects all Ollama models and pulls from their repository.

.DESCRIPTION
    Selects all Ollama models and pulls from their repository, updating them to the latest available version.
    !Requires that Ollama is installed and available in the system PATH!

.PARAMETER ModelName
    The name of the Ollama model to update, with wildcard support (e.g., "gemma*", "mistral:latest").
    By default, this updates all available models.
#>
function Update-Ollama {
    param(
        [string]$ModelName = "*"
    )

    # Get the list of all Ollama models
    try {
        Write-Debug "Retrieving Ollama models..."
        $allModelNames = ollama list | Select-Object -Skip 1 | ForEach-Object {
            ($_.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))[0]
        }
    }
    catch {
        Write-Warning "Failed to retrieve Ollama models. Is Ollama running? Error: $_"
        return
    }

    # Filter the list of model names based on the -ModelName parameter
    $modelsToUpdate = $allModelNames | Where-Object { $_ -like $ModelName }

    if (-not $modelsToUpdate) {
        Write-Host "No models found matching the pattern '$ModelName'."
        return
    }

    foreach ($model in $modelsToUpdate) {
        Write-Host "Updating Ollama model: $model"
        try {
            ollama pull $model
        }
        catch {
            Write-Warning "Failed to update Ollama model $model`: $_"
        }
    }
}

Update-Ollama @PSBoundParameters