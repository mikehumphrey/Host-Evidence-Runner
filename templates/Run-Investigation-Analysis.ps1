<#
.SYNOPSIS
    Investigation Analysis Script Template - Copy to investigation folder and customize
.DESCRIPTION
    This template script orchestrates the complete analysis workflow for a forensic investigation.
    Copy this file to your investigation folder (e.g., investigations/Case123/HOSTNAME/TIMESTAMP/)
    and update the variables below before running.
    
    The script runs analysis phases in optimal order with parallel execution where safe:
    - Phase 1: Parse all artifacts (parallel: EventLogs, MFT, Prefetch, Registry)
    - Phase 2: Search operations (sequential: requires Phase 1 completion)
    - Phase 3: Additional analysis (parallel: Browser, Network, AD)
    - Phase 4: Timeline reconstruction and reporting
.NOTES
    - Copy this file to investigation folder before running
    - File will be ignored by git (investigations/ is in .gitignore)
    - Update variables in CONFIGURATION section before running
    - Review SEARCH TERMS section and customize for your case
#>

#Requires -Version 5.1

# ============================================================================
# CONFIGURATION - UPDATE THESE VARIABLES FOR YOUR INVESTIGATION
# ============================================================================

# Investigation Details
$InvestigationPath = "C:\Temp\Investigations\MOA-SD-PSDC01\20251217_162931"  # Full path to collection folder
$InvestigationName = "Insider_Threat_GoogleDrive_Exfil"  # Short name for this investigation
$AnalystName = "Michael Humphrey"  # Analyst conducting analysis

# Path to Analyze-Investigation.ps1 script (relative from this folder)
# Adjust based on where you copied this template
$AnalyzeScript = "..\..\..\..\source\Analyze-Investigation.ps1"

# Analysis Options - Set to $true to enable
$EnableFullAnalysis = $false  # If true, runs all modules (overrides individual settings)
$EnableParallelExecution = $true  # Run independent operations in parallel

# Phase 1: Parsing Operations (can run in parallel)
$ParseEventLogs = $true
$ParseMFT = $true
$ParsePrefetch = $true
$ParseRegistry = $true

# Phase 2: Search Operations (requires Phase 1 completion)
$SearchEventLogs = $true
$SearchMFT = $true

# Phase 3: Additional Analysis (can run in parallel with Phase 1)
$AnalyzeBrowserHistory = $true
$AnalyzeNetworkArtifacts = $true
$AnalyzeActiveDirectory = $false  # Only if DC artifacts collected

# Phase 4: Advanced Operations
$RunYaraScan = $false  # Set to $true if you have sensitive file list
$YaraInputFile = ".\sensitive_files.csv"  # Path to CSV with FileName,SHA256Hash columns

# Phase 5: Reporting
$GenerateReports = $true

# ============================================================================
# SEARCH TERMS - CUSTOMIZE FOR YOUR INVESTIGATION
# ============================================================================

# Event Log Search Keywords (customize for your case)
$EventLogKeywords = @(
    # Google Drive indicators
    "drive.google.com",
    "googleapis.com",
    "GoogleDriveSync.exe",
    
    # Browser executables
    "chrome.exe",
    "msedge.exe",
    "firefox.exe",
    
    # File access patterns
    "Confidential",
    "Restricted",
    "Sensitive",
    
    # Add suspect username if known
    # "suspect.username",
    
    # Add sensitive file names if known
    # "Budget_2024.xlsx",
    # "Personnel_Records.docx"
)

# Event IDs to filter (customize based on investigation focus)
$EventIDsToFilter = @(
    4663,  # Object access (file access)
    4656,  # Handle to object
    4624,  # Account logon
    4625,  # Failed logon
    4688,  # Process creation
    4689,  # Process termination
    7045   # Service installation
)

# MFT Search Paths (customize for your case)
$MFTSearchPaths = @(
    "Google Drive",
    "AppData\Local\Google\Drive",
    "Downloads",
    "Documents\Confidential",
    "Documents\Restricted",
    "Temp"
)

# Alternatively, load keywords/paths from files (uncomment to use)
# $EventLogKeywordsFile = ".\search_keywords.txt"
# $MFTSearchPathsFile = ".\search_paths.txt"

# ============================================================================
# SCRIPT EXECUTION - DO NOT MODIFY BELOW THIS LINE
# ============================================================================

$ErrorActionPreference = 'Continue'

# Validate configuration
if (-not (Test-Path $InvestigationPath)) {
    Write-Error "Investigation path not found: $InvestigationPath"
    exit 1
}

if (-not (Test-Path $AnalyzeScript)) {
    Write-Error "Analyze-Investigation.ps1 script not found at: $AnalyzeScript"
    Write-Host "Expected location: $AnalyzeScript" -ForegroundColor Yellow
    Write-Host "Current directory: $PWD" -ForegroundColor Yellow
    exit 1
}

