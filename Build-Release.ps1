<#
.SYNOPSIS
    Builds a minimal Host Evidence Runner (HER) release for sysadmins to run collection from USB or C:\temp.

.DESCRIPTION
    Packages only the necessary artifacts to run `collect.ps1` locally:
    - `run-collector.ps1` and `RUN_COLLECT.bat` (launchers at root)
    - `source/collect.ps1` (main collection script)
    - `tools/bins/*` (forensic tools used by collect.ps1; auto-resolved)
    - `templates/*` (metadata templates for investigations)
    - `README.md` (quick reference and usage guide)
    Excludes investigations, optional tools, analysis modules, and legacy scripts.

    Optionally signs scripts if a Code Signing certificate is available.

.PARAMETER OutputDir
    Destination folder for the release build artifacts (default: `releases/<timestamp>`)

.PARAMETER Zip
    Creates a zip file `HER-Collector.zip` in `releases/` for easy transfer.

.PARAMETER Sign
    Attempts to sign PowerShell scripts using an available Code Signing certificate.

.EXAMPLE
    .\Build-Release.ps1 -Zip -Sign

.EXAMPLE
    .\Build-Release.ps1 -OutputDir "E:\HER-Collector" -Sign
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)] [string]$OutputDir,
    [Parameter(Mandatory=$false)] [switch]$Zip,
    [Parameter(Mandatory=$false)] [switch]$Sign,
    [Parameter(Mandatory=$false)] [string]$Version
)


$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# Version handling
$releaseNotesPath = Join-Path $root 'RELEASE_NOTES.md'
function Get-CurrentVersion {
    if (Test-Path $releaseNotesPath) {
        $notes = Get-Content $releaseNotesPath -Raw
        if ($notes -match '(?m)^- \*\*Version\*\*:\s*(\d+\.\d+\.\d+)') {
            return $Matches[1]
        }
    }
    return '0.0.0'
}


# Updates version, date, and ID
function Set-NewVersion {
    param(
        [string]$newVersion,
        [string]$timestampParam
    )
    Write-Host "[DEBUG] Set-NewVersion called with newVersion: $newVersion" -ForegroundColor Yellow
    Write-Host "[DEBUG] releaseNotesPath: $releaseNotesPath" -ForegroundColor Yellow
    try {
        $content = Get-Content $releaseNotesPath -Raw
        $today = Get-Date -Format 'MMMM dd, yyyy'
        $releaseId = $timestampParam
        $updated = $content
        $updated = $updated -replace '(?m)^\s*- \*\*Version\*\*:\s*\d+\.\d+\.\d+', "- **Version**: $newVersion"
        $updated = $updated -replace '(?m)^\s*- \*\*Release Date\*\*:\s*.+$', "- **Release Date**: $today"
        $updated = $updated -replace '(?m)^\s*- \*\*Release ID\*\*:\s*.+$', "- **Release ID**: $releaseId"
        Write-Host "[DEBUG] Updated content preview (first 300 chars):" -ForegroundColor Yellow
        Write-Host ($updated.Substring(0, [Math]::Min(300, $updated.Length))) -ForegroundColor Gray
        Set-Content $releaseNotesPath $updated -ErrorAction Stop
        Write-Host "[DEBUG] RELEASE_NOTES.md updated successfully." -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to update RELEASE_NOTES.md: $_" -ForegroundColor Red
        throw
    }
}

# Only updates date and ID, not version
function Set-ReleaseDateAndId {
    param([string]$timestampParam)
    Write-Host "[DEBUG] Set-ReleaseDateAndId called" -ForegroundColor Yellow
    Write-Host "[DEBUG] releaseNotesPath: $releaseNotesPath" -ForegroundColor Yellow
    try {
        $content = Get-Content $releaseNotesPath -Raw
        $today = Get-Date -Format 'MMMM dd, yyyy'
        $releaseId = $timestampParam
        $updated = $content
        $updated = $updated -replace '(?m)^\s*- \*\*Release Date\*\*:\s*.+$', "- **Release Date**: $today"
        $updated = $updated -replace '(?m)^\s*- \*\*Release ID\*\*:\s*.+$', "- **Release ID**: $releaseId"
        Write-Host "[DEBUG] Updated content preview (first 300 chars):" -ForegroundColor Yellow
        Write-Host ($updated.Substring(0, [Math]::Min(300, $updated.Length))) -ForegroundColor Gray
        Set-Content $releaseNotesPath $updated -ErrorAction Stop
        Write-Host "[DEBUG] RELEASE_NOTES.md updated successfully (date/ID only)." -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to update RELEASE_NOTES.md: $_" -ForegroundColor Red
        throw
    }
}

