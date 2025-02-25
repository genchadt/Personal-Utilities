[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Position=0)]
    [string]$Path = (Get-Location)
)

# Check for chdman availability
if (-not (Get-Command chdman -ErrorAction SilentlyContinue)) {
    Write-Error "chdman not found in PATH. Please ensure chdman is installed and available."
    exit 1
}

# Collect CHD files recursively
$chdFiles = Get-ChildItem -Path $Path -Filter *.chd -Recurse -File

if ($chdFiles.Count -eq 0) {
    Write-Host "No CHD files found in specified path: $Path"
    exit
}

# Display files to process
Write-Host "Found $($chdFiles.Count) CHD files to process:`n"
$chdFiles | ForEach-Object { Write-Host "- $($_.FullName)" }

# Confirm operation
if (-not $PSCmdlet.ShouldProcess("All listed CHD files", "Convert")) {
    Write-Host "`nOperation cancelled by user."
    exit
}

# Process each file
foreach ($chd in $chdFiles) {
    Write-Host "`nProcessing: $($chd.FullName)"

    $targetDir = $chd.DirectoryName
    $baseName = $chd.BaseName
    $cuePath = Join-Path $targetDir "$baseName.cue"  #  *Possible* cue path
    $tempChdPath = Join-Path $targetDir "$baseName.temp.chd"

    # Step 1: Extract CD
    try {
        Write-Host "Extracting to CUE/BIN..."
        $extractArgs = @("extractcd", "-i", $chd.FullName, "-o", $cuePath) # Output to the *cue* name, even if it's not a cue.
        & chdman $extractArgs

        if ($LASTEXITCODE -ne 0) {
            throw "Extraction failed (exit code $LASTEXITCODE)"
        }

        # --- Find the *actual* extracted input file ---
        $extractedFiles = Get-ChildItem -Path $targetDir -File | Where-Object {$_.BaseName -eq $baseName -and $_.Extension -ne ".chd"}
        if ($extractedFiles.Count -eq 0) {
            throw "No extracted files (CUE/BIN/ISO) found after extraction."
        }
        # Prioritize .cue, then .bin, then .iso
        $inputFile = $extractedFiles | Where-Object {$_.Extension -eq ".cue"} | Select-Object -First 1
        if (-not $inputFile) {
            $inputFile = $extractedFiles | Where-Object {$_.Extension -eq ".bin"} | Select-Object -First 1
        }
        if (-not $inputFile) {
            $inputFile = $extractedFiles | Where-Object {$_.Extension -eq ".iso"} | Select-Object -First 1
        }
        if(-not $inputFile) {
            throw "Could not determine input file type after extraction."
        }

        Write-Host "Using input file: $($inputFile.FullName)"


    }
    catch {
        Write-Error "Error extracting $($chd.Name): $_"
        continue  # Skip to the next CHD file
    }

    # Step 2: Create DVD CHD
    try {
        Write-Host "Creating new DVD CHD..."
        $createArgs = @(
            "createdvd",
            "--input", $inputFile.FullName,  # Use the *found* input file
            "--output", $tempChdPath,
            "--hunksize", "2048",  # Correct hunksize option
            "--compression", "zlib|flac",  # Correct compression option and format.  PSP uses 2048 sector size.
            "--force"  # Force overwrite of temp file
        )
        & chdman $createArgs

        if ($LASTEXITCODE -ne 0) {
            throw "CHD creation failed (exit code $LASTEXITCODE)"
        }
    }
    catch {
        Write-Error "Error creating CHD for $($chd.Name): $_"
        if (Test-Path $tempChdPath) { Remove-Item $tempChdPath -Force } # -Force to avoid prompts
        continue
    }

    # Step 3: Replace original CHD
    try {
        Write-Host "Replacing original file..."
        Remove-Item -Path $chd.FullName -Force -ErrorAction Stop # -Force to avoid prompts
        Rename-Item -Path $tempChdPath -NewName $chd.Name -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Error replacing original CHD: $_"
        continue
    }

    # Step 4: Cleanup extracted files
     try {
        Write-Host "Removing extracted files..."
        $extractedFiles | Remove-Item -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Error removing extracted files: $_"
    }


    Write-Host "Successfully processed $($chd.Name)"
}

Write-Host "`nProcessing complete. Original CHD files have been replaced."