# Create analysis log
$AnalysisLogPath = Join-Path $InvestigationPath "Analysis_Execution_Log.txt"
$StartTime = Get-Date

function Write-AnalysisLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Add-Content -Path $AnalysisLogPath -Value $logEntry
    Write-Host $logEntry -ForegroundColor Cyan
}

# Header
Write-Host "`n============================================================================" -ForegroundColor Cyan
Write-Host "Investigation Analysis Execution" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Investigation: $InvestigationName" -ForegroundColor White
Write-Host "Path: $InvestigationPath" -ForegroundColor White
Write-Host "Analyst: $AnalystName" -ForegroundColor White
Write-Host "Start Time: $StartTime" -ForegroundColor White
Write-Host "Parallel Execution: $EnableParallelExecution" -ForegroundColor White
Write-Host "============================================================================`n" -ForegroundColor Cyan

Write-AnalysisLog "=== Investigation Analysis Started ==="
Write-AnalysisLog "Investigation: $InvestigationName"
Write-AnalysisLog "Analyst: $AnalystName"
Write-AnalysisLog "Path: $InvestigationPath"

# ============================================================================
# PHASE 1: PARSE ARTIFACTS (Parallel Execution)
# ============================================================================

Write-Host "`n[PHASE 1] Parsing Collected Artifacts" -ForegroundColor Yellow
Write-Host "These operations create CSV files from binary formats and can run in parallel.`n" -ForegroundColor Gray

$Phase1Jobs = @()

if ($ParseEventLogs) {
    Write-AnalysisLog "Starting: Parse Event Logs"
    if ($EnableParallelExecution) {
        $Phase1Jobs += Start-Job -ScriptBlock {
            param($Script, $Path)
            & $Script -InvestigationPath $Path -ParseEventLogs -EventLogFormat csv
        } -ArgumentList $AnalyzeScript, $InvestigationPath -Name "ParseEventLogs"
        Write-Host "  ⚡ Started (parallel): Parse Event Logs" -ForegroundColor Green
    } else {
        & $AnalyzeScript -InvestigationPath $InvestigationPath -ParseEventLogs -EventLogFormat csv
        Write-AnalysisLog "Completed: Parse Event Logs"
    }
}

if ($ParseMFT) {
    Write-AnalysisLog "Starting: Parse MFT"
    if ($EnableParallelExecution) {
        $Phase1Jobs += Start-Job -ScriptBlock {
            param($Script, $Path)
            & $Script -InvestigationPath $Path -ParseMFT
        } -ArgumentList $AnalyzeScript, $InvestigationPath -Name "ParseMFT"
        Write-Host "  ⚡ Started (parallel): Parse MFT" -ForegroundColor Green
    } else {
        & $AnalyzeScript -InvestigationPath $InvestigationPath -ParseMFT
        Write-AnalysisLog "Completed: Parse MFT"
    }
}

if ($ParsePrefetch) {
    Write-AnalysisLog "Starting: Parse Prefetch"
    if ($EnableParallelExecution) {
        $Phase1Jobs += Start-Job -ScriptBlock {
            param($Script, $Path)
            & $Script -InvestigationPath $Path -ParsePrefetch
        } -ArgumentList $AnalyzeScript, $InvestigationPath -Name "ParsePrefetch"
        Write-Host "  ⚡ Started (parallel): Parse Prefetch" -ForegroundColor Green
    } else {
        & $AnalyzeScript -InvestigationPath $InvestigationPath -ParsePrefetch
        Write-AnalysisLog "Completed: Parse Prefetch"
    }
}

if ($ParseRegistry) {
    Write-AnalysisLog "Starting: Parse Registry"
    if ($EnableParallelExecution) {
        $Phase1Jobs += Start-Job -ScriptBlock {
            param($Script, $Path)
            & $Script -InvestigationPath $Path -ParseRegistry
        } -ArgumentList $AnalyzeScript, $InvestigationPath -Name "ParseRegistry"
        Write-Host "  ⚡ Started (parallel): Parse Registry" -ForegroundColor Green
    } else {
        & $AnalyzeScript -InvestigationPath $InvestigationPath -ParseRegistry
        Write-AnalysisLog "Completed: Parse Registry"
    }
}

