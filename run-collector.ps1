#Requires -RunAsAdministrator
<#
.SYNOPSIS
    One-step launcher for Cado-Batch collection from the release root.

.DESCRIPTION
    Ensures execution from the script root and invokes `source\collect.ps1` with
    ExecutionPolicy Bypass. Designed for sysadmins running from USB or C:\temp.
#>

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -Path $root

$collect = Join-Path $root 'source\collect.ps1'
if (-not (Test-Path $collect)) {
    Write-Host "collect.ps1 not found at $collect" -ForegroundColor Red
    exit 1
}

Write-Host "Starting collection from: $root" -ForegroundColor Cyan

try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $collect -Verbose
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
