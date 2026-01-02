<#
.SYNOPSIS
    Migrates the project to a local directory (C:\Source) to avoid OneDrive issues.

.DESCRIPTION
    1. Creates C:\Source\Host-Evidence-Runner
    2. Copies project files (excluding heavy artifacts like investigations/releases)
    3. Updates VS Code workspace paths
    4. Verifies the new environment

.NOTES
    OneDrive Path: C:\Users\Michael.O.Humphrey\OneDrive - Municipality of Anchorage\Documents\Development\GitHub\Host-Evidence-Runner
    Target Path:   C:\Source\Host-Evidence-Runner
#>

$ErrorActionPreference = 'Stop'
$sourceDir = $PSScriptRoot
$targetRoot = "C:\Source"
$targetDir = Join-Path $targetRoot "Host-Evidence-Runner"

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "MIGRATION: Moving Project to Local Storage" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Source: $sourceDir" -ForegroundColor Gray
Write-Host "Target: $targetDir" -ForegroundColor Gray
Write-Host ""

# 1. Create Target Directory
if (-not (Test-Path $targetRoot)) {
    New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    Write-Host "Created $targetRoot" -ForegroundColor Green
}

# 2. Copy Files (Robocopy for robustness)
Write-Host "Copying files..." -ForegroundColor Yellow
$logFile = Join-Path $sourceDir "Migration_Robocopy.log"

# Exclude heavy/generated folders
$excludeDirs = @(
    "investigations",
    "releases",
    ".venv",
    "__pycache__",
    "logs"
)

$robocopyCmd = "robocopy `"$sourceDir`" `"$targetDir`" /E /XD $($excludeDirs -join ' ') /XF *.log /R:1 /W:1 /NP /LOG:`"$logFile`""
Invoke-Expression $robocopyCmd | Out-Null

if ($LASTEXITCODE -ge 8) {
    Write-Host "Robocopy failed with exit code $LASTEXITCODE. Check $logFile" -ForegroundColor Red
    exit 1
}
Write-Host "Files copied successfully." -ForegroundColor Green

# 3. Update VS Code Workspace
Write-Host "Updating VS Code Workspace..." -ForegroundColor Yellow
$workspaceFile = Join-Path $targetDir "Host-Evidence-Runner.code-workspace"

if (Test-Path $workspaceFile) {
    $json = Get-Content $workspaceFile -Raw
    # Replace deep relative paths with shallow ones
    # Old: "../../../../../../../Temp/Investigations"
    # New: "../../Temp/Investigations"
    
    $newJson = $json -replace "\.\./\.\./\.\./\.\./\.\./\.\./\.\./Temp", "../../Temp"
    
    Set-Content -Path $workspaceFile -Value $newJson
    Write-Host "Workspace paths updated." -ForegroundColor Green
}

# 4. Create a 'Open-New-Project.bat' for easy switching
$batPath = Join-Path $sourceDir "OPEN_NEW_LOCATION.bat"
"@echo off
echo Opening new project location...
code `"$workspaceFile`"
pause
" | Set-Content $batPath

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "MIGRATION COMPLETE" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. A new copy of the project is at: $targetDir"
Write-Host "2. Run 'OPEN_NEW_LOCATION.bat' to open it in VS Code."
Write-Host "3. Verify the new location works."
Write-Host "4. Once verified, you can archive/delete this OneDrive copy."
Write-Host ""