# Wait for Phase 1 jobs to complete
if ($EnableParallelExecution -and $Phase1Jobs.Count -gt 0) {
    Write-Host "`n  ⏳ Waiting for Phase 1 parsing operations to complete..." -ForegroundColor Yellow
    $Phase1Jobs | Wait-Job | Out-Null
    
    # Check results and display output
    foreach ($job in $Phase1Jobs) {
        Write-Host "`n  ✅ Completed: $($job.Name)" -ForegroundColor Green
        Write-AnalysisLog "Completed: $($job.Name)"
        
        # Display job output
        $output = Receive-Job -Job $job
        if ($output) {
            Write-Host $output -ForegroundColor Gray
        }
        
        # Check for errors
        if ($job.State -eq 'Failed') {
            Write-Host "  ❌ Job failed: $($job.Name)" -ForegroundColor Red
            Write-AnalysisLog "ERROR: $($job.Name) failed"
        }
    }
    
    # Clean up jobs
    $Phase1Jobs | Remove-Job
}

Write-Host "`n[PHASE 1] Complete - Artifacts parsed to CSV files`n" -ForegroundColor Green

# ============================================================================
# PHASE 2: SEARCH OPERATIONS (Sequential - Requires Phase 1)
# ============================================================================

Write-Host "`n[PHASE 2] Searching Parsed Data" -ForegroundColor Yellow
Write-Host "These operations query the CSV files created in Phase 1.`n" -ForegroundColor Gray

if ($SearchEventLogs) {
    Write-AnalysisLog "Starting: Search Event Logs"
    Write-Host "  🔍 Searching event logs for keywords and Event IDs..." -ForegroundColor Cyan
    
    $searchParams = @{
        InvestigationPath = $InvestigationPath
    }
    
    if ($EventLogKeywords -and $EventLogKeywords.Count -gt 0) {
        $searchParams['SearchKeywords'] = $EventLogKeywords
    }
    
    if ($EventIDsToFilter -and $EventIDsToFilter.Count -gt 0) {
        $searchParams['FilterEventIDs'] = $EventIDsToFilter
    }
    
    $searchParams['DetectSuspiciousPatterns'] = $true
    
    & $AnalyzeScript @searchParams
    Write-AnalysisLog "Completed: Search Event Logs"
    Write-Host "  ✅ Event log search complete" -ForegroundColor Green
}

if ($SearchMFT) {
    Write-AnalysisLog "Starting: Search MFT"
    Write-Host "  🔍 Searching MFT for file paths..." -ForegroundColor Cyan
    
    $mftParams = @{
        InvestigationPath = $InvestigationPath
    }
    
    if ($MFTSearchPaths -and $MFTSearchPaths.Count -gt 0) {
        $mftParams['SearchMFTPaths'] = $MFTSearchPaths
    }
    
    & $AnalyzeScript @mftParams
    Write-AnalysisLog "Completed: Search MFT"
    Write-Host "  ✅ MFT search complete" -ForegroundColor Green
}

Write-Host "`n[PHASE 2] Complete - Search results generated`n" -ForegroundColor Green

# ============================================================================
# PHASE 3: ADDITIONAL ANALYSIS (Parallel Execution)
# ============================================================================

Write-Host "`n[PHASE 3] Additional Analysis Modules" -ForegroundColor Yellow
Write-Host "These operations analyze specific artifact types and can run in parallel.`n" -ForegroundColor Gray

$Phase3Jobs = @()

if ($AnalyzeBrowserHistory) {
    Write-AnalysisLog "Starting: Browser History Analysis"
    if ($EnableParallelExecution) {
        $Phase3Jobs += Start-Job -ScriptBlock {
            param($Script, $Path)
            & $Script -InvestigationPath $Path -AnalyzeBrowserHistory
        } -ArgumentList $AnalyzeScript, $InvestigationPath -Name "BrowserHistory"
        Write-Host "  ⚡ Started (parallel): Browser History Analysis" -ForegroundColor Green
    } else {
        & $AnalyzeScript -InvestigationPath $InvestigationPath -AnalyzeBrowserHistory
        Write-AnalysisLog "Completed: Browser History Analysis"
    }
}

if ($AnalyzeNetworkArtifacts) {
    Write-AnalysisLog "Starting: Network Artifacts Analysis"
    if ($EnableParallelExecution) {
        $Phase3Jobs += Start-Job -ScriptBlock {
            param($Script, $Path)
            & $Script -InvestigationPath $Path -AnalyzeNetworkArtifacts
        } -ArgumentList $AnalyzeScript, $InvestigationPath -Name "NetworkArtifacts"
        Write-Host "  ⚡ Started (parallel): Network Artifacts Analysis" -ForegroundColor Green
    } else {
        & $AnalyzeScript -InvestigationPath $InvestigationPath -AnalyzeNetworkArtifacts
        Write-AnalysisLog "Completed: Network Artifacts Analysis"
    }
}

