<#
.SYNOPSIS
    A runner script to perform post-collection analysis on Cado-Batch investigations.
.DESCRIPTION
    This script imports the CadoBatchAnalysis module and executes analysis functions
    against a specified investigation's collected data. Supports Yara scanning for
    sensitive files and event log parsing with EvtxECmd.
.PARAMETER InvestigationPath
    The full path to a specific investigation timestamp folder 
    (e.g., .\investigations\Case_123\SERVER01\20251212_143022).
.PARAMETER YaraInputFile
    (Optional) The path to the CSV file containing the sensitive file information
    for the Yara scan. Must have 'FileName' and 'SHA256Hash' columns.
.PARAMETER ParseEventLogs
    (Optional) Switch to enable parsing of Windows Event Logs (.evtx files) using EvtxECmd.
.PARAMETER EventLogFormat
    (Optional) Output format for parsed event logs. Options: 'csv', 'json', 'both'. Default is 'csv'.
.EXAMPLE
    # Run Yara scan only
    .\source\Analyze-Investigation.ps1 -InvestigationPath ".\investigations\MyCase\MyServer\20251212_103000" -YaraInputFile ".\sensitive_files.csv"
.EXAMPLE
    # Parse event logs only
    .\source\Analyze-Investigation.ps1 -InvestigationPath ".\investigations\MyCase\MyServer\20251212_103000" -ParseEventLogs
.EXAMPLE
    # Run both Yara scan and event log parsing
    .\source\Analyze-Investigation.ps1 -InvestigationPath ".\investigations\MyCase\MyServer\20251212_103000" -YaraInputFile ".\sensitive_files.csv" -ParseEventLogs -EventLogFormat both
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InvestigationPath,

    [Parameter(Mandatory=$false)]
    [string]$YaraInputFile,
    
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
    
    [Parameter(Mandatory=$false)]
    [string[]]$SearchMFTPaths,
    
    [Parameter(Mandatory=$false)]
    [string]$SearchMFTPathsFile
    ,
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport
    ,
    [Parameter(Mandatory=$false)] [string]$CasePath,
    [Parameter(Mandatory=$false)] [string]$HostPath,
    [Parameter(Mandatory=$false)] [string]$CollectionPath
)

# Construct the full path to the module
$scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$modulePath = Join-Path $scriptRoot "..\modules\CadoBatchAnalysis\CadoBatchAnalysis.psd1"

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

if ($YaraInputFile) {
    Write-Host "`nStarting Yara Scan Workflow..." -ForegroundColor Yellow
    Invoke-YaraScan -InvestigationPath $InvestigationPath -YaraInputFile $YaraInputFile
}

if ($ParseEventLogs) {
    Write-Host "`nStarting Event Log Parsing..." -ForegroundColor Yellow
    Invoke-EventLogParsing -InvestigationPath $InvestigationPath -OutputFormat $EventLogFormat
}

if ($SearchKeywords -or $SearchKeywordsFile -or $FilterEventIDs -or $DetectSuspiciousPatterns) {
    Write-Host "`nSearching Event Log Data..." -ForegroundColor Yellow
    
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
    if ($keywordsToSearch.Count -gt 0) { $searchParams['Keywords'] = $keywordsToSearch }
    if ($FilterEventIDs) { $searchParams['EventIDs'] = $FilterEventIDs }
    if ($DetectSuspiciousPatterns) { $searchParams['SuspiciousPatterns'] = $true }
    
    Search-EventLogData @searchParams
}

if ($SearchMFTPaths -or $SearchMFTPathsFile) {
    Write-Host "`nSearching MFT for file paths..." -ForegroundColor Yellow
    $mftParams = @{
        InvestigationPath = $InvestigationPath
    }
    if ($SearchMFTPaths) { $mftParams['SearchPaths'] = $SearchMFTPaths }
    if ($SearchMFTPathsFile) { $mftParams['SearchPathsFile'] = $SearchMFTPathsFile }
    
    Search-MFTForPaths @mftParams
}

if ($GenerateReport) {
    Write-Host "`nGenerating report summaries..." -ForegroundColor Yellow
    $repParams = @{}
    if ($InvestigationPath) { $repParams['InvestigationPath'] = $InvestigationPath }
    if ($CasePath) { $repParams['CasePath'] = $CasePath }
    if ($HostPath) { $repParams['HostPath'] = $HostPath }
    if ($CollectionPath) { $repParams['CollectionPath'] = $CollectionPath }
    Generate-Reports @repParams
}

if (-not $YaraInputFile -and -not $ParseEventLogs -and -not $SearchKeywords -and -not $SearchKeywordsFile -and -not $FilterEventIDs -and -not $DetectSuspiciousPatterns -and -not $SearchMFTPaths -and -not $SearchMFTPathsFile -and -not $GenerateReport) {
    Write-Warning "No analysis operations specified. Available options:`n" +
                  "  -YaraInputFile: Scan for sensitive files`n" +
                  "  -ParseEventLogs: Parse Windows event logs`n" +
                  "  -SearchKeywords: Search event logs for keywords`n" +
                  "  -SearchKeywordsFile: Load keywords from text file (one per line)`n" +
                  "  -FilterEventIDs: Filter by specific Event IDs`n" +
                  "  -DetectSuspiciousPatterns: Find suspicious commands/patterns`n" +
                  "  -SearchMFTPaths/-SearchMFTPathsFile: Search the MFT for file paths`n" +
                  "  -GenerateReport: Write summaries (supports -CasePath, -HostPath, -CollectionPath)"
}

Write-Host "`nAnalysis complete." -ForegroundColor Green
