# Phase 2 Tools Installation Guide

**Purpose:** Document and guide installation of optional Phase 2 analysis tools  
**Status:** Phase 2 code integrated into collect.ps1  
**Date:** December 12, 2025

---

## Overview

Phase 2 automatically extracts:
- ✅ Chrome browser history and profiles
- ✅ Firefox history and profiles
- ✅ Prefetch file analysis
- ✅ SRUM (System Resource Usage Monitor) database
- ✅ Amcache program execution history
- ✅ Suspicious scheduled task detection
- ✅ Edge and IE browser artifacts

**No additional tools required for basic Phase 2 functionality.** The code is built into `collect.ps1` and uses native PowerShell capabilities.

---

## Phase 2 Data Collection (Automatic)

### 1. **Browser History Extraction**

**What's Collected:**
- Chrome User Data directory with all profiles
- Chrome History SQLite database (per profile)
- Firefox profile databases (places.sqlite)
- Edge bookmarks and browsing data
- IE cache and cookie containers

**Output Location:**
```
collected_files/Phase2_Advanced_Analysis/
├── Chrome_History_Default.db (SQLite database)
├── Chrome_History_Default.txt (metadata)
├── Chrome_History_Profile1.db
├── Chrome_History_Profile1.txt
├── Firefox_History_[profile].db
├── BrowserArtifacts_Edge/
│   ├── Default/
│   │   ├── Bookmarks
│   │   ├── History
│   │   └── Cache/
│   └── ...
└── BrowserArtifacts_InternetExplorer/
    └── (IE cache and cookies)
```

**Forensic Value:** ⭐⭐⭐⭐⭐
- Web activity timeline
- Visited websites and bookmarks
- Search queries (often in history)
- Form data (passwords, etc.)

---

### 2. **Prefetch File Analysis**

