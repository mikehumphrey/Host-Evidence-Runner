function Invoke-AIAnalysis {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InvestigationPath
    )

    $scriptDir = Resolve-Path "modules\AIAnalysis"
    $pythonScript = Join-Path $scriptDir "anomaly_detection.py"
    
    $investigationRoot = Resolve-Path $InvestigationPath
    $chainsawCsv = Join-Path $investigationRoot "Phase3_Chainsaw_Analysis\chainsaw_hunt_results.csv"
    $outputFile = Join-Path $investigationRoot "Phase3_Chainsaw_Analysis\AI_Summary.txt"

    if (-not (Test-Path $chainsawCsv)) {
        Write-Error "Chainsaw CSV not found at $chainsawCsv. Run Invoke-ChainsawAnalysis first."
        return
    }

    Write-Host "Running AI Analysis on Chainsaw results..." -ForegroundColor Cyan
    python $pythonScript $chainsawCsv $outputFile
}
