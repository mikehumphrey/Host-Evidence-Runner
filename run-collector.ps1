#Requires -RunAsAdministrator
<#
.SYNOPSIS
    One-step launcher for Host Evidence Runner (HER) collection from the release root.

.DESCRIPTION
    Ensures execution from the script root and invokes `source\collect.ps1` with
    ExecutionPolicy Bypass. Designed for sysadmins running from USB or C:\temp.
    
    Derived from the archived Cado-Batch project; independently maintained.

.PARAMETER NoZip
    Skip compression of collected files. Useful for large collections (>4GB) to save time.

.PARAMETER AnalystWorkstation
    Hostname or IP of analyst workstation to copy collected files to via robocopy.
    Files will be copied to C$\Temp\Investigations\[Hostname]\[Timestamp]
    Example: -AnalystWorkstation "ITDL251263" or -AnalystWorkstation "localhost"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$NoZip,
    
    [Parameter(Mandatory=$false)]
    [string]$AnalystWorkstation
)

$ErrorActionPreference = 'Stop'

# Resolve root robustly: prefer $PSCommandPath, then $PSScriptRoot, then MyInvocation
$root = $null
if ($PSCommandPath) {
    $root = Split-Path -Parent $PSCommandPath
} elseif ($PSScriptRoot) {
    $root = $PSScriptRoot
} elseif ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Definition) {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

if (-not $root -or -not (Test-Path $root)) {
    Write-Host "Could not determine script root (invalid path)." -ForegroundColor Red
    exit 1
}

Set-Location -Path (Resolve-Path $root)

# Unblock files to prevent DLL initialization errors (files extracted from ZIP are often blocked)
Write-Host "Unblocking files (if needed)..." -ForegroundColor Cyan
try {
    Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
    Write-Host "Files unblocked successfully." -ForegroundColor Green
} catch {
    Write-Verbose "Could not unblock all files (may not be necessary): $_"
}

$collect = Join-Path $root 'source\collect.ps1'
if (-not (Test-Path $collect)) {
    Write-Host "collect.ps1 not found at $collect" -ForegroundColor Red
    exit 1
}

# Check if execution policy is blocking script execution
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
$systemPolicy = Get-ExecutionPolicy -Scope LocalMachine

if ($executionPolicy -eq 'Restricted' -or $systemPolicy -eq 'Restricted' -or 
    $executionPolicy -eq 'AllSigned' -or $systemPolicy -eq 'AllSigned') {
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host "EXECUTION POLICY RESTRICTION DETECTED" -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Current Execution Policy:" -ForegroundColor Yellow
    Write-Host "  CurrentUser: $executionPolicy" -ForegroundColor White
    Write-Host "  LocalMachine: $systemPolicy" -ForegroundColor White
    Write-Host ""
    Write-Host "PowerShell execution is restricted on this system." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To run the collector, use one of these methods:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Option 1 (Recommended):" -ForegroundColor Green
    Write-Host "    Run 'RUN_COLLECT.bat' instead - it bypasses the restriction" -ForegroundColor White
    Write-Host ""
    Write-Host "  Option 2:" -ForegroundColor Green
    Write-Host "    Right-click PowerShell -> Run as Administrator, then:" -ForegroundColor White
    Write-Host "    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process" -ForegroundColor White
    Write-Host "    .\run-collector.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "Starting collection from: $root" -ForegroundColor Cyan
if ($NoZip) {
    Write-Host "Compression will be skipped (-NoZip parameter)" -ForegroundColor Yellow
}
if ($AnalystWorkstation) {
    Write-Host "Files will be copied to analyst workstation: $AnalystWorkstation" -ForegroundColor Cyan
}

try {
    $collectArgs = @{
        RootPath = $root
        NoZip = $NoZip
        AnalystWorkstation = $AnalystWorkstation
    }
    
    # Remove empty parameters
    $collectArgs.Keys | Where-Object { -not $collectArgs[$_] -and $collectArgs[$_] -ne $false } | ForEach-Object { $collectArgs.Remove($_) }
    
    # Call collect.ps1 directly with proper parameter passing
    & $collect @collectArgs
    $exitCode = $LASTEXITCODE
} catch {
    Write-Host "Collection failed: $_" -ForegroundColor Red
    exit 1
}

if ($exitCode -ne 0) {
    Write-Host "collect.ps1 exited with code $exitCode" -ForegroundColor Yellow
    exit $exitCode
}

Write-Host "Collection completed." -ForegroundColor Green
exit 0
