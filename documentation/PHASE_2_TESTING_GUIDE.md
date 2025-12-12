# Phase 2 Testing Guide

**Version:** 1.0  
**Date:** December 12, 2025  
**Purpose:** Validate Phase 2 functionality on Windows Server 2016+

---

## Pre-Test Checklist

Before executing tests, ensure:

- ✅ PowerShell 5.0+ available
- ✅ Administrator access on test system
- ✅ Phase 1 tools installed (in tools/bins/)
- ✅ collect.ps1 enhanced with Phase 2 code
- ✅ Test system has internet browsers installed (Chrome, Firefox, Edge)
- ✅ At least 2-5 GB free disk space
- ✅ Test system has event log data (natural from daily use)
- ✅ Test system has scheduled tasks

---

## Test Environment Setup

### **Option A: Virtual Machine (Recommended)**

1. Create VM snapshot before testing
   ```powershell
   # This allows easy rollback if needed
   ```

2. Install browsers on test VM:
   - Microsoft Edge (pre-installed on Server 2019+)
   - Google Chrome (https://www.google.com/chrome/)
   - Mozilla Firefox (https://www.mozilla.org/firefox/)

3. Create test data:
   ```powershell
   # Visit some websites to create history
   # Create some files and shortcuts
   # Create custom scheduled task for testing
   ```

4. System information:
   ```powershell
   # Document baseline for comparison
   Get-ComputerInfo | Export-Csv test_baseline.csv
   Get-ChildItem C:\Windows\Prefetch | Measure-Object | Select-Object Count
   ```

### **Option B: Physical Server**

1. Coordinate with system owner
2. Get written authorization
3. Document baseline state
4. Plan for minimal disruption

---

## Test Execution Steps

### **Step 1: Prepare Test Environment**

```powershell
# Create test directory
$testDir = "C:\Cado_Phase2_Test"
mkdir $testDir
cd $testDir

# Copy collection script and tools
Copy-Item -Path "D:\path\to\Cado-Batch\source\collect.ps1" -Destination $testDir
Copy-Item -Path "D:\path\to\Cado-Batch\tools\bins" -Destination $testDir\bins -Recurse

# Verify Phase 1 tools exist
Get-ChildItem $testDir\bins\*.exe | Select-Object Name, Length
```

**Expected Output:**
```
Name                Length
────                ──────
hashdeep.exe        789504
strings.exe         369664
sigcheck.exe        445440
RawCopy.exe         727040
zip.exe             135168
hashdeep64.exe      867840
strings64.exe       478720
sigcheck64.exe      540160
```

---

### **Step 2: Create Test User Data**

```powershell
# Create test browsing history
# Open Edge and visit: https://github.com, https://microsoft.com, https://www.nist.gov

# Open Chrome and visit same sites
# Open Firefox and visit same sites

# This ensures browser databases are created and populated

# Create test files in Documents
New-Item -Path "$env:USERPROFILE\Documents\Test_File_1.txt" -Value "Test content" -Force
New-Item -Path "$env:USERPROFILE\Documents\Test_File_2.txt" -Value "More test" -Force
```

---

### **Step 3: Execute Collection Script**

```powershell
# Run with verbose output to see Phase 2 execution
cd $testDir
./collect.ps1 -Verbose

# Alternatively, enable logging:
# The script automatically creates: logs\forensic_collection_*.txt
```

**Expected Duration:** 3-10 minutes depending on system

---

### **Step 4: Verify Phase 1 Completion**

Check Phase 1 was successful before Phase 2 validation:

```powershell
# Check output directory exists
Test-Path ".\collected_files"           # Should be TRUE

# Check SHA256 manifest (Phase 1 tool)
Test-Path ".\collected_files\SHA256_MANIFEST.txt"  # Should be TRUE
Get-Content ".\collected_files\SHA256_MANIFEST.txt" | Select-Object -First 10

# Check signatures (Phase 1 tool)
Test-Path ".\collected_files\ExecutableSignatures.txt"  # Should be TRUE

# Count collected files
(Get-ChildItem ".\collected_files" -Recurse).Count  # Should be 200+
```

**Success Criteria (Phase 1):**
- ✅ collected_files/ directory exists
- ✅ SHA256_MANIFEST.txt contains hashes
- ✅ ExecutableSignatures.txt contains signatures
- ✅ 200+ files collected from system

---

## Phase 2 Validation

### **Test 1: Browser History Extraction**

**Purpose:** Verify Chrome, Firefox, Edge browser data collection

```powershell
# Check Phase 2 output directory
Test-Path ".\collected_files\Phase2_Advanced_Analysis"  # Should be TRUE

# Check Chrome data
$chromeFiles = Get-ChildItem ".\collected_files\Phase2_Advanced_Analysis" -Filter "Chrome_History_*"
Write-Host "Chrome databases found: $($chromeFiles.Count)"

# List Chrome profiles collected
$chromeFiles | Select-Object Name, Length | Format-Table

# Verify Chrome database is real SQLite
Get-Content ".\collected_files\Phase2_Advanced_Analysis\Chrome_History_Default.db" -Encoding Byte -ReadCount 16 | Select-Object -First 1 | ForEach-Object {
    $header = [System.Text.Encoding]::ASCII.GetString($_[0..15])
    if ($header -like "SQLite format 3*") {
        Write-Host "✓ Valid SQLite database" -ForegroundColor Green
    }
}
```

**Expected Output:**
```
Chrome databases found: 2-4  (depends on profiles)

Name                           Length
────                           ──────
Chrome_History_Default.db      1048576
Chrome_History_Default.txt     256
Chrome_History_Profile1.db     1048576
Chrome_History_Profile1.txt    256
```

**Success Criteria:**
- ✅ Chrome_History_*.db files exist
- ✅ Database files are >1 MB (contain data)
- ✅ Files are valid SQLite format

---

### **Test 2: Firefox History Extraction**

```powershell
# Check Firefox profile data
$firefoxFiles = Get-ChildItem ".\collected_files\Phase2_Advanced_Analysis" -Filter "Firefox_History_*"
Write-Host "Firefox databases found: $($firefoxFiles.Count)"

# List Firefox data
$firefoxFiles | Select-Object Name, Length | Format-Table

# Verify Firefox database format
if ($firefoxFiles) {
    $fileSize = (Get-Item $firefoxFiles[0].FullName).Length
    Write-Host "Firefox database size: $fileSize bytes" -ForegroundColor Green
    if ($fileSize -gt 100000) {
        Write-Host "✓ Firefox database appears populated" -ForegroundColor Green
    }
}
```

**Expected Output:**
```
Firefox databases found: 1-2  (depends on profiles)

Name                              Length
────                              ──────
Firefox_History_[profile].db      2097152
```

**Success Criteria:**
- ✅ Firefox_History_*.db files exist
- ✅ Database files are >100 KB
- ✅ Files copied successfully

---

### **Test 3: Prefetch Analysis**

```powershell
# Check prefetch analysis exists
$prefetchAnalysis = ".\collected_files\Phase2_Advanced_Analysis\Prefetch_Analysis.txt"
Test-Path $prefetchAnalysis  # Should be TRUE

# View analysis report
Write-Host "`n=== PREFETCH ANALYSIS REPORT ===" -ForegroundColor Cyan
Get-Content $prefetchAnalysis | Select-Object -First 30
Write-Host "`n..."
Get-Content $prefetchAnalysis | Select-Object -Last 5

# Count prefetch files collected
$prefetchFiles = Get-ChildItem ".\collected_files\Phase2_Advanced_Analysis\Prefetch_Files" -Filter "*.pf" -ErrorAction SilentlyContinue
Write-Host "`nPrefetch files collected: $($prefetchFiles.Count)" -ForegroundColor Green
```

**Expected Output:**
```
PREFETCH FILE ANALYSIS
Generated: 2025-12-12 14:30:22
Total Prefetch Files: 487

EXPLORER.EXE | Modified: 2025-12-12 10:15:23 | Size: 23456 bytes
POWERSHELL.EXE | Modified: 2025-12-12 11:22:11 | Size: 34567 bytes
CMD.EXE | Modified: 2025-12-12 09:45:30 | Size: 19234 bytes
... (487 total files)

Prefetch files collected: 487
```

**Success Criteria:**
- ✅ Prefetch_Analysis.txt exists and readable
- ✅ Report shows file count >100
- ✅ Prefetch_Files/ directory contains .pf files
- ✅ Collected files >400 (500+ typical)

---

### **Test 4: Amcache Extraction**

```powershell
# Check Amcache hive
$amcache = ".\collected_files\Phase2_Advanced_Analysis\Amcache.hve"
Test-Path $amcache  # Should be TRUE if collected

if (Test-Path $amcache) {
    $fileSize = (Get-Item $amcache).Length
    Write-Host "Amcache size: $fileSize bytes" -ForegroundColor Green
    
    if ($fileSize -gt 1000000) {
        Write-Host "✓ Amcache appears intact and populated" -ForegroundColor Green
    } else {
        Write-Host "⚠ Amcache appears small (possible lock during collection)" -ForegroundColor Yellow
    }
}
```

**Expected Output:**
```
Amcache size: 15728640 bytes
✓ Amcache appears intact and populated
```

**Success Criteria:**
- ✅ Amcache.hve exists
- ✅ File size >10 MB (populated)
- ✅ File is readable (no corruption)

**Note:** If Amcache locked, RawCopy.exe should have copied it. Check log for details.

---

### **Test 5: SRUM Database Extraction**

```powershell
# Check SRUM database
$srum = ".\collected_files\Phase2_Advanced_Analysis\SRUM_Database.dat"
Test-Path $srum  # Should be TRUE if collected

if (Test-Path $srum) {
    $fileSize = (Get-Item $srum).Length
    Write-Host "SRUM database size: $fileSize bytes" -ForegroundColor Green
    
    if ($fileSize -gt 100000) {
        Write-Host "✓ SRUM database appears populated" -ForegroundColor Green
    }
} else {
    Write-Host "⚠ SRUM not collected (may be locked by system)" -ForegroundColor Yellow
}
```

**Expected Output:**
```
SRUM database size: 5242880 bytes
✓ SRUM database appears populated
```

**Success Criteria:**
- ✅ SRUM_Database.dat exists (or logged as locked)
- ✅ File size >100 KB if collected
- ✅ Graceful handling if locked

---

### **Test 6: Suspicious Scheduled Tasks**

```powershell
# Check task analysis report
$taskAnalysis = ".\collected_files\Phase2_Advanced_Analysis\Suspicious_Scheduled_Tasks.txt"
Test-Path $taskAnalysis  # Should be TRUE

# View analysis
Write-Host "`n=== SUSPICIOUS TASKS ANALYSIS ===" -ForegroundColor Cyan
Get-Content $taskAnalysis | Head -20
Write-Host "`n..."
Get-Content $taskAnalysis | Tail -10

# Check detection pattern
$content = Get-Content $taskAnalysis -Raw
$suspiciousCount = ([regex]::Matches($content, 'SUSPICIOUS TASK FOUND')).Count
Write-Host "`nSuspicious tasks flagged: $suspiciousCount" -ForegroundColor Yellow
```

**Expected Output:**
```
SUSPICIOUS SCHEDULED TASK ANALYSIS
Generated: 2025-12-12 14:35:00

SUMMARY
Total Tasks Analyzed: 247
Suspicious Tasks Found: 0-5  (varies per system)
```

**Success Criteria:**
- ✅ Suspicious_Scheduled_Tasks.txt exists
- ✅ File contains task analysis
- ✅ Summary shows total tasks analyzed >100
- ✅ Correctly identifies suspicious patterns (PowerShell, CMD, etc.)

**Note:** May show 0 suspicious tasks if system is clean (expected).

---

### **Test 7: Browser Artifacts Collection**

```powershell
# Check browser artifact directories
$edgeArtifacts = Test-Path ".\collected_files\Phase2_Advanced_Analysis\BrowserArtifacts_Edge"
$ieArtifacts = Test-Path ".\collected_files\Phase2_Advanced_Analysis\BrowserArtifacts_InternetExplorer"

Write-Host "Edge artifacts collected: $edgeArtifacts" -ForegroundColor $(if ($edgeArtifacts) {'Green'} else {'Yellow'})
Write-Host "IE artifacts collected: $ieArtifacts" -ForegroundColor $(if ($ieArtifacts) {'Green'} else {'Yellow'})

# List collected browser cache
if ($edgeArtifacts) {
    $edgeFiles = Get-ChildItem ".\collected_files\Phase2_Advanced_Analysis\BrowserArtifacts_Edge" -Recurse
    Write-Host "Edge files collected: $($edgeFiles.Count)" -ForegroundColor Green
}

if ($ieArtifacts) {
    $ieFiles = Get-ChildItem ".\collected_files\Phase2_Advanced_Analysis\BrowserArtifacts_InternetExplorer" -Recurse
    Write-Host "IE files collected: $($ieFiles.Count)" -ForegroundColor Green
}
```

**Expected Output:**
```
Edge artifacts collected: True
IE artifacts collected: True
Edge files collected: 45-200  (varies)
IE files collected: 10-50     (varies)
```

**Success Criteria:**
- ✅ BrowserArtifacts directories exist
- ✅ Collected >10 files per browser if installed
- ✅ Includes cache, bookmarks, history

---

## Complete Phase 2 Validation Script

```powershell
# Run all Phase 2 tests with summary
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         PHASE 2 VALIDATION SUMMARY                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$results = @()

# Test 1: Phase 2 directory exists
$phase2Dir = ".\collected_files\Phase2_Advanced_Analysis"
$test1 = Test-Path $phase2Dir
$results += @{ Test = "Phase 2 Directory"; Result = $test1 }
Write-Host "Phase 2 directory exists: $test1" -ForegroundColor $(if ($test1) {'Green'} else {'Red'})

# Test 2: Chrome data
$chrome = (Get-ChildItem $phase2Dir -Filter "Chrome_History_*.db" -ErrorAction SilentlyContinue).Count -gt 0
$results += @{ Test = "Chrome History"; Result = $chrome }
Write-Host "Chrome history collected: $chrome" -ForegroundColor $(if ($chrome) {'Green'} else {'Yellow'})

# Test 3: Firefox data
$firefox = (Get-ChildItem $phase2Dir -Filter "Firefox_History_*.db" -ErrorAction SilentlyContinue).Count -gt 0
$results += @{ Test = "Firefox History"; Result = $firefox }
Write-Host "Firefox history collected: $firefox" -ForegroundColor $(if ($firefox) {'Green'} else {'Yellow'})

# Test 4: Prefetch analysis
$prefetch = Test-Path "$phase2Dir\Prefetch_Analysis.txt"
$prefetchCount = (Get-ChildItem "$phase2Dir\Prefetch_Files" -Filter "*.pf" -ErrorAction SilentlyContinue).Count
$results += @{ Test = "Prefetch Analysis"; Result = $prefetch }
Write-Host "Prefetch analysis exists: $prefetch ($prefetchCount files)" -ForegroundColor $(if ($prefetch) {'Green'} else {'Yellow'})

# Test 5: Amcache
$amcache = Test-Path "$phase2Dir\Amcache.hve"
$results += @{ Test = "Amcache Data"; Result = $amcache }
Write-Host "Amcache extracted: $amcache" -ForegroundColor $(if ($amcache) {'Green'} else {'Yellow'})

# Test 6: SRUM
$srum = Test-Path "$phase2Dir\SRUM_Database.dat"
$results += @{ Test = "SRUM Database"; Result = $srum }
Write-Host "SRUM extracted: $srum" -ForegroundColor $(if ($srum) {'Green'} else {'Yellow'})

# Test 7: Task analysis
$tasks = Test-Path "$phase2Dir\Suspicious_Scheduled_Tasks.txt"
$results += @{ Test = "Task Analysis"; Result = $tasks }
Write-Host "Task analysis created: $tasks" -ForegroundColor $(if ($tasks) {'Green'} else {'Yellow'})

# Test 8: Browser artifacts
$edgeBrowser = Test-Path "$phase2Dir\BrowserArtifacts_Edge"
$ieBrowser = Test-Path "$phase2Dir\BrowserArtifacts_InternetExplorer"
$results += @{ Test = "Browser Artifacts"; Result = ($edgeBrowser -or $ieBrowser) }
Write-Host "Browser artifacts collected: Edge=$edgeBrowser, IE=$ieBrowser" -ForegroundColor Green

# Summary
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    SUMMARY                             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$passed = ($results | Where-Object { $_.Result -eq $true }).Count
$total = $results.Count

Write-Host "Tests Passed: $passed / $total" -ForegroundColor $(if ($passed -eq $total) {'Green'} else {'Yellow'})

if ($passed -eq $total) {
    Write-Host "`n✓ PHASE 2 VALIDATION SUCCESSFUL" -ForegroundColor Green
} else {
    Write-Host "`n⚠ Phase 2 partially successful - some components missing" -ForegroundColor Yellow
    Write-Host "  This may be normal if some data sources don't exist on this system" -ForegroundColor Gray
}
```

---

## Troubleshooting

### **Issue: Chrome history not collected**

**Possible Causes:**
- Chrome was running during collection
- Chrome profiles in non-standard location
- User profile not accessible

**Solutions:**
```powershell
# 1. Close all Chrome processes
Get-Process chrome | Stop-Process -Force

# 2. Check Chrome data location
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
Test-Path $chromePath
Get-ChildItem $chromePath

# 3. Try collection again
./collect.ps1
```

---

### **Issue: Prefetch files not collected**

**Possible Causes:**
- Prefetch disabled on system
- Permission issues accessing C:\Windows\Prefetch
- System freshly booted (no prefetch data yet)

**Solutions:**
```powershell
# Check if prefetch is enabled
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"

# Check prefetch directory
Get-ChildItem C:\Windows\Prefetch -Filter "*.pf" | Measure-Object
```

---

### **Issue: Amcache/SRUM not collected**

**Causes:** These files are locked by the system

**Solution:** 
- Ensure RawCopy.exe is in bins/ directory
- Check collection log for RawCopy success/failure
- This is expected behavior; log documents the issue

---

## Post-Test Analysis

### **Step 1: Generate Timeline**

```powershell
# If plaso/log2timeline is installed:
python -m plaso.tools.log2timeline \
    .\analysis_timeline.plaso \
    .\collected_files\EventLogs\
    .\collected_files\Phase2_Advanced_Analysis\
```

### **Step 2: Analyze Browser History**

```powershell
# Use optional tools to parse browser databases
# See PHASE_2_TOOLS_INSTALLATION.md for specific tools
```

### **Step 3: Review Prefetch Timeline**

```powershell
# Run WinPrefetchView on collected files
WinPrefetchView.exe /prefetchdir ".\collected_files\Phase2_Advanced_Analysis\Prefetch_Files"
```

---

## Success Criteria Summary

✅ **Phase 2 is SUCCESSFUL if:**
- All Phase 1 tests pass
- Browser history databases collected (Chrome or Firefox or Edge)
- Prefetch analysis report generated
- 400+ prefetch files collected
- Suspicious task analysis report generated
- At least 1 optional database collected (Amcache/SRUM)

⚠️ **Phase 2 is PARTIAL if:**
- Phase 1 passes
- Most but not all browser data collected
- Prefetch data present but minimal
- Databases locked (logged in collection log)

❌ **Phase 2 FAILED if:**
- Phase 2 directory missing entirely
- No Phase 2 output files created
- Collection script error during Phase 2 section

---

## Test Report Template

```
PHASE 2 TESTING REPORT
═════════════════════════════════════════════
System: [HostName]
OS Version: [Windows Server Version]
Test Date: [YYYY-MM-DD HH:MM:SS]
Tester: [Name]

PHASE 1 RESULTS:
✓ Event logs collected: [Y/N]
✓ Registry collected: [Y/N]
✓ Prefetch collected: [Y/N]
✓ LNK files collected: [Y/N]

PHASE 2 RESULTS:
✓ Chrome history: [Y/N]
✓ Firefox history: [Y/N]
✓ Prefetch analysis: [Y/N]
✓ Amcache: [Y/N]
✓ SRUM: [Y/N]
✓ Task analysis: [Y/N]

TOTAL FILES COLLECTED: [Number]
TOTAL SIZE: [GB]
COLLECTION DURATION: [Minutes]

ISSUES ENCOUNTERED:
[Any problems noted]

OVERALL RESULT: [PASS / PARTIAL / FAIL]

Notes:
[Additional observations]

Tester Signature: _________________ Date: __________
```

---

## Document Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-12 | Initial Phase 2 testing guide |

---

**Ready for deployment testing.** Follow this guide before pushing Phase 2 to production.
