# Quick Test Script for Large CSV Fix
# Tests the updated Search-EventLogData function with a large file

$ErrorActionPreference = 'Continue'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Testing Large CSV Search Fix" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test configuration
$testInvestigationPath = "C:\Temp\Investigations\MOA-SD-PSDC01\20251217_162931"
$keywords = @("drive.google.com", "chrome.exe", "ADMJJJ")
$eventIds = @(4663, 4688, 4624)

Write-Host "Investigation Path: $testInvestigationPath" -ForegroundColor White
Write-Host "Keywords: $($keywords -join ', ')" -ForegroundColor White
Write-Host "Event IDs: $($eventIds -join ', ')" -ForegroundColor White
Write-Host ""

# Check if CSV exists
$csvPath = Join-Path $testInvestigationPath "Phase3_EventLog_Analysis"
if (-not (Test-Path $csvPath)) {
    Write-Error "CSV path not found: $csvPath"
    exit 1
}

$csvFile = Get-ChildItem -Path $csvPath -Filter "*.csv" | Select-Object -First 1
if (-not $csvFile) {
    Write-Error "No CSV file found in $csvPath"
    exit 1
}

$sizeMB = [math]::Round($csvFile.Length / 1MB, 2)
Write-Host "CSV File: $($csvFile.Name)" -ForegroundColor Cyan
Write-Host "Size: $sizeMB MB" -ForegroundColor Cyan

if ($sizeMB -gt 500) {
    Write-Host "✅ Large file detected - streaming mode will be used" -ForegroundColor Green
} else {
    Write-Host "ℹ️  Small file - traditional mode will be used" -ForegroundColor Yellow
}

Write-Host "`nStarting search (this may take several minutes for large files)...`n" -ForegroundColor Yellow

# Time the operation
$startTime = Get-Date

# Import module and run search
$projectRoot = "C:\Dev\GitHub\Host-Evidence-Runner"
$modulePath = Join-Path $projectRoot "modules\CadoBatchAnalysis\CadoBatchAnalysis.psd1"

if (-not (Test-Path $modulePath)) {
    Write-Error "Module not found: $modulePath"
    exit 1
}

Import-Module $modulePath -Force

# Run the search
try {
    Search-EventLogData -InvestigationPath $testInvestigationPath `
        -Keywords $keywords `
        -EventIDs $eventIds `
        -SuspiciousPatterns
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "✅ Search Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host "Result: Check Phase3_Filtered_EventLog_Results.csv" -ForegroundColor White
    
} catch {
    Write-Error "Search failed: $_"
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
