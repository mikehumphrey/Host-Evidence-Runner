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
    .\Build-Release.ps1 -OutputDir "E:\Cado-Batch-Collector" -Sign
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)] [string]$OutputDir,
    [Parameter(Mandatory=$false)] [switch]$Zip,
    [Parameter(Mandatory=$false)] [switch]$Sign
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

if (-not $OutputDir) { $OutputDir = Join-Path $root "releases\$timestamp" }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

Write-Host "Building minimal collector release to '$OutputDir'..." -ForegroundColor Yellow

# Layout
$layout = @(
    @{ src = Join-Path $root 'run-collector.ps1';                      dest = Join-Path $OutputDir 'run-collector.ps1' },
    @{ src = Join-Path $root 'RUN_COLLECT.bat';                        dest = Join-Path $OutputDir 'RUN_COLLECT.bat' },
    @{ src = Join-Path $root 'source\collect.ps1';                     dest = Join-Path $OutputDir 'source\collect.ps1' },
    @{ src = Join-Path $root 'tools\bins';                             dest = Join-Path $OutputDir 'tools\bins' },
    @{ src = Join-Path $root 'templates';                               dest = Join-Path $OutputDir 'templates' },
    @{ src = Join-Path $root 'README.md';                               dest = Join-Path $OutputDir 'README.md' },
    @{ src = Join-Path $root 'RELEASE_NOTES.md';                       dest = Join-Path $OutputDir 'RELEASE_NOTES.md' },
    @{ src = Join-Path $root 'docs\sysadmin\ANALYST_WORKSTATION_GUIDE.md'; dest = Join-Path $OutputDir 'docs\ANALYST_WORKSTATION_GUIDE.md' },
    @{ src = Join-Path $root 'LICENSE';                                 dest = Join-Path $OutputDir 'LICENSE' },
    @{ src = Join-Path $root 'NOTICE';                                  dest = Join-Path $OutputDir 'NOTICE' }
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
        (Join-Path $OutputDir 'run-collector.ps1')
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
