<#
.SYNOPSIS
    Advanced Forensic Analysis Wrapper for Lab Environment.

.DESCRIPTION
    Orchestrates the full analysis pipeline:
    1. Standard HER Analysis (Analyze-Investigation.ps1)
    2. Chainsaw Fast Event Log Analysis (Invoke-ChainsawAnalysis)
    3. AI/Anomaly Detection (Invoke-AIAnalysis)

.PARAMETER InvestigationPath
    Path to the investigation folder.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$InvestigationPath,

    [Parameter(Mandatory=$false)]
    [switch]$RunPlaso,

    [Parameter(Mandatory=$false)]
    [switch]$PlasoOnly
)

$ErrorActionPreference = "Continue"
$root = $PSScriptRoot

# 1. Import Modules
Write-Host "=== Phase 1: Initialization ===" -ForegroundColor Cyan
# Handle dot-sourcing vs script execution for root path
if (-not $root) { $root = Get-Location }

$chainsawModule = Join-Path $root "modules\ChainsawAnalysis\Invoke-ChainsawAnalysis.ps1"
$aiModule = Join-Path $root "modules\AIAnalysis\Invoke-AIAnalysis.ps1"

if (Test-Path $chainsawModule) {
    . $chainsawModule
} else {
    Write-Error "Chainsaw module not found at $chainsawModule"
}

if (Test-Path $aiModule) {
    . $aiModule
} else {
    Write-Error "AI module not found at $aiModule"
}

# 2. Run Standard Analysis (Optional, but good for MFT/Registry)
# Write-Host "=== Phase 2: Standard HER Analysis ===" -ForegroundColor Cyan
# & (Join-Path $root "source\Analyze-Investigation.ps1") -InvestigationPath $InvestigationPath -ParseMFT -ParseRegistry

# 3. Run Chainsaw (skipped if -PlasoOnly)
if (-not $PlasoOnly) {
    Write-Host "=== Phase 3: Chainsaw Event Log Analysis ===" -ForegroundColor Cyan
    Invoke-ChainsawAnalysis -InvestigationPath $InvestigationPath

    # 4. Run AI Analysis
    Write-Host "=== Phase 4: AI Anomaly Detection ===" -ForegroundColor Cyan
    Invoke-AIAnalysis -InvestigationPath $InvestigationPath
} else {
    Write-Host "=== Skipping Chainsaw/AI (PlasoOnly) ===" -ForegroundColor Yellow
}

# 5. Run Plaso (Optional)
if ($RunPlaso) {
    Write-Host "=== Phase 5: Plaso Timeline Generation ===" -ForegroundColor Cyan
    $collectedDir = Join-Path $InvestigationPath "collected_files"
    if (-not (Test-Path $collectedDir)) {
        Write-Warning "collected_files not found at $collectedDir. Skipping Plaso."
    } elseif (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Warning "docker not found. Skipping Plaso timeline."
    } else {
        Write-Host "Running log2timeline via docker (this may take a while)..."
        try {
            $resolvedInvestigation = (Resolve-Path $InvestigationPath).Path
            $dockerStorage = "/data/timeline.plaso"
            $dockerSource = "/data/collected_files"
            docker run --rm -v "${resolvedInvestigation}:/data" log2timeline/plaso:latest log2timeline --storage_file $dockerStorage $dockerSource
            Write-Host "Plaso timeline generated at $(Join-Path $InvestigationPath 'timeline.plaso')" -ForegroundColor Green
        } catch {
            Write-Error "Plaso execution failed: $_"
        }
    }
}

Write-Host "=== Analysis Complete ===" -ForegroundColor Green
Write-Host "Results in: $InvestigationPath"