**What's Collected:**
- All prefetch (.pf) files from `C:\Windows\Prefetch\`
- Human-readable analysis report
- Last execution times for each program

**Output Location:**
```
collected_files/Phase2_Advanced_Analysis/
├── Prefetch_Analysis.txt (summary report)
├── Prefetch_Files/
│   ├── EXPLORER.EXE-[hash].pf
│   ├── POWERSHELL.EXE-[hash].pf
│   ├── NOTEPAD.EXE-[hash].pf
│   └── ... (500+ files)
```

**Forensic Value:** ⭐⭐⭐⭐
- Program execution timeline (last 8 executions per program)
- System reconnaissance tools used
- Persistence mechanism programs
- Dates of execution

**Optional External Analysis:**

To parse .pf files into detailed timelines, use one of these tools:

#### **WinPrefetchView** (Recommended - Free)
```
Download: https://www.nirsoft.net/utils/win_prefetch_view.html
Unzip to: tools/optional/WinPrefetchView/
Usage: WinPrefetchView.exe /prefetchdir ".\collected_files\Phase2_Advanced_Analysis\Prefetch_Files"
Output: HTML/CSV with execution times and program paths
```

#### **PECmd** (SANS Toolkit)
```
Download: https://github.com/EricZimmerman/PECmd/releases
Location: tools/optional/PECmd/
Usage: PECmd.exe -d ".\collected_files\Phase2_Advanced_Analysis\Prefetch_Files" --csv .
Output: CSV with detailed prefetch analysis
```

---

### 3. **SRUM Database Extraction**

**What's Collected:**
- System Resource Usage Monitor database
- Tracks CPU, memory, network per application
- Timeline data for system activity

**Output Location:**
```
collected_files/Phase2_Advanced_Analysis/SRUM_Database.dat
```

**Forensic Value:** ⭐⭐⭐
- Application resource usage over time
- Network traffic per application
- CPU and memory spikes
- Timeline correlation data

**Optional External Analysis:**

#### **SRUM Dump** (open-source)
```
Download: https://github.com/MarkBaggett/srum-dump
Usage: python srum_dump.py -r ".\SRUM_Database.dat"
Output: CSV with resource usage timeline
```

---

### 4. **Amcache Program Execution History**

**What's Collected:**
- Application Compatibility Cache (Amcache.hve)
- Program execution history (days/weeks back)
- File associations and execution paths

**Output Location:**
```
collected_files/Phase2_Advanced_Analysis/Amcache.hve
```

**Forensic Value:** ⭐⭐⭐⭐
- Long-term program execution history
- Programs executed before prefetch enabled
- Files accessed by applications
- Installation history

**Optional External Analysis:**

#### **AmcacheParser** (Recommended)
```
Download: https://github.com/EricZimmerman/AmcacheParser/releases
Location: tools/optional/AmcacheParser/
Usage: AmcacheParser.exe -f ".\Amcache.hve" --csv .
Output: CSV with program execution timeline
```

---

### 5. **Suspicious Scheduled Task Detection**

**What's Collected:**
- Analysis of all scheduled task XML files
- Suspicious task identification
- Command patterns detected
- Task modification timestamps

**Output Location:**
```
collected_files/Phase2_Advanced_Analysis/Suspicious_Scheduled_Tasks.txt
```

**Forensic Value:** ⭐⭐⭐⭐
- Persistence mechanisms
- Lateral movement indicators
- Credential theft via scheduled tasks
- Anomalous automation

**Detection Patterns (Built-in):**
- PowerShell execution
- CMD.exe execution
- WScript/CScript execution
- MSHTA execution
- Regsvr32 (DLL sideloading)
- Rundll32 (proxy execution)
- Certutil (certificate/file operations)
- BitsAdmin (background file download)
- Curl/Wget (file download)
- Temp directory references

---

## External Analysis Tools (Optional Post-Processing)

These tools are **not required** for collection but useful for analyzing Phase 2 output:

### **Browser History Analysis**

**BrowserHistoryView** (NirSoft)
```
URL: https://www.nirsoft.net/utils/browsing_history_view.html
Purpose: Parse browser history from raw databases
Supported: Chrome, Firefox, Edge, IE
```

### **Prefetch Analysis**

**WinPrefetchView** (NirSoft)
```
URL: https://www.nirsoft.net/utils/win_prefetch_view.html
Purpose: Human-readable prefetch timeline
```

**PECmd** (Eric Zimmerman Tools)
```
URL: https://github.com/EricZimmerman/PECmd
Purpose: Detailed prefetch parsing with timestamps
```

### **Registry Analysis** (for Amcache data stored in registry)

**RegRipper**
```
URL: https://github.com/keydet89/RegRipper3.0
Purpose: Parse registry hives for activity artifacts
```

### **Overall Timeline Analysis**

**Plaso/log2timeline**
```
URL: https://github.com/log2timeline/plaso
Purpose: Create master timeline from all collected artifacts
Supports: Event logs, prefetch, browser history, MFT, etc.
```

---

## Phase 2 Implementation Details

### Automatic Functions

All Phase 2 data is collected automatically by functions in `collect.ps1`:

1. **Export-ChromeHistory**
   - Locates all Chrome profiles
   - Copies History SQLite database
   - Creates metadata files

2. **Export-FirefoxHistory**
   - Finds Firefox profiles
   - Extracts places.sqlite database
   - Preserves profile structure

3. **Export-PrefetchAnalysis**
   - Lists all .pf files
   - Generates human-readable summary
   - Copies files for external parsing

4. **Export-SRUMData**
   - Attempts to copy SRUM database
   - Uses RawCopy.exe if available
   - Handles locked file exceptions

5. **Export-AmcacheData**
   - Extracts Amcache.hve registry hive
   - Uses RawCopy.exe for locked files
   - Preserves binary format for parsing

6. **Export-SuspiciousScheduledTasks**
   - Scans all scheduled task XML files
   - Identifies suspicious patterns
   - Generates analysis report

7. **Export-BrowserArtifacts**
   - Collects Edge and IE artifacts
   - Copies cache and cookies
   - Preserves directory structure

---

## Data Size Expectations

| Component | Size | Items |
|-----------|------|-------|
| Chrome profiles | 50-200 MB | 1-4 profiles |
| Firefox profiles | 20-100 MB | 1-2 profiles |
| Prefetch files | 5-20 MB | 500+ files |
| Edge artifacts | 50-150 MB | Cache + Bookmarks |
| IE artifacts | 20-50 MB | Cache + History |
| SRUM database | 10-50 MB | 1 file |
| Amcache | 10-30 MB | 1 file |
| Task analysis | 0.5-2 MB | 1 report |
| **Total** | **~200-600 MB** | **~700+ items** |

---

## Verification Checklist

After running `collect.ps1`, verify Phase 2 completed:

```powershell
# Check Phase 2 output directory
Test-Path ".\collected_files\Phase2_Advanced_Analysis\"

