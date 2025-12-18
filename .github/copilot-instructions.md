# Host Evidence Runner (HER) - AI Agent Instructions

## Project Overview
**HER** is a forensic evidence collection and analysis toolkit for Windows incident response. Derived from Cado-Batch, it deploys from USB/network shares to collect 400+ Windows artifacts and perform post-collection analysis.

**Primary Users:** System administrators (deployment) and forensic analysts (analysis)  
**License:** Apache 2.0 | **Version:** 1.0.1

## Architecture & Components

### Three-Tier Structure
1. **Launchers** (`run-collector.ps1`, `RUN_COLLECT.bat`) - Handle execution policy and admin elevation
2. **Collection Engine** (`source/collect.ps1`) - 1800+ line forensic collection script
3. **Analysis Engine** (`source/Analyze-Investigation.ps1` + `modules/CadoBatchAnalysis/`) - Post-collection parsing

### Critical Path Resolution Pattern
Tools live at `tools/bins/` in releases. Scripts auto-resolve using fallback logic:
```powershell
# See source/collect.ps1 lines 119-160
Resolve-BinPath checks: source/bins → tools/bins → bins/
Get-BinFile prefers 64-bit: hashdeep64.exe > hashdeep.exe
```
**Never hardcode bin paths.** Use `Get-BinFile "toolname.exe"` to leverage 32/64-bit selection.

### Output Structure
```
investigations/
  └── [HOSTNAME]/
      └── [TIMESTAMP]/
          ├── collected_files/       # Raw artifacts
          ├── collected_files.zip    # Optional compression
          ├── forensic_collection_*.txt   # Main log
          ├── COLLECTION_SUMMARY.txt
          └── manifest_*.txt         # SHA256 hashes
```

## Development Workflows

### Building Releases
```powershell
.\Build-Release.ps1 -Zip [-Sign]
# Output: releases/<timestamp>/ and releases/HER-Collector.zip
# Excludes: docs/historical/, tests/, tools/optional/, .git/
```

### Testing
```powershell
# Test collection locally (analyst workstation must exist or use localhost)
.\run-collector.ps1 -AnalystWorkstation "localhost" -Verbose

# Test analyst workstation parameter logic
.\tests\Test-AnalystWorkstation.ps1 -AnalystWorkstation "analyst-pc"

# Test collection on remote hosts
.\source\deploy_multi_server.ps1 -Servers "dc01.domain.com","file01.domain.com"
```

### Running Collection
- **Standard:** `.\run-collector.ps1 -AnalystWorkstation "analyst-pc"`
- **Large collections:** Add `-NoZip` to skip compression
- **Restricted environments:** Use `RUN_COLLECT.bat` (bypasses execution policy)

## Project-Specific Conventions

### Error Handling Philosophy
**Continue, don't abort.** `$ErrorActionPreference = 'Continue'` throughout. MAX_PATH errors log warnings but don't halt collection. See [RELEASE_NOTES.md](../RELEASE_NOTES.md) lines 10-17 for rationale.

```powershell
# Pattern from source/collect.ps1
try {
    # Collection operation
} catch {
    if ($_.Exception.Message -match "path.*too long|exceeds the maximum") {
        Write-Log "WARNING: MAX_PATH issue (non-fatal): $_" -Level Warning
        $script:collectionStats.Warnings++
    } else {
        Write-Log "ERROR: Fatal failure: $_" -Level Error
        throw  # Only fatal errors exit
    }
}
```

### Non-Interactive Execution
**Zero prompts.** Designed for Task Scheduler and automated deployment. Use `-AnalystWorkstation` parameter instead of interactive Read-Host. Set `$ProgressPreference = 'SilentlyContinue'`.

### Logging Standards
- Use `Write-Log` function with `-Level` parameter (Info/Warning/Error)
- Timestamps: `yyyyMMdd_HHmmss` format consistently
- Every major operation: log start/success/failure with artifact counts
- Example: `Write-Log "Collected 342 event logs (12 warnings, 2 errors)" -Level Info`

### Path Handling
Use `SafeJoinPath` (lines 88-116 in collect.ps1) to prevent array-to-string binding errors. OneDrive paths require special handling - use `pushd` in batch files instead of `cd`.

