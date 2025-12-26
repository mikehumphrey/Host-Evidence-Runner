#Requires -Version 5.1
<#
.SYNOPSIS
    Generic Chainsaw hunt script template for forensic investigations
.DESCRIPTION
    Runs Chainsaw forensic analysis tool against collected event logs using custom Sigma rules.
    This is a template - customize the parameters and search terms for your specific investigation.
.PARAMETER ProjectRoot
    Root directory of HER project (default: auto-detect)
.PARAMETER InvestigationPath
    Path to the collected_files directory containing event logs
.PARAMETER Mode
    Chainsaw operation mode: hunt (Sigma rules), search (keywords), or analyse (timeline)
.PARAMETER FromDate
    Start date for analysis (format: YYYY-MM-DDTHH:MM:SS)
.PARAMETER ToDate
    End date for analysis (format: YYYY-MM-DDTHH:MM:SS)
.EXAMPLE
    .\Run-Chainsaw-Hunt.ps1 -InvestigationPath "C:\Temp\Investigations\HOST\20251218_120000" -Mode hunt
.EXAMPLE
    .\Run-Chainsaw-Hunt.ps1 -InvestigationPath "C:\Temp\Investigations\HOST\20251218_120000" -Mode search
.NOTES
    TEMPLATE - Customize for your investigation:
    1. Set InvestigationPath to your collected event logs
    2. Update FromDate/ToDate to investigation timeframe
    3. Customize search terms in 'search' mode section (lines ~180-195)
    4. Create custom Sigma rules in sigma-rules/ directory
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectRoot,
    
    [Parameter(Mandatory=$true)]
    [string]$InvestigationPath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('hunt', 'search', 'analyse')]
    [string]$Mode = 'hunt',
    
    [Parameter(Mandatory=$false)]
    [string]$FromDate = "2024-01-01T00:00:00",
    
    [Parameter(Mandatory=$false)]
    [string]$ToDate = "2025-12-31T23:59:59"
)

$ErrorActionPreference = 'Stop'

# Auto-detect project root if not provided
if (-not $ProjectRoot) {
    # Script is in templates/ or investigation folder, project root is parent or grandparent
    $scriptLocation = $PSScriptRoot
    if ($scriptLocation -like "*\templates") {
        $ProjectRoot = Split-Path $scriptLocation -Parent
    } elseif ($scriptLocation -like "*\investigations\*") {
        # In investigation folder, go up to root
        $ProjectRoot = Split-Path (Split-Path (Split-Path $scriptLocation -Parent) -Parent) -Parent
    } else {
        Write-Error "Cannot auto-detect project root. Please specify -ProjectRoot parameter."
        exit 1
    }
}

Write-Host "`n============================================================================" -ForegroundColor Cyan
Write-Host "Chainsaw Forensic Hunt - Generic Template" -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan

# ============================================================================
# VALIDATION
# ============================================================================

