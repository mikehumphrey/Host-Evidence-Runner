<#
.SYNOPSIS
    Creates a versioned GitHub release package for Host Evidence Runner (HER)

.DESCRIPTION
    This script automates the GitHub release process:
    1. Creates a version-tagged release directory
    2. Builds the release package using Build-Release.ps1
    3. Creates a properly named ZIP file for GitHub Assets
    4. Generates release notes summary
    5. Optionally creates a git tag

.PARAMETER Version
    Version number for the release (e.g., "1.0.1", "1.1.0")
    If not specified, reads from RELEASE_NOTES.md

.PARAMETER CreateTag
    If specified, creates a git tag for this version (e.g., v1.0.1)

.PARAMETER Sign
    If specified, signs PowerShell scripts with code signing certificate

.PARAMETER SkipZip
    If specified, does not create ZIP file (for testing)

.EXAMPLE
    .\Build-GitHubRelease.ps1 -Version "1.0.1" -CreateTag -Sign

.EXAMPLE
    .\Build-GitHubRelease.ps1
    # Reads version from RELEASE_NOTES.md

.NOTES
    After running this script:
    1. Navigate to GitHub > Releases > Create Release
    2. Tag: v1.0.1 (or use -CreateTag to auto-create)
    3. Title: "Host Evidence Runner v1.0.1"
    4. Upload: releases/HER-v1.0.1.zip
    5. Paste release notes from releases/v1.0.1/GITHUB_RELEASE_NOTES.txt
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateTag,
    
    [Parameter(Mandatory=$false)]
    [switch]$Sign,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipZip
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath


# ============================================================================
# STEP 0: Set/Edit Version Number (Top of Script for Visibility)
# ============================================================================

# >>>>>>>> EDIT VERSION NUMBER HERE <<<<<<<<
# Set the version number for this release. This should match GitHub tag and semantic versioning (e.g., 1.0.1)
$DefaultVersion = '1.0.0'

# ============================================================================
# STEP 1: Determine Version Number
# ============================================================================

if (-not $Version) {
    Write-Host "No version specified, reading from RELEASE_NOTES.md..." -ForegroundColor Cyan
    $releaseNotes = Get-Content (Join-Path $root "RELEASE_NOTES.md") -Raw
    # Extract version from explicit Version line (e.g., "- **Version**: 1.0.1")
    if ($releaseNotes -match "(?m)^- \*\*Version\*\*:\s*(\d+\.\d+\.\d+)") {
        $Version = $Matches[1]
        Write-Host "Detected version: $Version" -ForegroundColor Green
    } else {
        $Version = $DefaultVersion
        Write-Host "Could not extract version from RELEASE_NOTES.md. Using default: $Version" -ForegroundColor Yellow
    }
}

# Validate version format (GitHub standard: X.Y.Z)
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "Version must be in format X.Y.Z (e.g., 1.0.1)"
    exit 1
}

Write-Host "`n============================================================================" -ForegroundColor Cyan
Write-Host "Creating GitHub Release for Host Evidence Runner v$Version" -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan

# ============================================================================
# STEP 2: Create Release Directory Structure
# ============================================================================

$releaseDir = Join-Path $root "releases\v$Version"
$releasesRoot = Join-Path $root "releases"

if (Test-Path $releaseDir) {
    Write-Warning "Release directory already exists: $releaseDir"
    $response = Read-Host "Overwrite? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
    Remove-Item $releaseDir -Recurse -Force
}

Write-Host "[1/6] Creating release directory: $releaseDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

# ============================================================================
# STEP 3: Build Release Package
# ============================================================================

Write-Host "[2/6] Building release package..." -ForegroundColor Yellow

$buildParams = @{
    OutputDir = $releaseDir
}

if ($Sign) {
    $buildParams['Sign'] = $true
}

& (Join-Path $root "Build-Release.ps1") @buildParams

if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
    Write-Error "Build-Release.ps1 failed with exit code: $LASTEXITCODE"
    exit 1
}


# ============================================================================
# STEP 4: Create ZIP for GitHub Assets
# ============================================================================