```powershell
# Correct
$path = SafeJoinPath $parent $child
$binFile = Get-BinFile "RawCopy.exe"

# Wrong
$path = Join-Path $parent $child  # Can fail with array parameters
$rawcopy = "$binPath\RawCopy.exe"  # Misses 32/64-bit logic
```

## Forensic Collection Details

### Role Detection
Script auto-detects server roles and collects specialized artifacts:
- **Domain Controller:** NTDS.dit, SYSVOL, AD logs
- **DNS Server:** Zone files, DNS debug logs  
- **IIS:** Web logs, applicationHost.config
- **Hyper-V:** VM configs, VMMS logs
- **Print Server:** Spool files, print logs

Role detection: `Get-WindowsFeature` on Server, fallback to services on Win10/11.

### Tools Used
| Tool | Purpose | License File |
|------|---------|--------------|
| RawCopy.exe | Extract locked files ($MFT, registry) | tools/bins/RawCopy_LICENSE.md |
| hashdeep64.exe | SHA256 manifests | tools/bins/hashdeep_LICENSE.txt |
| sigcheck64.exe | Binary signatures | tools/bins/SysInternals_LICENSE.txt |
| zip.exe | Compression | tools/bins/Zip_License.txt |

**Optional tools** (not in releases): Zimmerman tools (EvtxECmd, MFTECmd, PECmd, RECmd) in `tools/optional/`. Used by analysis module.

### Zimmerman Tools Installation & Setup
Zimmerman tools are NOT included in releases. Download manually from https://ericzimmerman.github.io/#!index.md

```powershell
# Install Zimmerman tools to tools/optional/ZimmermanTools/
# Prefer net9 runtime versions, fallback to net8/net6
# Required .NET Desktop Runtime: https://dotnet.microsoft.com/download/dotnet/9.0

# Verify installation
Test-Path "tools/optional/ZimmermanTools/net9/MFTECmd.exe"
Test-Path "tools/optional/ZimmermanTools/net9/EvtxECmd.exe"
```

**Key tools for investigations:**
- **MFTECmd:** Parse $MFT for file system timeline, access patterns
- **EvtxECmd:** Parse event logs (.evtx) to CSV/JSON with filtering
- **PECmd:** Parse prefetch files for program execution history
- **RECmd:** Parse registry hives for typed URLs, recent docs, MRUs
- **LECmd:** Parse LNK files (recent items, jump lists)
- **JLECmd:** Parse jump lists for application-specific recent files

## Insider Threat Investigation Workflow

### Scenario: Privileged User Data Exfiltration
**Investigation Goal:** User with elevated privileges accessed sensitive files and uploaded to Google Drive, then shared with press (within past year).

**Collection Strategy:** Servers first (DC/DNS/DFS), then suspect workstations.

### Phase 1: Server Collection (DC, DNS, DFS)

```powershell
# Deploy to servers to establish baseline
.\source\deploy_multi_server.ps1 -Servers "dc01.domain.com","dns01.domain.com","dfs01.domain.com" `
    -AnalystWorkstation "analyst-pc"

# Critical artifacts collected from servers:
# - NTDS.dit (AD database) - user account activity, logons
# - SYSVOL - Group Policy changes, scripts
# - DFS metadata - file access patterns across shares
# - Event logs - 4663 (file access), 4656 (handle to object), 4624/4625 (logons)
# - DNS logs - google.com, googleapis.com, drive.google.com queries
```

**Server-Side Artifacts to Analyze:**
1. **Active Directory Logs (DC):**
   - Event ID 4663: File access auditing on sensitive shares
   - Event ID 4656: Handle to object (shows file opens)
   - Event ID 4624: Account logons (Type 3 = network, Type 10 = RDP)
   - Event ID 4688: Process creation (shows what apps user ran)

2. **DFS Replication Metadata:**
   - File access timestamps on DFS shares
   - Identify which files suspect user accessed

3. **DNS Query Logs:**
   - Queries to drive.google.com, googleapis.com
   - Correlate with file access times

### Phase 2: Workstation Collection (Suspect Hosts)

```powershell
# Collect from suspect's workstation(s)
.\run-collector.ps1 -AnalystWorkstation "analyst-pc" -Verbose

