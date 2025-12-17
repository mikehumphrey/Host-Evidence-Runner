<#
.SYNOPSIS
    Test script to validate AnalystWorkstation parameter handling

.DESCRIPTION
    Tests the path construction and parameter passing logic for the AnalystWorkstation feature
    without running the full collection. Useful for validating localhost vs remote host logic.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$AnalystWorkstation = ""
)

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "AnalystWorkstation Parameter Test" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Parameter validation
Write-Host "Test 1: Parameter Validation" -ForegroundColor Yellow
Write-Host "  Input value: '$AnalystWorkstation'" -ForegroundColor White

if ($AnalystWorkstation -and $AnalystWorkstation.Trim()) {
    Write-Host "  Result: VALID (non-empty after trim)" -ForegroundColor Green
    $normalizedHost = $AnalystWorkstation.Trim() -replace '\\\\', '' -replace '\\', ''
    Write-Host "  Normalized: '$normalizedHost'" -ForegroundColor White
} else {
    Write-Host "  Result: INVALID (empty or whitespace)" -ForegroundColor Red
    Write-Host "  Action: Parameter would be skipped" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Test 2: Host type detection
Write-Host "Test 2: Host Type Detection" -ForegroundColor Yellow
$computerName = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$isLocalhost = $false
if ($normalizedHost -eq 'localhost' -or $normalizedHost -eq '127.0.0.1' -or $normalizedHost -eq $env:COMPUTERNAME) {
    $isLocalhost = $true
    Write-Host "  Detected: LOCALHOST" -ForegroundColor Green
    Write-Host "    Matches: localhost, 127.0.0.1, or $env:COMPUTERNAME" -ForegroundColor White
} else {
    Write-Host "  Detected: REMOTE HOST" -ForegroundColor Cyan
    Write-Host "    Target: $normalizedHost" -ForegroundColor White
}

Write-Host ""

# Test 3: Path construction
Write-Host "Test 3: Destination Path Construction" -ForegroundColor Yellow

if ($isLocalhost) {
    $destinationPath = "C:\Temp\Investigations\$computerName\$timestamp"
    Write-Host "  Type: Local filesystem path" -ForegroundColor Green
} else {
    $destinationPath = "\\$normalizedHost\c`$\Temp\Investigations\$computerName\$timestamp"
    Write-Host "  Type: UNC path (network share)" -ForegroundColor Cyan
}

Write-Host "  Full path: $destinationPath" -ForegroundColor White

Write-Host ""

# Test 4: Connectivity check (if remote)
Write-Host "Test 4: Network Connectivity" -ForegroundColor Yellow

if ($isLocalhost) {
    Write-Host "  Skipped: Localhost does not require network check" -ForegroundColor Green
} else {
    Write-Host "  Testing connection to $normalizedHost..." -ForegroundColor White
    try {
        $pingResult = Test-Connection -ComputerName $normalizedHost -Count 1 -Quiet -ErrorAction Stop
        if ($pingResult) {
            Write-Host "  Result: SUCCESS - Host is reachable" -ForegroundColor Green
        } else {
            Write-Host "  Result: FAILED - Host is not responding to ping" -ForegroundColor Red
            Write-Host "  Note: Collection would still attempt transfer" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Result: ERROR - Cannot test connection" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

Write-Host ""

# Test 5: Directory creation simulation
Write-Host "Test 5: Directory Creation Check" -ForegroundColor Yellow

$destParent = Split-Path $destinationPath -Parent
Write-Host "  Parent directory: $destParent" -ForegroundColor White

if ($isLocalhost) {
    $tempRoot = "C:\Temp"
    if (Test-Path $tempRoot) {
        Write-Host "  C:\Temp exists: YES" -ForegroundColor Green
    } else {
        Write-Host "  C:\Temp exists: NO (would be created)" -ForegroundColor Yellow
    }
}

if (Test-Path $destParent) {
    Write-Host "  Parent exists: YES" -ForegroundColor Green
} else {
    Write-Host "  Parent exists: NO (would be created)" -ForegroundColor Yellow
}

if (Test-Path $destinationPath) {
    Write-Host "  Full path exists: YES" -ForegroundColor Green
} else {
    Write-Host "  Full path exists: NO (would be created by robocopy)" -ForegroundColor Cyan
}

Write-Host ""

# Test 6: Robocopy command simulation
Write-Host "Test 6: Robocopy Command Construction" -ForegroundColor Yellow

$sourceRoot = "C:\temp\test_source"
$robocopyLog = Join-Path $destinationPath "ROBOCopyLog.txt"

Write-Host "  Source: $sourceRoot" -ForegroundColor White
Write-Host "  Destination: $destinationPath" -ForegroundColor White
Write-Host "  Log: $robocopyLog" -ForegroundColor White
Write-Host ""

# ZIP-only transfer
$robocopyZipCmd = "robocopy `"$sourceRoot`" `"$destinationPath`" collected_files.zip forensic_collection_*.txt COLLECTION_SUMMARY.txt /DCOPY:T /COPY:DAT /R:3 /W:5 /LOG+:`"$robocopyLog`" /TEE /NP"
Write-Host "  ZIP-only mode:" -ForegroundColor Cyan
Write-Host "    $robocopyZipCmd" -ForegroundColor White
Write-Host ""

# Full directory transfer
$robocopyFullCmd = "robocopy `"$sourceRoot`" `"$destinationPath`" /E /DCOPY:T /COPY:DAT /R:3 /W:5 /LOG+:`"$robocopyLog`" /TEE /NP"
Write-Host "  Full directory mode:" -ForegroundColor Cyan
Write-Host "    $robocopyFullCmd" -ForegroundColor White

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Parameter: $AnalystWorkstation" -ForegroundColor White
Write-Host "Normalized: $normalizedHost" -ForegroundColor White
Write-Host "Type: $(if ($isLocalhost) { 'Localhost' } else { 'Remote Host' })" -ForegroundColor White
Write-Host "Destination: $destinationPath" -ForegroundColor White
Write-Host ""

if ($isLocalhost) {
    Write-Host "Localhost Mode:" -ForegroundColor Green
    Write-Host "  ✓ Files will be copied to local C:\Temp directory" -ForegroundColor Green
    Write-Host "  ✓ No network transfer required" -ForegroundColor Green
    Write-Host "  ✓ Useful for testing or local analysis" -ForegroundColor Green
} else {
    Write-Host "Remote Host Mode:" -ForegroundColor Cyan
    Write-Host "  ✓ Files will be copied via UNC path to $normalizedHost" -ForegroundColor Cyan
    Write-Host "  ✓ Requires network connectivity and admin access to C$ share" -ForegroundColor Cyan
    Write-Host "  ✓ Standard deployment scenario" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
