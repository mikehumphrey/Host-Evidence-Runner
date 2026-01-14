<#
.SYNOPSIS
    Comprehensive post-collection analysis for Host Evidence Runner (HER) investigations.
.DESCRIPTION
    This script imports the CadoBatchAnalysis module and executes analysis functions
    against collected forensic artifacts. Supports analysis of:
    - Windows Event Logs (Security, System, Application, etc.)
    - Master File Table (MFT) and file system timeline
    - Registry hives (SYSTEM, SOFTWARE, SAM, SECURITY, user hives)
    - Prefetch files (program execution history)
    - Browser history (Chrome, Edge, Firefox)
    - Active Directory artifacts (NTDS.dit, SYSVOL if collected)
    - Network artifacts (RDP history, USB devices, WiFi profiles)
    - Yara scanning for IOCs or sensitive files
.PARAMETER InvestigationPath
    The full path to a specific investigation timestamp folder 
    (e.g., .\investigations\Case_123\SERVER01\20251212_143022).
.PARAMETER YaraInputFile
    (Optional) CSV file with sensitive file information for Yara scanning.
    Must have 'FileName' and 'SHA256Hash' columns.
.PARAMETER ParseEventLogs
    Parse Windows Event Logs (.evtx files) using EvtxECmd to CSV/JSON.
.PARAMETER ParseMFT
    Parse Master File Table ($MFT) using MFTECmd for file system timeline.
.PARAMETER ParsePrefetch
    Parse Prefetch files using PECmd for program execution history.
.PARAMETER ParseRegistry
    Parse registry hives using RECmd for system and user configuration.
.PARAMETER AnalyzeBrowserHistory
    Extract and analyze browser history from collected artifacts.
.PARAMETER AnalyzeActiveDirectory
    Analyze AD artifacts (NTDS.dit, SYSVOL) if available.
.PARAMETER AnalyzeNetworkArtifacts
    Extract network configuration, RDP history, USB devices, WiFi profiles.
.PARAMETER FullAnalysis
    Run all available analysis modules on the investigation.
.PARAMETER EventLogFormat
    Output format for parsed event logs: 'csv', 'json', or 'both'. Default: 'csv'.
.EXAMPLE
    # Full analysis of all collected artifacts
    .\source\Analyze-Investigation.ps1 -InvestigationPath ".\investigations\Case\Host\20251215_120000" -FullAnalysis
.EXAMPLE
    # Parse only event logs and MFT
    .\source\Analyze-Investigation.ps1 -InvestigationPath ".\investigations\Case\Host\20251215_120000" -ParseEventLogs -ParseMFT
.EXAMPLE
    # Search event logs with keywords and analyze network artifacts
    .\source\Analyze-Investigation.ps1 -InvestigationPath ".\investigations\Case\Host\20251215_120000" `
        -ParseEventLogs -SearchKeywordsFile "iocs.txt" -AnalyzeNetworkArtifacts
.EXAMPLE
    # Yara scan with custom rule file
    .\source\Analyze-Investigation.ps1 -InvestigationPath ".\investigations\Case\Host\20251215_120000" -YaraInputFile ".\sensitive_files.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InvestigationPath,

    # Project root (HER repo). Defaults to the parent of this script's directory so it works from any CWD.
    [Parameter(Mandatory=$false)]
    [string]$ProjectRoot,

    # Scanning & IOC Detection
    [Parameter(Mandatory=$false)]
    [string]$YaraInputFile,
    
    # Event Log Analysis
    [Parameter(Mandatory=$false)]
    [switch]$ParseEventLogs,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('csv', 'json', 'both')]
    [string]$EventLogFormat = 'csv',
    
    [Parameter(Mandatory=$false)]
    [string[]]$SearchKeywords,
    
    [Parameter(Mandatory=$false)]
    [string]$SearchKeywordsFile,
    
    [Parameter(Mandatory=$false)]
    [int[]]$FilterEventIDs,
    
    [Parameter(Mandatory=$false)]
    [switch]$DetectSuspiciousPatterns,
    
    # File System Analysis
    [Parameter(Mandatory=$false)]
    [switch]$ParseMFT,
    
    [Parameter(Mandatory=$false)]
    [string[]]$SearchMFTPaths,
    
    [Parameter(Mandatory=$false)]
    [string]$SearchMFTPathsFile,
    
    # Program Execution Analysis
    [Parameter(Mandatory=$false)]
    [switch]$ParsePrefetch,
    
    # Registry Analysis
    [Parameter(Mandatory=$false)]
    [switch]$ParseRegistry,
    
    # Browser & User Activity
    [Parameter(Mandatory=$false)]
    [switch]$AnalyzeBrowserHistory,
    
    # Domain Controller Artifacts
    [Parameter(Mandatory=$false)]
    [switch]$AnalyzeActiveDirectory,
    
    # Network Artifacts
    [Parameter(Mandatory=$false)]
    [switch]$AnalyzeNetworkArtifacts,
    
    # Comprehensive Analysis
    [Parameter(Mandatory=$false)]
    [switch]$FullAnalysis,
    
    # Reporting
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory=$false)] 
    [string]$CasePath,
    
    [Parameter(Mandatory=$false)] 
    [string]$HostPath,
    
    [Parameter(Mandatory=$false)] 
    [string]$CollectionPath
)

    # Resolve project root relative to this script when not provided
    $scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    if (-not $ProjectRoot) {
        $ProjectRoot = Split-Path -Parent $scriptRoot
    }

    # Construct the full path to the module
    $modulePath = Join-Path $ProjectRoot "modules\CadoBatchAnalysis\CadoBatchAnalysis.psd1"

try {
    # Import the module. Using -Force to ensure the latest version is loaded in case of changes.
    Import-Module -Name $modulePath -Force
    Write-Host "✅ CadoBatchAnalysis module loaded successfully." -ForegroundColor Green
}
catch {
    Write-Error "Failed to import the CadoBatchAnalysis module. Ensure it exists at '$modulePath'."
    throw
}

# --- Execute Analysis Functions ---

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Host Evidence Runner (HER) - Analysis" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# If FullAnalysis specified, enable all modules
if ($FullAnalysis) {
    Write-Host "⚡ Full Analysis Mode Enabled" -ForegroundColor Yellow
    $ParseEventLogs = $true
    $ParseMFT = $true
    $ParsePrefetch = $true
    $ParseRegistry = $true
    $AnalyzeBrowserHistory = $true
    $AnalyzeNetworkArtifacts = $true
    $AnalyzeActiveDirectory = $true
    $GenerateReport = $true
}

# Yara Scanning (IOC Detection)
if ($YaraInputFile) {
    Write-Host "`n🔍 Starting Yara Scan Workflow..." -ForegroundColor Yellow
    Invoke-YaraScan -InvestigationPath $InvestigationPath -YaraInputFile $YaraInputFile
}