# Key artifacts for Google Drive exfiltration:
# - Browser history (Chrome/Edge) - drive.google.com activity
# - MFT - file access in Google Drive sync folder (C:\Users\[user]\Google Drive\)
# - Prefetch - GoogleDriveSync.exe, browser executables
# - Recent Items/Jump Lists - files opened before upload
# - Registry MRUs - recent documents, typed URLs
# - Event logs - 4663 (sensitive file access), 4688 (Chrome/Drive process launches)
```

### Phase 3: Analysis with Zimmerman Tools

#### 3.1 Parse Event Logs (File Access & Logons)
```powershell
# STEP 1: Parse event logs FIRST (this creates CSV files from .evtx)
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\WORKSTATION\20251218_120000" `
    -ParseEventLogs -EventLogFormat csv

# Output: Phase3_EventLog_Analysis/Security_parsed.csv, System_parsed.csv, etc.

# STEP 2: Search parsed logs for keywords and filter by Event IDs
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\WORKSTATION\20251218_120000" `
    -SearchKeywordsFile "sensitive_filenames.txt" -FilterEventIDs 4663,4656,4624,4688 -DetectSuspiciousPatterns

# Output: Phase3_Filtered_EventLog_Results.csv

# NOTE: Searching requires parsing first. You cannot search without -ParseEventLogs having run previously.
```

**Key Event IDs for Insider Threat:**
- **4663:** Object access (shows files opened/read/copied)
- **4656:** Handle to object (shows file access attempts)
- **4624:** Logon (Type 3=network, Type 10=RDP to servers)
- **4688:** Process creation (Chrome.exe, GoogleDriveSync.exe)
- **4689:** Process termination
- **7045:** New service installed (if suspect installed tools)

#### 3.2 MFT Analysis (File Access Timeline)
```powershell
# STEP 1: Parse MFT to create timeline CSV
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\WORKSTATION\20251218_120000" `
    -ParseMFT

# Output: Phase3_MFT_Analysis/MFT_Full.csv

# STEP 2: Search parsed MFT for sensitive file paths and Google Drive sync folder
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\WORKSTATION\20251218_120000" `
    -SearchMFTPaths "Google Drive","Downloads","Documents\Confidential" `
    -SearchMFTPathsFile "sensitive_paths.txt"

# Output: Phase3_MFT_PathMatches.csv

# NOTE: Searching MFT requires parsing first (-ParseMFT must have run previously).
```

**MFT Analysis Focus Areas:**
- **Google Drive Sync Folder:** `C:\Users\[user]\Google Drive\` or `C:\Users\[user]\AppData\Local\Google\Drive\`
- **Download Timestamps:** Files downloaded from servers before upload
- **File Modifications:** When files were accessed/modified before exfiltration
- **Deletion Evidence:** $MFT retains records even after file deletion

#### 3.3 Browser History Analysis (Google Drive Activity)
```powershell
# Analyze browser artifacts (already collected in UserActivity_Analysis/)
# Look for collected browser history files:
# - collected_files/UserActivity_Analysis/Chrome_History_Default.db
# - collected_files/UserActivity_Analysis/Edge_History_Default.db

