@echo off
REM ============================================================================
REM Host Evidence Runner (HER) - Forensic Collection Launcher
REM Batch wrapper with fallback support for restricted environments
REM ============================================================================


setlocal enabledelayedexpansion


REM Change to script directory - must happen before any other operations
pushd "%~dp0" 2>nul
if errorlevel 1 (
    pause
    exit /b 1
)


REM ============================================================================
REM Check for Administrator Privileges
REM ============================================================================

openfiles >nul 2>&1
set ADMIN_CHECK=%ERRORLEVEL%

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

color 0A
title Host Evidence Runner - Starting Collection
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

echo Checking PowerShell availability
powershell -NoProfile -Command "Write-Host 'PowerShell OK'" >nul 2>&1
set PS_CHECK=%ERRORLEVEL%

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

echo Checking for required files

if not exist "run-collector.ps1" (
    color 0C
    echo.
    echo ============================================================================
    echo ERROR: Collection Script Missing
    echo ============================================================================
    echo.
    echo The file "run-collector.ps1" was not found in the current directory.
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

echo Required files verified.
echo.

REM ============================================================================
REM Analyst Workstation Parameter (defaults to localhost)
REM ============================================================================

set /p analyst_ws="Enter analyst workstation hostname (default: localhost): "

REM If user pressed Enter without input, use localhost as default
if "!analyst_ws!"=="" set "analyst_ws=localhost"

set "ANALYST_PARAM=-AnalystWorkstation '!analyst_ws!'"
echo.
echo Files will be transferred to: !analyst_ws!
if "!analyst_ws!"=="localhost" (
    echo Destination: C:\Temp\Investigations\%COMPUTERNAME%\[timestamp]
) else (
    echo Destination: \\!analyst_ws!\c$\Temp\Investigations\%COMPUTERNAME%\[timestamp]
)
echo.

REM ============================================================================
REM Start Collection
REM ============================================================================

echo.
echo ============================================================================
echo Starting collection
echo.
echo Please DO NOT close this window until collection completes!
echo Progress will be displayed below.
echo ============================================================================
echo.
echo Press any key to start the collection process
pause >nul

echo.
echo.
echo Running collection script
echo Command: powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-collector.ps1" !ANALYST_PARAM!
echo.

REM Execute the PowerShell collection script
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-collector.ps1" !ANALYST_PARAM!

set COLLECTION_RESULT=%ERRORLEVEL%
echo.
echo PowerShell exited with code: %COLLECTION_RESULT%
echo.

REM ============================================================================
REM Display Results
REM ============================================================================

echo.
echo ============================================================================

if %COLLECTION_RESULT% EQU 0 (
    color 0A
    echo.
    echo   COLLECTION COMPLETED SUCCESSFULLY!
    echo.
    echo ============================================================================
    echo.
    echo Output location: investigations\%COMPUTERNAME%\[timestamp]
    echo.
    if not "!analyst_ws!"=="" (
        echo Files have been transferred to: !analyst_ws!
        echo.
    )
    echo Next steps:
    echo   1. Review the COLLECTION_SUMMARY.txt for any warnings
    if "!analyst_ws!"=="" (
        echo   2. Copy the investigation folder to secure storage
        echo   3. Provide to analyst for review
    ) else (
        echo   2. Verify files arrived at analyst workstation
        echo   3. Securely delete local copy after confirmation
    )
    echo.
) else (
    color 0E
    echo.
    echo   COLLECTION COMPLETED WITH ERRORS
    echo.
    echo ============================================================================
    echo.
    echo Exit code: %COLLECTION_RESULT%
    echo.
    echo Please review the log file in investigations\%COMPUTERNAME%\[timestamp]
    echo and provide it to your analyst for troubleshooting.
    echo.
)

echo ============================================================================
echo.
echo Press any key to close this window
pause >nul
popd
exit /b %COLLECTION_RESULT%