# Event Log Analysis
if ($ParseEventLogs) {
    Write-Host "`n📋 Parsing Windows Event Logs..." -ForegroundColor Yellow
    Invoke-EventLogParsing -InvestigationPath $InvestigationPath -OutputFormat $EventLogFormat
}

if ($SearchKeywords -or $SearchKeywordsFile -or $FilterEventIDs -or $DetectSuspiciousPatterns) {
    Write-Host "`n🔎 Searching Event Log Data..." -ForegroundColor Yellow
    
    # Load keywords from file if specified
    $keywordsToSearch = @()
    if ($SearchKeywordsFile) {
        if (Test-Path $SearchKeywordsFile) {
            $keywordsToSearch = Get-Content $SearchKeywordsFile | Where-Object { $_.Trim() -ne "" }
            Write-Host "   Loaded $($keywordsToSearch.Count) keywords from file" -ForegroundColor Gray
        } else {
            Write-Error "Keywords file not found: $SearchKeywordsFile"
        }
    }
    if ($SearchKeywords) {
        $keywordsToSearch += $SearchKeywords
    }
    
    $searchParams = @{
        InvestigationPath = $InvestigationPath
    }
    $enableSuspicious = [bool]$DetectSuspiciousPatterns
    if ($keywordsToSearch.Count -gt 0) { $searchParams['Keywords'] = $keywordsToSearch }
    if ($FilterEventIDs) { $searchParams['EventIDs'] = $FilterEventIDs }
    if ($enableSuspicious) { $searchParams['SuspiciousPatterns'] = $true }
    
    Search-EventLogData @searchParams
}

# File System Analysis (MFT)
if ($ParseMFT) {
    Write-Host "`n💾 Parsing Master File Table (MFT)..." -ForegroundColor Yellow
    Invoke-MFTParsing -InvestigationPath $InvestigationPath
}

if ($SearchMFTPaths -or $SearchMFTPathsFile) {
    Write-Host "`n🔍 Searching MFT for file paths..." -ForegroundColor Yellow
    $mftParams = @{
        InvestigationPath = $InvestigationPath
    }
    if ($SearchMFTPaths) { $mftParams['SearchPaths'] = $SearchMFTPaths }
    if ($SearchMFTPathsFile) { $mftParams['SearchPathsFile'] = $SearchMFTPathsFile }
    
    Search-MFTForPaths @mftParams
}

# Program Execution Analysis
if ($ParsePrefetch) {
    Write-Host "`n⚡ Analyzing Prefetch Files..." -ForegroundColor Yellow
    Invoke-PrefetchAnalysis -InvestigationPath $InvestigationPath
}

# Registry Analysis
if ($ParseRegistry) {
    Write-Host "`n📝 Parsing Registry Hives..." -ForegroundColor Yellow
    Invoke-RegistryAnalysis -InvestigationPath $InvestigationPath
}

# Browser & User Activity
if ($AnalyzeBrowserHistory) {
    Write-Host "`n🌐 Analyzing Browser History..." -ForegroundColor Yellow
    Invoke-BrowserAnalysis -InvestigationPath $InvestigationPath
}

# Domain Controller Artifacts
if ($AnalyzeActiveDirectory) {
    Write-Host "`n🏢 Analyzing Active Directory Artifacts..." -ForegroundColor Yellow
    Invoke-ADAnalysis -InvestigationPath $InvestigationPath
}