# Manually query with SQLite or use LECmd for detailed analysis
# Key URLs to search:
# - drive.google.com/file/d/[ID]/view
# - drive.google.com/drive/folders/[ID]
# - docs.google.com/spreadsheets/d/[ID]
# - accounts.google.com/signin (authentication timestamps)
```

**Google Drive URL Patterns:**
- `drive.google.com/file/d/*` - File viewing
- `drive.google.com/drive/folders/*` - Folder browsing
- `docs.google.com/document/d/*` - Google Docs
- `docs.google.com/spreadsheets/d/*` - Google Sheets
- Upload activity: Look for POST requests to `drive.google.com/upload`

#### 3.4 Recent Files & Jump Lists (What Was Opened Before Upload)
```powershell
# Collected artifacts are in:
# collected_files/Users/[username]/Recent/

# Use LECmd (LNK parser) manually:
cd tools/optional/ZimmermanTools/net9
.\LECmd.exe -d "investigations\Case\WORKSTATION\20251218_120000\collected_files\Users\suspect\Recent" `
    --csv "investigations\Case\WORKSTATION\20251218_120000\Phase3_LNK_Analysis" `
    --csvf "Recent_Files.csv"

# Look for:
# - LNK files for sensitive documents opened before upload
# - Target paths pointing to DFS shares or local sensitive folders
# - Timestamps correlating with Google Drive access in browser history
```

#### 3.5 Prefetch Analysis (Program Execution)
```powershell
# Parse prefetch to identify when Chrome/Drive sync was used
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\WORKSTATION\20251218_120000" `
    -ParsePrefetch

# Or manually with PECmd:
cd tools/optional/ZimmermanTools/net9
.\PECmd.exe -d "investigations\Case\WORKSTATION\20251218_120000\collected_files\Prefetch" `
    --csv "investigations\Case\WORKSTATION\20251218_120000\Phase3_Prefetch_Analysis" `
    --csvf "Prefetch_Timeline.csv"

# Focus on:
# - CHROME.EXE-*.pf (last run time, execution count)
# - GOOGLEDRIVESYNC.EXE-*.pf (if Drive desktop app installed)
# - File paths accessed by these processes
```

#### 3.6 Registry Analysis (Typed URLs, Recent Docs, MRUs)
```powershell
# Parse registry hives for user activity evidence
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\WORKSTATION\20251218_120000" `
    -ParseRegistry

# Or manually with RECmd:
cd tools/optional/ZimmermanTools/net9

# Parse NTUSER.DAT for typed URLs and recent docs
.\RECmd.exe -f "investigations\Case\WORKSTATION\20251218_120000\collected_files\Users\suspect\NTUSER.DAT" `
    --bn "BatchExamples\TypedUrls.reb" `
    --csv "investigations\Case\WORKSTATION\20251218_120000\Phase3_Registry_Analysis" `
    --csvf "TypedUrls.csv"

# Parse for Office recent documents
.\RECmd.exe -f "investigations\Case\WORKSTATION\20251218_120000\collected_files\Users\suspect\NTUSER.DAT" `
    --bn "BatchExamples\OfficeMRU.reb" `
    --csv "investigations\Case\WORKSTATION\20251218_120000\Phase3_Registry_Analysis" `
    --csvf "Office_RecentDocs.csv"
```

**Registry Artifact Focus:**
- **TypedURLs:** `HKCU\Software\Microsoft\Internet Explorer\TypedURLs` - URLs typed in browser
- **Office MRUs:** Recent Office documents opened
- **RecentDocs:** `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs`
- **UserAssist:** Program execution counts and last run times
- **MountPoints2:** External drives/network shares accessed

### Phase 4: Timeline Reconstruction

```powershell
# Combine artifacts into timeline:
# 1. MFT timeline (file access on workstation)
# 2. Event logs (server-side file access, logons)
# 3. Browser history (Google Drive activity)
# 4. Prefetch (program execution)
# 5. Registry (recent documents, typed URLs)

# Look for temporal correlation:
# - File accessed on DFS share (Event ID 4663) at 2024-03-15 14:23:00
# - Same file in MFT with Modified time 2024-03-15 14:23:15
# - Chrome.exe execution in Prefetch at 2024-03-15 14:24:00
# - drive.google.com/upload in browser history at 2024-03-15 14:25:30
# - LNK file for document in Recent Items with timestamp 2024-03-15 14:23:00
```

### Phase 5: Yara Scanning (Identify Specific Files)
```powershell
# Create CSV with sensitive file names and hashes
# Format: FileName,SHA256Hash
# Example: sensitive_files.csv
# Budget_2024_Secret.xlsx,abc123def456...
# Personnel_Records.docx,789xyz012...

# Run Yara scan to find traces of these files in collected artifacts
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\WORKSTATION\20251218_120000" `
    -YaraInputFile "sensitive_files.csv"

# Output: Phase3_Yara_Scan_Results.txt
# Shows if any files matching names/hashes exist in collected data
```

**CRITICAL:** Analysis operations have prerequisites - parsing must happen before searching/filtering.

1. **Server Analysis First:**
   - **Parse** DC event logs to CSV: `-ParseEventLogs`
   - **Search** parsed logs for file access (4663, 4656): `-SearchKeywordsFile -FilterEventIDs`
   - Parse DNS logs for drive.google.com queries
   - Parse DFS metadata for files accessed on shares

2. **Workstation Analysis:**
   - **Parse** MFT: `-ParseMFT`
   - **Search** parsed MFT for Google Drive folders: `-SearchMFTPaths`
   - **Parse** prefetch: `-ParsePrefetch`
   - **Parse** registry: `-ParseRegistry`
   - Parse browser history for drive.google.com URLs
   - Parse LNK files for recently opened sensitive documents

3. **Cross-Reference:**
   - Match file access times (Event 4663) with browser activity
   - Correlate MFT timestamps with upload times
   - Link prefetch execution with file access events

4. **Timeline Output:**
   - Establish chain of custody: File access → Browser launch → Drive upload
   - Document temporal proximity (within minutes)
   - Identify shared files through Drive link sharing patterns

**Common Error:** Running `-SearchKeywordsFile` without `-ParseEventLogs` first will fail with "No parsed event log CSV found." Always parse before searching.→ Drive upload
   - Document temporal proximity (within minutes)
   - Identify shared files through Drive link sharing patterns

### Critical Search Terms for Filtering

**Server-side (Event Logs):**
```
Sensitive folder names: "Confidential", "Restricted", "Executive", "Board Materials"
File extensions: .xlsx, .docx, .pdf, .pptx
Suspect username: "[domain]\[username]"
Event IDs: 4663, 4656, 4624, 4688
```

**Workstation (All artifacts):**
```
GoogComplete Insider Threat Analysis Example

```powershell
# Complete workflow for suspect workstation analysis
$inv = "investigations\Case\SUSPECT-PC\20251218_120000"

# Step 1: Parse all artifacts (creates CSV files)
.\source\Analyze-Investigation.ps1 -InvestigationPath $inv `
    -ParseEventLogs -ParseMFT -ParsePrefetch -ParseRegistry

# Step 2: Search for Google Drive activity in event logs
.\source\Analyze-Investigation.ps1 -InvestigationPath $inv `
    -SearchKeywords "chrome.exe","GoogleDriveSync.exe","drive.google.com" `
    -FilterEventIDs 4663,4688 -DetectSuspiciousPatterns

# Step 3: Search MFT for Google Drive sync folder
.\source\Analyze-Investigation.ps1 -InvestigationPath $inv `
    -SearchMFTPaths "Google Drive","AppData\Local\Google\Drive"

# Step 4: Run full analysis with Yara scan for sensitive files
.\source\Analyze-Investigation.ps1 -InvestigationPath $inv `
    -YaraInputFile "sensitive_files.csv" -FullAnalysis

# Results in:
# - Phase3_EventLog_Analysis/Security_parsed.csv
# - Phase3_Filtered_EventLog_Results.csv (filtered by keywords)
# - Phase3_MFT_Analysis/MFT_Full.csv
# - Phase3_MFT_PathMatches.csv (Google Drive paths)
# - Phase3_Prefetch_Analysis/Prefetch_Timeline.csv
# - Phase3_Registry_Analysis/*.csv
# - Phase3_Yara_Scan_Results.txt
```

### Zimmerman Tool Invocation Reference

```powershell
# EvtxECmd - Parse event logs to CSV (called by -ParseEventLogs)msedge.exe"
```

### Zimmerman Tool Invocation Reference

```powershell
# EvtxECmd - Parse event logs to CSV
tools/optional/ZimmermanTools/net9/EvtxECmd.exe `
    -d "collected_files\EventLogs" `
    --csv "Phase3_EventLog_Analysis" --csvf "Security_parsed.csv"

# MFTECmd - Parse MFT to timeline
tools/optional/ZimmermanTools/net9/MFTECmd.exe `
    -f "collected_files\MFT_C.bin" `
    --csv "Phase3_MFT_Analysis" --csvf "MFT_Full.csv"

# PECmd - Parse prefetch
tools/optional/ZimmermanTools/net9/PECmd.exe `
    -d "collected_files\Prefetch" `
    --csv "Phase3_Prefetch_Analysis" --csvf "Prefetch_Timeline.csv"

# RECmd - Parse registry with batch file
tools/optional/ZimmermanTools/net9/RECmd.exe `
    -f "collected_files\Users\suspect\NTUSER.DAT" `
    --bn "BatchExamples\TypedUrls.reb" `
    --csv "Phase3_Registry_Analysis" --csvf "TypedUrls.csv"

# LECmd - Parse LNK files
tools/optional/ZimmermanTools/net9/LECmd.exe `
    -d "collected_files\Users\suspect\Recent" `
    --csv "Phase3_LNK_Analysis" --csvf "Recent_Files.csv"

# JLECmd - Parse jump lists
tools/optional/ZimmermanTools/net9/JLECmd.exe `
    -d "collected_files\Users\suspect\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations" `
    --csv "Phase3_JumpList_Analysis" --csvf "JumpLists.csv"
```

## Analysis Module

### Structure
```
modules/CadoBatchAnalysis/
├── CadoBatchAnalysis.psd1  # Manifest
└── CadoBatchAnalysis.psm1  # Functions: Invoke-YaraScan, Parse-EventLogs, etc.
```

### Usage Pattern
```powershell
# Import-Module loads from relative path in Analyze-Investigation.ps1
$modulePath = Join-Path $scriptRoot "..\modules\CadoBatchAnalysis\CadoBatchAnalysis.psd1"
Import-Module -Name $modulePath -Force

# Run full analysis
.\source\Analyze-Investigation.ps1 -InvestigationPath ".\investigations\HOST\20251218_120000" -FullAnalysis
```

## Documentation Structure

- **docs/analyst/** - Technical details, artifact inventory, analysis workflows
- **docs/sysadmin/** - Deployment guides, quick start, Cortex XDR procedures
- **docs/historical/** - Bug fix reports, security audits, release notes
- **docs/validation/** - Test results and validation scripts
- **archive/** - Legacy documentation from original Cado-Batch project

**User-facing docs** in releases: README.md, RELEASE_NOTES.md, docs/ANALYST_WORKSTATION_GUIDE.md

## Common Pitfalls

1. **File Unblocking:** Files extracted from ZIP are often blocked. `run-collector.ps1` calls `Unblock-File` automatically (lines 49-54).

2. **Parameter Arrays:** PowerShell splatting requires hashtables, not arrays. Wrong: `& script.ps1 $args`. Right: `& script.ps1 @PSBoundParameters` or pass parameters individually.

3. **Admin Rights:** Collection requires admin. Check with `#Requires -RunAsAdministrator`. Batch launcher validates with `net session >nul 2>&1`.

4. **Long Paths:** Robocopy handles MAX_PATH better than Copy-Item. Use for user profile artifacts (Recent Items, browser history).

5. **Analyst Workstation Logic:** Normalize hostname (`-replace '\\\\', '' -replace '\\', ''`). Detect localhost (`localhost`, `127.0.0.1`, `$env:COMPUTERNAME`). Use `C:\Temp` for local, `\\host\c$\Temp` for remote. See [tests/Test-AnalystWorkstation.ps1](../tests/Test-AnalystWorkstation.ps1).

## Key Files Reference

- [source/collect.ps1](../source/collect.ps1) - Main collection logic, path resolution, logging framework
- [run-collector.ps1](../run-collector.ps1) - Entry point with execution policy bypass
- [Build-Release.ps1](../Build-Release.ps1) - Release packaging (defines what ships)
- [DIRECTORY_STRUCTURE.md](../DIRECTORY_STRUCTURE.md) - Project layout and file placement rules
- [README.md](../README.md) - Quick start, artifact inventory, forensic value tables
- [00_START_HERE.md](../00_START_HERE.md) - Project overview and key capabilities

## Working with This Codebase

### Making Changes
1. **Test locally first:** `.\run-collector.ps1 -AnalystWorkstation "localhost" -Verbose`
2. **Check logs:** Always review `forensic_collection_*.txt` for errors/warnings
3. **Build release:** `.\Build-Release.ps1 -Zip` after changes
4. **Update docs:** User-facing changes require README.md updates
5. **Version bump:** Update version in README.md and RELEASE_NOTES.md headers

### Adding New Artifacts
1. Add collection code to `source/collect.ps1` using `Write-Log` framework
2. Increment `$script:collectionStats` counters
3. Document in README.md data sources table
4. Update artifact count in RELEASE_NOTES.md
5. Add parsing function to `modules/CadoBatchAnalysis/` if applicable

### Debugging Tips
- Use `-Verbose` for detailed output
- Check `$scriptRoot` and `$binPath` resolution at script start
- Verify tool paths with `Get-BinFile` before use
- Test with `-NoZip` first (faster iteration)
- Review `COLLECTION_SUMMARY.txt` for statistics

## References
- **Zimmerman Tools:** https://ericzimmerman.github.io/
- **RawCopy:** https://github.com/jschicht/RawCopy
- **Yara:** https://github.com/VirusTotal/yara
- **SysInternals:** https://docs.microsoft.com/en-us/sysinternals/