if (-not $SkipZip) {
    Write-Host "[3/6] Creating ZIP archive for GitHub..." -ForegroundColor Yellow
    $zipName = "HER-v$Version.zip"
    $zipPath = Join-Path $releasesRoot $zipName

    if (Test-Path $zipPath) {
        Write-Warning "ZIP asset already exists: $zipPath. It will be overwritten."
        try {
            Remove-Item $zipPath -Force
        } catch {
            Write-Error "Could not remove existing ZIP asset: $_"
            exit 1
        }
    }

    # Create ZIP from release directory contents with error handling
    try {
        Compress-Archive -Path "$releaseDir\*" -DestinationPath $zipPath -Force
        $zipSize = (Get-Item $zipPath).Length / 1MB
        Write-Host "  ✅ Created: $zipPath ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create ZIP archive: $_"
        exit 1
    }
} else {
    Write-Host "[3/6] Skipping ZIP creation (-SkipZip specified)" -ForegroundColor Gray
    $zipPath = $null
}


# ============================================================================
# STEP 5: Generate GitHub Release Notes
# ============================================================================

Write-Host "[4/6] Generating GitHub release notes..." -ForegroundColor Yellow

# Extract relevant sections from RELEASE_NOTES.md for GitHub
$releaseNotesPath = Join-Path $root "RELEASE_NOTES.md"
$releaseNotesContent = Get-Content $releaseNotesPath -Raw

# TODO: For future improvement, extract only the latest release section from RELEASE_NOTES.md
# (Currently, the entire file is included. See the '## Latest Release:' header for sectioning.)

# Create a formatted version for GitHub
$githubReleaseNotes = @"
# Host Evidence Runner (HER) v$Version

**A comprehensive forensic evidence collection and analysis toolkit for Windows incident response.**

---

## 📦 Download

Download the release package: **HER-v$Version.zip** (attached below)

---

## 🚀 Quick Start

1. **Extract the ZIP** to USB drive or C:\Temp
2. **Unblock files**: ``Get-ChildItem -Recurse | Unblock-File``
3. **Run as Administrator**: ``.\run-collector.ps1 -AnalystWorkstation "localhost"``

For detailed instructions, see included ``docs\COLLECTION_GUIDE.md``

---

## 📋 What's Included

- **Collection Engine**: PowerShell-based forensic artifact collection
- **Analysis Tools**: Post-collection analysis with Zimmerman tools integration
- **Forensic Tools**: RawCopy, hashdeep, sigcheck, zip utilities
- **Documentation**: Comprehensive guides for analysts and sysadmins
- **Templates**: Investigation workflow templates

---

## 🔍 What Gets Collected

- **400+ forensic artifacts** including:
    - NTFS artifacts (MFT, LogFile, UsnJrnl)
    - Registry hives (SYSTEM, SOFTWARE, SAM, SECURITY, user hives)
    - Event logs (Security, System, Application, PowerShell, Defender)
    - User activity (browser history, recent files, PowerShell history)
    - Program execution (Prefetch, Amcache, SRUM)
    - Network artifacts (RDP history, WiFi profiles, USB devices)
    - **Server roles**: Active Directory, DNS, DHCP, IIS, Hyper-V, DFS

---

## 📝 Release Notes

$releaseNotesContent

---

## 💻 System Requirements

- **OS**: Windows 10, Windows 11, Windows Server 2016+
- **PowerShell**: 5.1 or higher
- **Privileges**: Administrator/Elevated rights required
- **Disk Space**: 30GB+ recommended for complete collection

---

## 📄 License

Apache 2.0 - See LICENSE file for details.

---

## 🔗 Documentation

- [README.md](README.md) - Main documentation
- [COLLECTION_GUIDE.md](docs/COLLECTION_GUIDE.md) - Sysadmin deployment guide
- [QUICK_START.txt](docs/QUICK_START.txt) - 5-minute quick start

---

**For issues, feedback, or feature requests, please open a GitHub issue.**
"@

$githubNotesPath = Join-Path $releaseDir "GITHUB_RELEASE_NOTES.txt"
$githubReleaseNotes | Set-Content $githubNotesPath -Encoding UTF8

Write-Host "  ✅ Created: $githubNotesPath" -ForegroundColor Green

# ============================================================================
# STEP 6: Create Git Tag (Optional)
# ============================================================================

