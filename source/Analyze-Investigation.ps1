<#
.SYNOPSIS
    A runner script to perform post-collection analysis on Cado-Batch investigations.
.DESCRIPTION
    This script imports the CadoBatchAnalysis module and executes analysis functions
    against a specified investigation's collected data.
.PARAMETER InvestigationPath
    The full path to a specific investigation timestamp folder 
    (e.g., .\investigations\Case_123\SERVER01\20251212_143022).
.PARAMETER YaraInputFile
    The path to the CSV file containing the sensitive file information
    for the Yara scan. Must have 'FileName' and 'SHA256Hash' columns.
.EXAMPLE
    .\source\Analyze-Investigation.ps1 -InvestigationPath ".\investigations\MyCase\MyServer\20251212_103000" -YaraInputFile ".\sensitive_files.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$InvestigationPath,

    [Parameter(Mandatory=$true)]
    [string]$YaraInputFile
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

# Currently, this script only supports Yara scans, but it can be expanded.
if ($YaraInputFile) {
    Write-Host "`nStarting Yara Scan Workflow..." -ForegroundColor Yellow
    Invoke-YaraScan -InvestigationPath $InvestigationPath -YaraInputFile $YaraInputFile
}

Write-Host "`nAnalysis complete." -ForegroundColor Green
