@echo off
REM ============================================================================
REM Cado-Batch Forensic Collection Tool
REM End-User Launcher Batch Script
REM 
REM This script is designed to be run by system administrators with
REM no technical knowledge of forensics or PowerShell.
REM ============================================================================

setlocal enabledelayedexpansion
cd /d "%~dp0"

REM Color codes and formatting
color 0A
title Forensic Collection Tool - Running...

REM ============================================================================
REM Check for Administrator Privileges
REM ============================================================================

openfiles >nul 2>&1
if errorlevel 1 (
    echo.
    echo ============================================================================
    echo ERROR: This tool requires Administrator privileges
    echo ============================================================================
    echo.
    echo Please run this script as Administrator:
    echo.
    echo 1. Right-click on RUN_ME.bat
    echo 2. Select "Run as administrator"
    echo 3. Click "Yes" when Windows asks for permission
    echo.
    echo If you continue to have problems, contact your IT department.
    echo.
    pause
    exit /b 1
)

REM ============================================================================
REM Initialize Logging
REM ============================================================================

for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c%%a%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)
set "LOGFILE=FORENSIC_COLLECTION_LOG.txt"

if exist "%LOGFILE%" (
    ren "%LOGFILE%" "%LOGFILE%.backup"
)

(
    echo ============================================================================
    echo Forensic Collection Tool - Execution Log
    echo ============================================================================
    echo Started: %mydate% %mytime%
    echo Computer: %COMPUTERNAME%
    echo User: %USERNAME%
    echo Script Location: %~dp0
    echo.
) > "%LOGFILE%"

REM ============================================================================
REM Display Welcome Message
REM ============================================================================

cls
echo.
echo ============================================================================
echo.
echo          FORENSIC COLLECTION TOOL
echo.
echo          Server: %COMPUTERNAME%
echo          Started: %mydate% %mytime%
echo.
echo ============================================================================
echo.
echo This tool will collect forensic data from your server.
echo.
echo What will be collected:
echo   - System configuration and event logs
echo   - File system metadata
echo   - Active Directory information (if applicable)
echo   - Network configuration
echo   - Registry settings
echo.
echo Estimated time: 15-30 minutes
echo Data size: 500MB - 5GB
echo Impact: Read-only, does not modify any files
echo.
echo ============================================================================
echo.
echo Collection is starting...
echo Please DO NOT close this window until you see "Collection Complete!"
echo.
pause

REM ============================================================================
REM Verify PowerShell is available
REM ============================================================================

echo Checking PowerShell availability... >> "%LOGFILE%"
powershell -NoProfile -Command "Write-Host 'PowerShell available'" >nul 2>&1
if errorlevel 1 (
    echo.
    echo ============================================================================
    echo ERROR: PowerShell is not available or disabled
    echo ============================================================================
    echo.
    echo PowerShell is required to run this collection tool.
    echo.
    echo Please contact your IT department and inform them:
    echo "PowerShell execution is disabled on this server"
    echo.
    echo They may need to enable PowerShell execution policy to continue.
    echo.
    echo ============================================================================
    echo.
    >> "%LOGFILE%" echo ERROR: PowerShell not available or disabled
    >> "%LOGFILE%" echo Collection cannot proceed without PowerShell
    pause
    exit /b 1
)

echo PowerShell verified successfully >> "%LOGFILE%"
echo.

REM ============================================================================
REM Verify required script exists
REM ============================================================================

echo Checking for collection script... >> "%LOGFILE%"
if not exist "collect.ps1" (
    echo.
    echo ============================================================================
    echo ERROR: Collection script not found
    echo ============================================================================
    echo.
    echo The file "collect.ps1" is missing.
    echo.
    echo Please ensure you copied the entire Cado-Batch folder to your USB drive.
    echo The folder should contain:
    echo   - RUN_ME.bat
    echo   - collect.ps1
    echo   - bins\ folder
    echo.
    echo Contact the analyst who provided this tool for assistance.
    echo.
    echo ============================================================================
    echo.
    >> "%LOGFILE%" echo ERROR: collect.ps1 not found in %CD%
    >> "%LOGFILE%" echo Folder contents:
    dir >> "%LOGFILE%" 2>&1
    pause
    exit /b 1
)

