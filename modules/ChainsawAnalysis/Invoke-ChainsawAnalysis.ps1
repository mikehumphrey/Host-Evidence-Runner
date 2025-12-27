function Invoke-ChainsawAnalysis {
    <#
    .SYNOPSIS
        Runs Chainsaw forensic artifact analysis on collected event logs.

    .DESCRIPTION
        Wraps the Chainsaw executable to perform "hunt" operations using Sigma rules
        against .evtx files in a HER investigation directory.
        Automatically downloads Sigma rules if not found.

    .PARAMETER InvestigationPath
        Path to the investigation folder (containing collected_files).

    .PARAMETER ChainsawPath
        Path to chainsaw.exe. Defaults to C:\Tools\chainsaw\chainsaw.exe.

    .PARAMETER RulesPath
        Path to Sigma rules directory. Defaults to C:\Tools\chainsaw\sigma.

    .EXAMPLE
        Invoke-ChainsawAnalysis -InvestigationPath "investigations\Host\Timestamp"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InvestigationPath,

        [Parameter(Mandatory=$false)]
        [string]$ChainsawPath = "C:\Tools\chainsaw\chainsaw.exe",

        [Parameter(Mandatory=$false)]
        [string]$RulesPath = "C:\Tools\chainsaw\sigma"
    )

    $ErrorActionPreference = "Stop"

    # 1. Validate Paths
    if (-not (Test-Path $ChainsawPath)) {
        Write-Error "Chainsaw executable not found at $ChainsawPath"
        return
    }

    $investigationRoot = Resolve-Path $InvestigationPath
    $evtxPath = Join-Path $investigationRoot "collected_files"
    
    if (-not (Test-Path $evtxPath)) {
        Write-Error "Collected files directory not found at $evtxPath"
        return
    }

    # 2. Check/Download Rules
    if (-not (Test-Path $RulesPath)) {
        Write-Warning "Sigma rules not found at $RulesPath. Attempting to download..."
        try {
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                throw "Git is not installed. Cannot download Sigma rules."
            }
            
            # Create parent dir if needed
            $parent = Split-Path $RulesPath -Parent
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

            Write-Host "Cloning SigmaHQ/sigma to $RulesPath..." -ForegroundColor Cyan
            git clone https://github.com/SigmaHQ/sigma.git $RulesPath
        } catch {
            Write-Error "Failed to download Sigma rules: $_"
            return
        }
    }

    # 3. Prepare Output
    $outputDir = Join-Path $investigationRoot "Phase3_Chainsaw_Analysis"
    if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }
    
    $outputCsv = Join-Path $outputDir "chainsaw_hunt_results.csv"
    $outputTxt = Join-Path $outputDir "chainsaw_hunt_summary.txt"

    # 4. Construct Command
    # Mapping file is usually in chainsaw dir/mappings
    $chainsawDir = Split-Path $ChainsawPath -Parent
    $mappingFile = Join-Path $chainsawDir "mappings\sigma-event-logs-all.yml"

    if (-not (Test-Path $mappingFile)) {
        Write-Warning "Mapping file not found at $mappingFile. Trying to find it..."
        $mappingFile = Get-ChildItem -Path $chainsawDir -Recurse -Filter "sigma-event-logs-all.yml" | Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $mappingFile) {
        Write-Error "Could not find sigma-event-logs-all.yml mapping file."
        return
    }

    Write-Host "Starting Chainsaw Analysis..." -ForegroundColor Cyan
    Write-Host "  Target: $evtxPath"
    Write-Host "  Rules: $RulesPath"
    Write-Host "  Output: $outputCsv"

    # Chainsaw command structure:
    # chainsaw hunt <EVTX_PATH> -s <SIGMA_PATH> --mapping <MAPPING_FILE> --csv --output <OUTPUT_DIR>
    
    $args = @(
        "hunt",
        $evtxPath,
        "-s", $RulesPath,
        "--mapping", $mappingFile,
        "--csv",
        "--output", $outputDir
    )

    try {
        & $ChainsawPath $args 2>&1 | Tee-Object -FilePath $outputTxt
        
        # Rename default output if needed
        $defaultOutput = Join-Path $outputDir "sigma.csv"
        if (Test-Path $defaultOutput) {
            Move-Item $defaultOutput $outputCsv -Force
        }

        Write-Host "Chainsaw analysis complete." -ForegroundColor Green
    } catch {
        Write-Error "Chainsaw execution failed: $_"
    }
}