# Network Artifacts
if ($AnalyzeNetworkArtifacts) {
    Write-Host "`n🌐 Analyzing Network Artifacts..." -ForegroundColor Yellow
    Invoke-NetworkAnalysis -InvestigationPath $InvestigationPath
}

# Generate Summary Reports
if ($GenerateReport) {
    Write-Host "`n📊 Generating Summary Reports..." -ForegroundColor Yellow
    $repParams = @{}
    if ($InvestigationPath) { $repParams['InvestigationPath'] = $InvestigationPath }
    if ($CasePath) { $repParams['CasePath'] = $CasePath }
    if ($HostPath) { $repParams['HostPath'] = $HostPath }
    if ($CollectionPath) { $repParams['CollectionPath'] = $CollectionPath }
    Generate-Reports @repParams
}

# Display help if no options specified
if (-not $YaraInputFile -and -not $ParseEventLogs -and -not $ParseMFT -and -not $ParsePrefetch -and 
    -not $ParseRegistry -and -not $AnalyzeBrowserHistory -and -not $AnalyzeActiveDirectory -and 
    -not $AnalyzeNetworkArtifacts -and -not $SearchKeywords -and -not $SearchKeywordsFile -and 
    -not $FilterEventIDs -and -not $DetectSuspiciousPatterns -and -not $SearchMFTPaths -and 
    -not $SearchMFTPathsFile -and -not $GenerateReport -and -not $FullAnalysis) {
    
    Write-Host "`n⚠️  No analysis operations specified.`n" -ForegroundColor Yellow
    Write-Host "Available Analysis Modules:" -ForegroundColor Cyan
    Write-Host "  -FullAnalysis                : Run all available analysis modules" -ForegroundColor White
    Write-Host "`nFile System:" -ForegroundColor Cyan
    Write-Host "  -ParseMFT                    : Parse Master File Table for timeline" -ForegroundColor White
    Write-Host "  -SearchMFTPaths              : Search MFT for specific file paths" -ForegroundColor White
    Write-Host "  -SearchMFTPathsFile          : Load search paths from file" -ForegroundColor White
    Write-Host "`nEvent Logs:" -ForegroundColor Cyan
    Write-Host "  -ParseEventLogs              : Parse Windows event logs to CSV/JSON" -ForegroundColor White
    Write-Host "  -SearchKeywords              : Search event logs for keywords" -ForegroundColor White
    Write-Host "  -SearchKeywordsFile          : Load keywords from text file" -ForegroundColor White
    Write-Host "  -FilterEventIDs              : Filter by specific Event IDs" -ForegroundColor White
    Write-Host "  -DetectSuspiciousPatterns    : Find suspicious commands/patterns" -ForegroundColor White
    Write-Host "`nProgram Execution:" -ForegroundColor Cyan
    Write-Host "  -ParsePrefetch               : Analyze prefetch files for execution history" -ForegroundColor White
    Write-Host "`nRegistry:" -ForegroundColor Cyan
    Write-Host "  -ParseRegistry               : Parse registry hives for configuration" -ForegroundColor White
    Write-Host "`nUser Activity:" -ForegroundColor Cyan
    Write-Host "  -AnalyzeBrowserHistory       : Extract and analyze browser history" -ForegroundColor White
    Write-Host "`nNetwork:" -ForegroundColor Cyan
    Write-Host "  -AnalyzeNetworkArtifacts     : Extract network config, RDP, USB, WiFi" -ForegroundColor White
    Write-Host "`nDomain Controller:" -ForegroundColor Cyan
    Write-Host "  -AnalyzeActiveDirectory      : Analyze AD artifacts (NTDS, SYSVOL)" -ForegroundColor White
    Write-Host "`nThreat Detection:" -ForegroundColor Cyan
    Write-Host "  -YaraInputFile               : Scan for sensitive files or IOCs" -ForegroundColor White
    Write-Host "`nReporting:" -ForegroundColor Cyan
    Write-Host "  -GenerateReport              : Generate summary reports" -ForegroundColor White
    Write-Host "`nExamples:" -ForegroundColor Cyan
    Write-Host "  # Full analysis of all artifacts" -ForegroundColor Gray
    Write-Host "  .\Analyze-Investigation.ps1 -InvestigationPath '.\investigations\Case\Host\20251215' -FullAnalysis`n" -ForegroundColor Gray
    Write-Host "  # Parse event logs and search for keywords" -ForegroundColor Gray
    Write-Host "  .\Analyze-Investigation.ps1 -InvestigationPath '.\investigations\Case\Host\20251215' -ParseEventLogs -SearchKeywordsFile 'iocs.txt'`n" -ForegroundColor Gray
    Write-Host "  # Analyze file system and program execution" -ForegroundColor Gray
    Write-Host "  .\Analyze-Investigation.ps1 -InvestigationPath '.\investigations\Case\Host\20251215' -ParseMFT -ParsePrefetch`n" -ForegroundColor Gray
}

Write-Host "`n✅ Analysis complete.`n" -ForegroundColor Green
