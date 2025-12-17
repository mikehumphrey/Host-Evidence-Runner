#Requires -RunAsAdministrator

Write-Host "Test Script Started" -ForegroundColor Green
Write-Host "Current Location: $(Get-Location)" -ForegroundColor Cyan

# Test 1: Check if tools exist
$toolsPath = "C:\Temp\HER-Collector\tools\bins\RawCopy.exe"
if (Test-Path $toolsPath) {
    Write-Host "✓ Tools directory found: $toolsPath" -ForegroundColor Green
} else {
    Write-Host "✗ Tools directory NOT found: $toolsPath" -ForegroundColor Red
    Write-Host "Contents of C:\Temp\HER-Collector:" -ForegroundColor Yellow
    Get-ChildItem "C:\Temp\HER-Collector" -Recurse -Depth 2 | Select-Object FullName
}

# Test 2: Check if source\collect.ps1 exists
$collectScript = "C:\Temp\HER-Collector\source\collect.ps1"
if (Test-Path $collectScript) {
    Write-Host "✓ Collect script found: $collectScript" -ForegroundColor Green
} else {
    Write-Host "✗ Collect script NOT found: $collectScript" -ForegroundColor Red
}

# Test 3: Try to call collect.ps1 with explicit error handling
Write-Host "`nAttempting to run collect.ps1..." -ForegroundColor Cyan
try {
    $collectArgs = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', 'C:\Temp\HER-Collector\source\collect.ps1',
        '-RootPath', 'C:\Temp\HER-Collector',
        '-Verbose'
    )
    
    Write-Host "PowerShell command: powershell $($collectArgs -join ' ')" -ForegroundColor Yellow
    
    & powershell @collectArgs
    
    $exitCode = $LASTEXITCODE
    Write-Host "`nCollect.ps1 exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })
    
    if ($exitCode -eq -1073741502) {
        Write-Host "`nError Analysis:" -ForegroundColor Yellow
        Write-Host "Exit code -1073741502 (0xC0000142) = STATUS_DLL_INIT_FAILED" -ForegroundColor Red
        Write-Host "This usually means:" -ForegroundColor Yellow
        Write-Host "  1. An executable (like RawCopy.exe) failed to load" -ForegroundColor White
        Write-Host "  2. A required DLL is missing or blocked" -ForegroundColor White
        Write-Host "  3. Files need to be unblocked after extraction from ZIP" -ForegroundColor White
        Write-Host "`nTrying to unblock files..." -ForegroundColor Cyan
        Get-ChildItem "C:\Temp\HER-Collector" -Recurse | Unblock-File -ErrorAction SilentlyContinue
        Write-Host "Files unblocked. Try running again." -ForegroundColor Green
    }
    
} catch {
    Write-Host "Exception caught: $_" -ForegroundColor Red
    Write-Host "Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
}

Write-Host "`nPress Enter to close..."
Read-Host