if (-not $Version) {
    $currentVersion = Get-CurrentVersion
    Write-Host "Current version: $currentVersion" -ForegroundColor Cyan
    $prompt = "Would you like to increment the version number? (Y/N) [N]: "
    $response = Read-Host $prompt
    if ($response -eq 'Y' -or $response -eq 'y') {
        # Increment patch version (X.Y.Z -> X.Y.(Z+1))
        $parts = $currentVersion -split '\.'
        if ($parts.Length -eq 3) {
            $parts[2] = [int]$parts[2] + 1
            $newVersion = "$($parts[0]).$($parts[1]).$($parts[2])"
            Set-NewVersion $newVersion $timestamp
            Write-Host "Version updated to: $newVersion" -ForegroundColor Green
            $Version = $newVersion
        } else {
            Write-Warning "Could not parse current version. Using $currentVersion."
            $Version = $currentVersion
            Set-ReleaseDateAndId $timestamp
        }
    } else {
        $Version = $currentVersion
        Write-Host "Using current version: $Version" -ForegroundColor Yellow
        Set-ReleaseDateAndId $timestamp
    }
}

if (-not $OutputDir) { $OutputDir = Join-Path $root "releases\$timestamp" }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

Write-Host "Building minimal collector release to '$OutputDir' (Version: $Version)..." -ForegroundColor Yellow

# Layout
$layout = @(
    @{ src = Join-Path $root 'run-collector.ps1';                      dest = Join-Path $OutputDir 'run-collector.ps1' },
    @{ src = Join-Path $root 'run-silent.ps1';                         dest = Join-Path $OutputDir 'run-silent.ps1' },
    @{ src = Join-Path $root 'RUN_COLLECT.bat';                        dest = Join-Path $OutputDir 'RUN_COLLECT.bat' },
    @{ src = Join-Path $root 'source\collect.ps1';                     dest = Join-Path $OutputDir 'source\collect.ps1' },
    @{ src = Join-Path $root 'tools\bins';                             dest = Join-Path $OutputDir 'tools\bins' },
    @{ src = Join-Path $root 'templates';                              dest = Join-Path $OutputDir 'templates' },
    @{ src = Join-Path $root 'README.md';                              dest = Join-Path $OutputDir 'README.md' },
    @{ src = Join-Path $root 'RELEASE_NOTES.md';                       dest = Join-Path $OutputDir 'RELEASE_NOTES.md' },
    @{ src = Join-Path $root 'docs\sysadmin\COLLECTION_SUCCESS_GUIDE.md'; dest = Join-Path $OutputDir 'docs\COLLECTION_GUIDE.md' },
    @{ src = Join-Path $root 'docs\sysadmin\QUICK_START.txt';          dest = Join-Path $OutputDir 'docs\QUICK_START.txt' },
    @{ src = Join-Path $root 'LICENSE';                                dest = Join-Path $OutputDir 'LICENSE' },
    @{ src = Join-Path $root 'NOTICE';                                 dest = Join-Path $OutputDir 'NOTICE' },
    @{ src = Join-Path $root '00_START_HERE.md';                       dest = Join-Path $OutputDir '00_START_HERE.md' }
)

foreach ($item in $layout) {
    if (Test-Path $item.src) {
        $destParent = Split-Path $item.dest -Parent
        if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent -Force | Out-Null }
        Copy-Item -Path $item.src -Destination $item.dest -Recurse -Force
        Write-Host "  Copied: $($item.src) -> $($item.dest)" -ForegroundColor Gray
    } else {
        Write-Warning "Missing source item: $($item.src)"
    }
}

# Optional: Sign scripts
if ($Sign) {
    Write-Host "Attempting to sign scripts..." -ForegroundColor Cyan
    $scriptsToSign = @(
        (Join-Path $OutputDir 'source\collect.ps1'),
        (Join-Path $OutputDir 'run-collector.ps1'),
        (Join-Path $OutputDir 'run-silent.ps1')
    )
    # Find a code signing certificate in CurrentUser or LocalMachine
    $cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
    if (-not $cert) { $cert = Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert | Select-Object -First 1 }
    if ($cert) {
        foreach ($s in $scriptsToSign) {
            if (Test-Path $s) {
                try {
                    Set-AuthenticodeSignature -FilePath $s -Certificate $cert | Out-Null
                    Write-Host "  Signed: $s" -ForegroundColor Green
                } catch { Write-Warning ("  Failed to sign {0}: {1}" -f $s, $_.Exception.Message) }
            }
        }
    } else {
        Write-Warning "No Code Signing certificate found. Skipping signing."
    }
}

# Optional: Create zip
if ($Zip) {
    $zipName = Join-Path (Join-Path $root 'releases') 'HER-Collector.zip'
    if (-not (Test-Path (Split-Path $zipName -Parent))) { New-Item -ItemType Directory -Path (Split-Path $zipName -Parent) -Force | Out-Null }
    if (Test-Path $zipName) { Remove-Item $zipName -Force }
    Write-Host "Creating zip: $zipName" -ForegroundColor Cyan
    Compress-Archive -Path (Join-Path $OutputDir '*') -DestinationPath $zipName -Force
    Write-Host "Release zip created: $zipName" -ForegroundColor Green
}

Write-Host "Release build complete." -ForegroundColor Green
