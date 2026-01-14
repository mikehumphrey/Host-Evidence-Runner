@echo off
REM ============================================================================
REM Host Evidence Runner (HER) - Forensic Collection Launcher
REM Batch wrapper with fallback support for restricted environments
REM ============================================================================

echo [DEBUG] Script started at %DATE% %TIME%
echo [DEBUG] Raw script path: %~dp0
echo [DEBUG] Script name: %~nx0
echo [DEBUG] Current directory before any changes: %CD%

setlocal enabledelayedexpansion

echo [DEBUG] After setlocal - CD is: %CD%

REM Change to script directory - must happen before any other operations
echo [DEBUG] Attempting pushd to: "%~dp0"
pushd "%~dp0" 2>nul
if errorlevel 1 (
    echo [ERROR] pushd failed with result: %ERRORLEVEL%
    echo [ERROR] Cannot access script directory
    echo [ERROR] Directory: %~dp0
    pause
    exit /b 1
)

echo [DEBUG] pushd successful
echo [DEBUG] Current directory after pushd: %CD%

REM ============================================================================
REM Check for Administrator Privileges
REM ============================================================================

echo [DEBUG] Checking admin privileges
openfiles >nul 2>&1
set ADMIN_CHECK=%ERRORLEVEL%
echo [DEBUG] Admin check result: %ADMIN_CHECK%

if errorlevel 1 (
    color 0C
    echo.
    echo ============================================================================
    echo ERROR: Administrator Privileges Required
    echo ============================================================================
    echo.
    echo This tool requires Administrator privileges to collect forensic data.
    echo.
    echo To fix this:
    echo   1. Right-click on RUN_COLLECT.bat
    echo   2. Select "Run as administrator"
    echo   3. Click "Yes" when Windows asks for permission
    echo.
    echo If you continue to have problems, contact your IT department.
    echo.
    pause
    exit /b 1
)

REM ============================================================================
REM Display Welcome Banner
REM ============================================================================

echo [DEBUG] Admin check passed, displaying banner
color 0A
title Host Evidence Runner - Starting Collection
echo [DEBUG] About to clear screen (cls)
REM cls - DISABLED FOR DEBUGGING
echo.
echo ============================================================================
echo.
echo          HOST EVIDENCE RUNNER (HER)
echo          Forensic Collection Tool
echo.
echo          Server: %COMPUTERNAME%
echo          User: %USERNAME%
echo.
echo ============================================================================
echo.
echo This tool will collect forensic artifacts from this system.
echo.
echo What will be collected:
echo   - System event logs and registry hives
echo   - File system metadata (MFT, USN Journal)
echo   - User activity artifacts (browser history, prefetch)
echo   - Network configuration and security settings
echo   - Server role-specific data (AD, DNS, IIS, etc.)
echo.
echo Estimated time: 15-45 minutes (depending on system size)
echo Impact: Read-only collection, no modifications made
echo.
echo ============================================================================
echo.

REM ============================================================================
REM Verify PowerShell Availability
REM ============================================================================

echo [DEBUG] Starting PowerShell check
echo Checking PowerShell availability
powershell -NoProfile -Command "Write-Host 'PowerShell OK'" >nul 2>&1
set PS_CHECK=%ERRORLEVEL%
echo [DEBUG] PowerShell check result: %PS_CHECK%

if errorlevel 1 (
    color 0C
    echo.
    echo ============================================================================
    echo ERROR: PowerShell Not Available
    echo ============================================================================
    echo.
    echo PowerShell is required but appears to be disabled or unavailable.
    echo.
    echo Please contact your IT department with this error message.
    echo They may need to enable PowerShell execution on this system.
    echo.
    pause
    exit /b 1
)

echo PowerShell verified successfully.
echo.

REM ============================================================================
REM Verify Required Files
REM ============================================================================

echo [DEBUG] Starting file verification
echo [DEBUG] Current directory: %CD%
echo [DEBUG] Listing all files in current directory:
dir /b
echo [DEBUG] End of file listing
echo.

echo Checking for required files
set "ROOT=%~dp0"
set "COLLECTOR=%ROOT%run-collector.ps1"
echo [DEBUG] Looking for: %COLLECTOR%

if exist "%COLLECTOR%" (
    echo [DEBUG] SUCCESS: run-collector.ps1 FOUND at %COLLECTOR%
    echo Required files verified.
    echo.
) else (
    color 0C
    echo.
    echo ============================================================================
    echo ERROR: Collection Script Missing
    echo ============================================================================
    echo.
    echo The file "run-collector.ps1" was not found.
    echo Expected location: %COLLECTOR%
    echo Current directory: %CD%
    echo.
    echo Please ensure you copied the complete HER toolkit.
    echo The folder should contain:
    echo   - RUN_COLLECT.bat (this file)
    echo   - run-collector.ps1
    echo   - source\ folder
    echo   - tools\ folder
    echo.
    echo Contact the analyst who provided this tool for assistance.
    echo.
    pause
    exit /b 1
)

REM ============================================================================
REM Analyst Workstation Parameter (defaults to localhost)
REM ============================================================================

echo [DEBUG] Reached analyst workstation prompt section
set /p analyst_ws="Enter analyst workstation hostname (default: localhost): "
echo [DEBUG] User entered: [!analyst_ws!]

REM If user pressed Enter without input, use localhost as default
if "!analyst_ws!"=="" set "analyst_ws=localhost"
echo [DEBUG] After default check, analyst_ws is: [!analyst_ws!]
@echo off
REM Archived: use RUN_COLLECT.bat in this directory.
call "%~dp0RUN_COLLECT.bat" %*
echo.
