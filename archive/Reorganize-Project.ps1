# Script to reorganize HER project structure
# Move Phase 1 & 2 documentation to archive folder
# Organize docs by audience

$ErrorActionPreference = 'Continue'

Write-Host "Reorganizing HER project structure..." -ForegroundColor Cyan

# Files to move to archive/
$archiveFiles = @(
    "PHASE_1_DOCUMENTATION_INDEX.md",
    "PHASE_1_FINAL_SUMMARY.md",
    "PHASE_1_IMPLEMENTATION_SUMMARY.md",
    "PHASE_1_QUICK_REFERENCE.md",
    "PHASE_1_STATUS.md",
    "PHASE_1_TESTING_GUIDE.md",
    "PHASE_1_TOOLS_INSTALLED.md",
    "PHASE_2_IMPLEMENTATION_COMPLETE.md",
    "PROJECT_CONTEXT_FOR_RENAME.md",
    "PROJECT_STRUCTURE.md",
    "PACKAGE_SUMMARY.md",
    "REPOSITORY_CONTENTS.md",
    "README_NEW.md",
    "MANIFEST.md"
)

# Files to move to docs/analyst/
$analystDocs = @(
    "ANALYST_DEPLOYMENT_CHECKLIST.md",
    "TECHNICAL_DOCUMENTATION.md",
    "WINDOWS_SERVER_FORENSICS_PLAN.md",
    "BINS_EVALUATION_AND_TOOLS.md",
    "CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md"
)

# Files to move to docs/sysadmin/
$sysadminDocs = @(
    "SYSADMIN_DEPLOYMENT_GUIDE.md",
    "QUICK_START.txt"
)

# Files to move to docs/reference/
$referenceDocs = @(
    "QUICK_START.md",
    "QUICK_REFERENCE.md"
)

# Create directory structure
$dirs = @(
    "docs\analyst",
    "docs\sysadmin",
    "docs\reference"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Green
    }
}

# Move archive files
Write-Host "`nMoving Phase 1 & 2 documents to archive/..." -ForegroundColor Yellow
foreach ($file in $archiveFiles) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination "archive\" -Force
        Write-Host "  Moved: $file" -ForegroundColor Gray
    }
}

# Move analyst docs
Write-Host "`nMoving analyst documentation to docs/analyst/..." -ForegroundColor Yellow
foreach ($file in $analystDocs) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination "docs\analyst\" -Force
        Write-Host "  Moved: $file" -ForegroundColor Gray
    }
}

# Move sysadmin docs
Write-Host "`nMoving sysadmin documentation to docs/sysadmin/..." -ForegroundColor Yellow
foreach ($file in $sysadminDocs) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination "docs\sysadmin\" -Force
        Write-Host "  Moved: $file" -ForegroundColor Gray
    }
}

# Move reference docs
Write-Host "`nMoving reference documentation to docs/reference/..." -ForegroundColor Yellow
foreach ($file in $referenceDocs) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination "docs\reference\" -Force
        Write-Host "  Moved: $file" -ForegroundColor Gray
    }
}

# Move existing documentation/ folder contents to docs/
Write-Host "`nMoving documentation/ folder contents to docs/..." -ForegroundColor Yellow
if (Test-Path "documentation") {
    Get-ChildItem "documentation" | ForEach-Object {
        Move-Item -Path $_.FullName -Destination "docs\" -Force
        Write-Host "  Moved: $($_.Name)" -ForegroundColor Gray
    }
    Remove-Item "documentation" -Force
    Write-Host "  Removed empty documentation/ folder" -ForegroundColor Gray
}

Write-Host "`n✅ Reorganization complete!" -ForegroundColor Green
Write-Host "`nNew structure:" -ForegroundColor Cyan
Write-Host "  archive/          - Phase 1 & 2 historical documents"
Write-Host "  docs/analyst/     - Documentation for forensic analysts"
Write-Host "  docs/sysadmin/    - Documentation for system administrators"
Write-Host "  docs/reference/   - Quick reference guides"
Write-Host "  docs/             - Additional technical documentation"