# Verify Chrome data
Test-Path ".\collected_files\Phase2_Advanced_Analysis\Chrome_History_*.db"

# Verify Firefox data
Test-Path ".\collected_files\Phase2_Advanced_Analysis\Firefox_History_*.db"

# Verify Prefetch analysis
Test-Path ".\collected_files\Phase2_Advanced_Analysis\Prefetch_Analysis.txt"
Test-Path ".\collected_files\Phase2_Advanced_Analysis\Prefetch_Files\"

# Verify Amcache
Test-Path ".\collected_files\Phase2_Advanced_Analysis\Amcache.hve"

# Verify SRUM
Test-Path ".\collected_files\Phase2_Advanced_Analysis\SRUM_Database.dat"

# Verify task analysis
Test-Path ".\collected_files\Phase2_Advanced_Analysis\Suspicious_Scheduled_Tasks.txt"
```

---

## Troubleshooting

### Issue: Browser databases are empty or locked

**Cause:** Browser was running during collection
**Solution:** 
- Request collection on freshly booted system
- Or collect data with investigator present to close browsers
- Raw databases are still captured for offline analysis

### Issue: SRUM/Amcache not found

**Cause:** Database files locked by system
**Solution:**
- Ensure RawCopy.exe is in `bins/` directory
- Check logs for specific error messages
- Data is optional; collection continues without it

### Issue: Prefetch files incomplete

**Cause:** Prefetch disabled on system
**Solution:**
- Not critical; event logs provide timeline alternative
- Some older systems have disabled prefetch
- Check Group Policy: `gpedit.msc` → Admin Templates → System

---

## Phase 2 vs Phase 3 Comparison

| Aspect | Phase 2 | Phase 3 |
|--------|---------|---------|
| **Scope** | Historical artifacts | Volatile data |
| **Data Type** | Files and databases | Memory/network |
| **Persistence** | Survives reboot | Lost on reboot |
| **Collection Time** | Seconds-minutes | Minutes |
| **Analysis Tools** | Parsers | Debuggers/network tools |
| **Status** | ✅ Implemented | 🔵 Planned |

---

## Integration with Investigations

Phase 2 data should be analyzed in context of:

1. **Event Logs** (Phase 1)
   - Cross-reference timestamps
   - Identify user activity correlation
   - Track privileged operations

2. **Registry** (Phase 1)
   - User recent items
   - Network connections history
   - Installed programs/versions

3. **Prefetch** (Phase 2)
   - Program execution timeline
   - Suspicious tools used
   - Malware execution attempts

4. **Browser History** (Phase 2)
   - Command and control domains
   - Credential theft sites
   - Lateral movement indicators

5. **Scheduled Tasks** (Phase 2)
   - Persistence mechanisms
   - Automated threat activity
   - Lateral movement via automation

---

## Document Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-12 | Initial Phase 2 tools documentation |

---

**For Questions:** Review CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md for forensic value reasoning