# Check Chainsaw executable
$chainsawPath = Join-Path $ProjectRoot "tools\optional\chainsaw\chainsaw.exe"
if (-not (Test-Path $chainsawPath)) {
    Write-Error "Chainsaw not found at: $chainsawPath"
    Write-Host "`nDownload from: https://github.com/WithSecureLabs/chainsaw/releases" -ForegroundColor Yellow
    Write-Host "Extract to: tools\optional\chainsaw\" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Chainsaw found: $chainsawPath" -ForegroundColor Green

# Check event log directory
$eventLogPath = Join-Path $InvestigationPath "collected_files"
if (-not (Test-Path $eventLogPath)) {
    Write-Error "Event log directory not found: $eventLogPath"
    Write-Host "Expected structure: <InvestigationPath>\collected_files\*.evtx" -ForegroundColor Yellow
    exit 1
}

$evtxCount = (Get-ChildItem -Path $eventLogPath -Filter "*.evtx" -ErrorAction SilentlyContinue | Measure-Object).Count
if ($evtxCount -eq 0) {
    Write-Warning "No .evtx files found in $eventLogPath"
}

Write-Host "✓ Event logs found: $eventLogPath ($evtxCount .evtx files)" -ForegroundColor Green

# Get script directory for rules
$scriptDir = $PSScriptRoot
$sigmaRulesDir = Join-Path $scriptDir "sigma-rules"

# Check for Sigma rules directory (required for hunt mode)
if ($Mode -eq 'hunt') {
    if (-not (Test-Path $sigmaRulesDir)) {
        Write-Warning "Sigma rules directory not found: $sigmaRulesDir"
        Write-Host "`nFor hunt mode, create a 'sigma-rules' directory and add custom .yml rules" -ForegroundColor Yellow
        Write-Host "Example rules available in: investigations\<case>\sigma-rules\" -ForegroundColor Yellow
        Write-Host "`nContinuing without custom rules (will use Chainsaw defaults if -s flag omitted)...`n" -ForegroundColor Yellow
        $sigmaRulesDir = $null
    } else {
        $ruleCount = (Get-ChildItem -Path $sigmaRulesDir -Filter "*.yml" -ErrorAction SilentlyContinue | Measure-Object).Count
        Write-Host "✓ Sigma rules directory: $sigmaRulesDir ($ruleCount rules)" -ForegroundColor Green
    }
}

# Create output directory
$outputDir = Join-Path $scriptDir "Chainsaw_Results"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "✓ Output directory: $outputDir`n" -ForegroundColor Green

# ============================================================================
# CONFIGURATION
# ============================================================================

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Mode: $Mode" -ForegroundColor White
Write-Host "  Date Range: $FromDate to $ToDate" -ForegroundColor White
Write-Host "  Event Logs: $eventLogPath" -ForegroundColor White
Write-Host "  Output: $outputDir`n" -ForegroundColor White

# ============================================================================
# HUNT EXECUTION
# ============================================================================

switch ($Mode) {
    'hunt' {
        Write-Host "Running Chainsaw HUNT mode..." -ForegroundColor Yellow
        Write-Host "Using Sigma rules for threat detection`n" -ForegroundColor Yellow
        
        $outputFile = Join-Path $outputDir "chainsaw_hunt_${timestamp}.csv"
        
        # Get Chainsaw's built-in mapping file for Sigma rules
        $chainsawDir = Split-Path $chainsawPath -Parent
        $mappingFile = Join-Path $chainsawDir "mappings\sigma-event-logs-all.yml"
        
        if (-not (Test-Path $mappingFile)) {
            Write-Warning "Chainsaw mapping file not found: $mappingFile"
            Write-Host "This file should be included with Chainsaw distribution" -ForegroundColor Yellow
            $mappingFile = $null
        }
        
        # Build Chainsaw arguments
        # CRITICAL: Use -s flag for sigma directory (not --rule)
        $chainsawArgs = @(
            'hunt',
            $eventLogPath,
            '--skip-errors',
            '--load-unknown',
            '--from', $FromDate,
            '--to', $ToDate,
            '--output', $outputFile
        )
        
        # Add custom Sigma rules if directory exists
        if ($sigmaRulesDir) {
            $chainsawArgs += '-s'
            $chainsawArgs += $sigmaRulesDir
        }
        
        # Add mapping file if exists
        if ($mappingFile) {
            $chainsawArgs += '--mapping'
            $chainsawArgs += $mappingFile
        }
        
        Write-Host "Command: $chainsawPath $($chainsawArgs -join ' ')`n" -ForegroundColor Gray
        
        & $chainsawPath @chainsawArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✓ Hunt complete! Results saved to:" -ForegroundColor Green
            Write-Host "  $outputFile`n" -ForegroundColor White
            
            # Quick statistics
            if (Test-Path $outputFile) {
                $results = Import-Csv $outputFile -ErrorAction SilentlyContinue
                if ($results) {
                    $lineCount = ($results | Measure-Object).Count
                    Write-Host "Total detections: $lineCount`n" -ForegroundColor Cyan
                    
                    if ($lineCount -gt 0) {
                        Write-Host "Top 5 detection rules:" -ForegroundColor Cyan
                        $results | 
                            Group-Object -Property 'name' | 
                            Sort-Object Count -Descending | 
                            Select-Object -First 5 | 
                            Format-Table @{Label="Rule Name"; Expression={$_.Name}}, @{Label="Detections"; Expression={$_.Count}} -AutoSize
                    }
                } else {
                    Write-Host "No detections found (or output format changed)`n" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Error "Chainsaw hunt failed with exit code: $LASTEXITCODE"
        }
    }
    
    'search' {
        Write-Host "Running Chainsaw SEARCH mode..." -ForegroundColor Yellow
        Write-Host "Searching for investigation-specific indicators`n" -ForegroundColor Yellow
        
        # ========================================================================
        # CUSTOMIZE THESE SEARCH TERMS FOR YOUR INVESTIGATION
        # ========================================================================
        # Examples:
        # - Usernames: 'suspect.user', 'DOMAIN\username'
        # - Domains: 'dropbox.com', 'drive.google.com', 'mega.nz'
        # - Processes: 'chrome.exe', 'tor.exe', '7z.exe'
        # - File names: 'confidential', 'budget', 'passwords'
        # - IP addresses: '192.168.1.100', '10.0.0.5'
        # ========================================================================
        
        $searchTerms = @(
            # Add your investigation-specific search terms here
            # Example: 'suspect.username',
            # Example: 'malicious.domain.com',
            # Example: 'suspicious.exe'
        )
        
        if ($searchTerms.Count -eq 0) {
            Write-Warning "No search terms defined in script."
            Write-Host "`nTo use search mode, edit this script and add search terms in the `$searchTerms array (line ~185)" -ForegroundColor Yellow
            Write-Host "Example search terms: usernames, domains, processes, file names, IPs`n" -ForegroundColor Yellow
            exit 1
        }
        
        foreach ($term in $searchTerms) {
            $safeTermName = $term -replace '[\\/:*?"<>|]', '_'
            $outputFile = Join-Path $outputDir "chainsaw_search_${safeTermName}_${timestamp}.csv"
            
            Write-Host "Searching for: $term" -ForegroundColor Cyan
            
            $chainsawArgs = @(
                'search',
                $term,
                $eventLogPath,
                '--from', $FromDate,
                '--to', $ToDate,
                '--skip-errors',
                '--load-unknown',
                '--output', $outputFile
            )
            
            try {
                & $chainsawPath @chainsawArgs 2>&1 | Out-Null
                
                if (Test-Path $outputFile) {
                    $results = Import-Csv $outputFile -ErrorAction SilentlyContinue
                    if ($results) {
                        $lineCount = ($results | Measure-Object).Count
                        Write-Host "  Found: $lineCount events" -ForegroundColor $(if ($lineCount -gt 0) { 'Green' } else { 'Yellow' })
                    } else {
                        Write-Host "  Found: 0 events" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  Found: 0 events" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  Search failed: $_" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        Write-Host "`n✓ Search complete! Results in: $outputDir`n" -ForegroundColor Green
    }
    
    'analyse' {
        Write-Host "Running Chainsaw ANALYSE mode..." -ForegroundColor Yellow
        Write-Host "Performing timeline analysis`n" -ForegroundColor Yellow
        
        $outputFile = Join-Path $outputDir "chainsaw_analyse_${timestamp}.csv"
        
        $chainsawArgs = @(
            'analyse',
            $eventLogPath,
            '--skip-errors',
            '--load-unknown',
            '--from', $FromDate,
            '--to', $ToDate,
            '--output', $outputFile
        )
        
        Write-Host "Command: $chainsawPath $($chainsawArgs -join ' ')`n" -ForegroundColor Gray
        
        & $chainsawPath @chainsawArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✓ Analysis complete! Timeline saved to:" -ForegroundColor Green
            Write-Host "  $outputFile`n" -ForegroundColor White
            
            if (Test-Path $outputFile) {
                $results = Import-Csv $outputFile -ErrorAction SilentlyContinue
                if ($results) {
                    $eventCount = ($results | Measure-Object).Count
                    Write-Host "Timeline events: $eventCount" -ForegroundColor Cyan
                    
                    # Show distribution by event source
                    Write-Host "`nTop event sources:" -ForegroundColor Cyan
                    $results | 
                        Group-Object -Property 'Channel' | 
                        Sort-Object Count -Descending | 
                        Select-Object -First 5 | 
                        Format-Table @{Label="Channel"; Expression={$_.Name}}, @{Label="Events"; Expression={$_.Count}} -AutoSize
                }
            }
        } else {
            Write-Error "Chainsaw analysis failed with exit code: $LASTEXITCODE"
        }
    }
}

# ============================================================================
# POST-PROCESSING RECOMMENDATIONS
# ============================================================================

Write-Host "`n============================================================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan

Write-Host "1. Review Chainsaw results in: $outputDir" -ForegroundColor Yellow
Write-Host "2. Focus on high/critical severity detections first" -ForegroundColor Yellow
Write-Host "3. Cross-reference with MFT analysis for file access timeline" -ForegroundColor Yellow
Write-Host "4. Correlate browser activity with file access timestamps" -ForegroundColor Yellow
Write-Host "5. Check for temporal patterns (after-hours, weekends)" -ForegroundColor Yellow

Write-Host "`nTo run different modes:" -ForegroundColor Cyan
Write-Host "  Hunt mode:    .\Run-Chainsaw-Hunt.ps1 -InvestigationPath '<path>' -Mode hunt" -ForegroundColor White
Write-Host "  Search mode:  .\Run-Chainsaw-Hunt.ps1 -InvestigationPath '<path>' -Mode search" -ForegroundColor White
Write-Host "  Analyse mode: .\Run-Chainsaw-Hunt.ps1 -InvestigationPath '<path>' -Mode analyse`n" -ForegroundColor White

Write-Host "Customize this script for your investigation:" -ForegroundColor Cyan
Write-Host "  - Update search terms in 'search' mode section (lines ~185-195)" -ForegroundColor White
Write-Host "  - Create custom Sigma rules in sigma-rules/ directory" -ForegroundColor White
Write-Host "  - Adjust date ranges with -FromDate and -ToDate parameters`n" -ForegroundColor White

Write-Host "============================================================================`n" -ForegroundColor Cyan