if ($CreateTag) {
    Write-Host "[5/6] Creating git tag..." -ForegroundColor Yellow
    
    $tagName = "v$Version"
    $tagMessage = "Host Evidence Runner v$Version"
    
    try {
        # Check if tag already exists
        $existingTag = git tag -l $tagName 2>$null
        if ($existingTag) {
            Write-Warning "Tag '$tagName' already exists."
            $response = Read-Host "Delete and recreate? (y/n)"
            if ($response -eq 'y') {
                git tag -d $tagName
                Write-Host "  Deleted existing tag" -ForegroundColor Gray
            } else {
                Write-Host "  Keeping existing tag" -ForegroundColor Gray
            }
        }
        
        if (-not $existingTag -or $response -eq 'y') {
            git tag -a $tagName -m $tagMessage
            Write-Host "  ✅ Created git tag: $tagName" -ForegroundColor Green
            Write-Host "  To push: git push origin $tagName" -ForegroundColor Cyan
        }
    } catch {
        Write-Warning "Could not create git tag: $_"
        Write-Host "  You can manually create the tag with: git tag -a $tagName -m '$tagMessage'" -ForegroundColor Yellow
    }
} else {
    Write-Host "[5/6] Skipping git tag creation (-CreateTag not specified)" -ForegroundColor Gray
}

# ============================================================================
# STEP 7: Summary and Next Steps
# ============================================================================

Write-Host "`n[6/6] Release package complete!" -ForegroundColor Green

Write-Host "`n============================================================================" -ForegroundColor Cyan
Write-Host "GitHub Release v$Version Ready" -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan

Write-Host "📁 Release Files:" -ForegroundColor Yellow
Write-Host "  Directory: $releaseDir" -ForegroundColor White
if ($zipPath) {
    Write-Host "  ZIP Asset: $zipPath" -ForegroundColor White
}
Write-Host "  Release Notes: $githubNotesPath" -ForegroundColor White

Write-Host "`n📝 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review the release package in: $releaseDir" -ForegroundColor White
Write-Host "  2. Test the release (optional): Extract and run collection" -ForegroundColor White

if (-not $CreateTag) {
    Write-Host "  3. Create git tag: git tag -a v$Version -m 'Host Evidence Runner v$Version'" -ForegroundColor White
    Write-Host "  4. Push tag: git push origin v$Version" -ForegroundColor White
} else {
    Write-Host "  3. Push git tag: git push origin v$Version" -ForegroundColor White
}

Write-Host "  $(if ($CreateTag) { '4' } else { '5' }). Go to GitHub > Releases > Create Release" -ForegroundColor White
Write-Host "  $(if ($CreateTag) { '5' } else { '6' }). Upload ZIP: $zipName" -ForegroundColor White
Write-Host "  $(if ($CreateTag) { '6' } else { '7' }). Copy release notes from: GITHUB_RELEASE_NOTES.txt" -ForegroundColor White

Write-Host "`n🔗 GitHub Release URL:" -ForegroundColor Yellow
Write-Host "  https://github.com/YOUR-ORG/Host-Evidence-Runner/releases/new" -ForegroundColor Cyan

Write-Host "`n============================================================================`n" -ForegroundColor Cyan

# Create a quick reference file for GitHub release creation
$quickRefPath = Join-Path $releaseDir "CREATE_GITHUB_RELEASE.txt"
@"
========================================
GitHub Release Creation Quick Reference
========================================

Release: v$Version
Date: $(Get-Date -Format "yyyy-MM-dd")

STEP 1: Push Git Tag (if not already done)
-------------------------------------------
git tag -a v$Version -m "Host Evidence Runner v$Version"
git push origin v$Version

STEP 2: Create Release on GitHub
-------------------------------------------
1. Navigate to: https://github.com/YOUR-ORG/Host-Evidence-Runner/releases/new
2. Choose tag: v$Version
3. Release title: Host Evidence Runner v$Version
4. Upload asset: $zipName (located in releases/ folder)
5. Copy/paste release notes from: GITHUB_RELEASE_NOTES.txt
6. Check "Set as latest release"
7. Click "Publish release"

STEP 3: Verify Release
-------------------------------------------
1. Download the ZIP from GitHub release page
2. Extract and verify contents
3. Test run: .\run-collector.ps1 -AnalystWorkstation "localhost"

========================================
"@ | Set-Content $quickRefPath -Encoding UTF8

Write-Host "💡 Quick reference guide created: $quickRefPath`n" -ForegroundColor Cyan