if ($AnalyzeActiveDirectory) {
    Write-AnalysisLog "Starting: Active Directory Analysis"
    if ($EnableParallelExecution) {
        $Phase3Jobs += Start-Job -ScriptBlock {
            param($Script, $Path)
            & $Script -InvestigationPath $Path -AnalyzeActiveDirectory
        } -ArgumentList $AnalyzeScript, $InvestigationPath -Name "ActiveDirectory"
        Write-Host "  ⚡ Started (parallel): Active Directory Analysis" -ForegroundColor Green
    } else {
        & $AnalyzeScript -InvestigationPath $InvestigationPath -AnalyzeActiveDirectory
        Write-AnalysisLog "Completed: Active Directory Analysis"
    }
}

# Wait for Phase 3 jobs to complete
if ($EnableParallelExecution -and $Phase3Jobs.Count -gt 0) {
    Write-Host "`n  ⏳ Waiting for Phase 3 analysis operations to complete..." -ForegroundColor Yellow
    $Phase3Jobs | Wait-Job | Out-Null
    
    foreach ($job in $Phase3Jobs) {
        Write-Host "`n  ✅ Completed: $($job.Name)" -ForegroundColor Green
        Write-AnalysisLog "Completed: $($job.Name)"
        
        $output = Receive-Job -Job $job
        if ($output) {
            Write-Host $output -ForegroundColor Gray
        }
        
        if ($job.State -eq 'Failed') {
            Write-Host "  ❌ Job failed: $($job.Name)" -ForegroundColor Red
            Write-AnalysisLog "ERROR: $($job.Name) failed"
        }
    }
    
    $Phase3Jobs | Remove-Job
}

Write-Host "`n[PHASE 3] Complete - Additional analysis finished`n" -ForegroundColor Green

# ============================================================================
# PHASE 4: YARA SCANNING (If Enabled)
# ============================================================================

if ($RunYaraScan) {
    Write-Host "`n[PHASE 4] Yara Scanning" -ForegroundColor Yellow
    
    if (-not (Test-Path $YaraInputFile)) {
        Write-Host "  ⚠️  Yara input file not found: $YaraInputFile" -ForegroundColor Yellow
        Write-AnalysisLog "WARNING: Yara input file not found: $YaraInputFile"
    } else {
        Write-AnalysisLog "Starting: Yara Scan"
        Write-Host "  🔍 Running Yara scan for sensitive files/IOCs..." -ForegroundColor Cyan
        
        & $AnalyzeScript -InvestigationPath $InvestigationPath -YaraInputFile $YaraInputFile
        
        Write-AnalysisLog "Completed: Yara Scan"
        Write-Host "  ✅ Yara scan complete" -ForegroundColor Green
    }
}

# ============================================================================
# PHASE 5: REPORTING
# ============================================================================

if ($GenerateReports) {
    Write-Host "`n[PHASE 5] Generating Summary Reports" -ForegroundColor Yellow
    Write-AnalysisLog "Starting: Report Generation"
    
    & $AnalyzeScript -InvestigationPath $InvestigationPath -GenerateReport
    
    Write-AnalysisLog "Completed: Report Generation"
    Write-Host "  ✅ Reports generated" -ForegroundColor Green
}

# ============================================================================
# COMPLETION SUMMARY
# ============================================================================

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Host "`n============================================================================" -ForegroundColor Cyan
Write-Host "Investigation Analysis Complete" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Investigation: $InvestigationName" -ForegroundColor White
Write-Host "Duration: $($Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
Write-Host "End Time: $EndTime" -ForegroundColor White
Write-Host "============================================================================`n" -ForegroundColor Cyan

Write-AnalysisLog "=== Investigation Analysis Completed ==="
Write-AnalysisLog "Duration: $($Duration.ToString('hh\:mm\:ss'))"

Write-Host "Analysis Results Location:" -ForegroundColor Yellow
Write-Host "  Investigation Folder: $InvestigationPath" -ForegroundColor White
Write-Host "  Execution Log: $AnalysisLogPath" -ForegroundColor White
Write-Host "`nKey Output Files:" -ForegroundColor Yellow
Write-Host "  - Phase3_EventLog_Analysis/Security_parsed.csv" -ForegroundColor White
Write-Host "  - Phase3_Filtered_EventLog_Results.csv" -ForegroundColor White
Write-Host "  - Phase3_MFT_Analysis/MFT_Full.csv" -ForegroundColor White
Write-Host "  - Phase3_MFT_PathMatches.csv" -ForegroundColor White
Write-Host "  - Phase3_Prefetch_Analysis/Prefetch_Timeline.csv" -ForegroundColor White
Write-Host "  - Phase3_Registry_Analysis/*.csv" -ForegroundColor White
if ($RunYaraScan) {
    Write-Host "  - Phase3_Yara_Scan_Results.txt" -ForegroundColor White
}
Write-Host "`n"