echo Collection script verified >> "%LOGFILE%"

REM ============================================================================
REM Create logs subdirectory if needed
REM ============================================================================

if not exist "logs" (
    mkdir "logs"
)

REM ============================================================================
REM Execute PowerShell Collection Script
REM ============================================================================

echo.
echo Starting forensic collection (this may take 15-30 minutes)...
echo.
>> "%LOGFILE%" echo.
>> "%LOGFILE%" echo ============================================================================
>> "%LOGFILE%" echo PowerShell Script Execution
>> "%LOGFILE%" echo ============================================================================
>> "%LOGFILE%" echo.

REM Run the PowerShell script and capture output
powershell -NoProfile -ExecutionPolicy Bypass -File "collect.ps1" -Verbose >> "%LOGFILE%" 2>&1

if errorlevel 1 (
    >> "%LOGFILE%" echo.
    >> "%LOGFILE%" echo WARNING: PowerShell script exited with error code %ERRORLEVEL%
) else (
    >> "%LOGFILE%" echo.
    >> "%LOGFILE%" echo Collection script completed successfully
)

REM ============================================================================
REM Verify Output
REM ============================================================================

echo.
echo Verifying collected data...
>> "%LOGFILE%" echo.
>> "%LOGFILE%" echo Verifying output...

if exist "collected_files" (
    echo Output folder created successfully
    >> "%LOGFILE%" echo Output folder "collected_files" created successfully
    >> "%LOGFILE%" echo.
    dir /s collected_files >> "%LOGFILE%" 2>&1
) else (
    echo WARNING: Output folder not found
    >> "%LOGFILE%" echo WARNING: Expected output folder "collected_files" not found
)

REM ============================================================================
REM Display Completion Message
REM ============================================================================

echo.
echo ============================================================================
echo.
echo     COLLECTION COMPLETE!
echo.
echo ============================================================================
echo.
echo What to do next:
echo.
echo 1. Disconnect the USB drive from this server
echo 2. Connect the USB drive to your computer
echo 3. Copy the folder "collected_files*" to return to analyst
echo 4. Also copy "FORENSIC_COLLECTION_LOG.txt" 
echo 5. Send both to the analyst who provided this tool
echo.
echo ============================================================================
echo.
>> "%LOGFILE%" echo ============================================================================
>> "%LOGFILE%" echo Collection process completed
>> "%LOGFILE%" echo Timestamp: %mydate% %mytime%
>> "%LOGFILE%" echo ============================================================================

REM ============================================================================
REM Compression Option (if user wants smaller output)
REM ============================================================================

echo Would you like to compress the collected data?
echo This will make it smaller and faster to transfer.
echo.
set /p compress="Compress data? (Y/N): "

if /i "%compress%"=="Y" (
    echo.
    echo Compressing collected files...
    >> "%LOGFILE%" echo Compressing collected files...
    
    if exist "collected_files.zip" (
        del collected_files.zip
    )
    
    REM PowerShell compression command
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Compress-Archive -Path 'collected_files' -DestinationPath 'collected_files.zip' -Force; Write-Host 'Compression successful' } catch { Write-Host 'Compression failed: $_' }" >> "%LOGFILE%" 2>&1
    
    if exist "collected_files.zip" (
        echo.
        echo Compression complete! File size:
        powershell -NoProfile -Command "'{0:N2} MB' -f ((Get-Item 'collected_files.zip').Length / 1MB)"
        >> "%LOGFILE%" echo Compression successful
        >> "%LOGFILE%" echo Compressed archive: collected_files.zip
    ) else (
        echo Compression failed - data will be transferred uncompressed
        >> "%LOGFILE%" echo Compression failed - data will be transferred uncompressed
    )
)

echo.
echo ============================================================================
echo.
echo Please return the following to the analyst:
echo   - collected_files folder (or collected_files.zip if compressed)
echo   - FORENSIC_COLLECTION_LOG.txt
echo.
echo If you have questions or encountered errors, provide the contents of
echo FORENSIC_COLLECTION_LOG.txt to the analyst.
echo.
echo ============================================================================
echo.

pause
exit /b 0
