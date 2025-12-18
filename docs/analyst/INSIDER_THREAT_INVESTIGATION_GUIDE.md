# Insider Threat Investigation Guide

**For Forensic Analysts**  
**HER Version:** 1.0.1  
**Last Updated:** December 18, 2025

---

## Overview

This guide covers end-to-end insider threat investigations using Host Evidence Runner (HER), with focus on data exfiltration scenarios involving cloud storage services (Google Drive, OneDrive, Dropbox).

**Target Scenario:** Privileged user accessing sensitive files and uploading to cloud storage for unauthorized sharing.

---

## Investigation Phases

### Phase 1: Collection Planning & Execution

#### 1.1 Collection Strategy

**Multi-Host Collection Order:**
1. **Domain Controllers first** - Establish baseline user activity
2. **File Servers (DFS/NAS)** - Document sensitive file access
3. **DNS Servers** - Track cloud service queries
4. **Suspect Workstations** - Detailed user activity analysis

**Rationale:** Server-side artifacts provide the authoritative timeline. Workstation artifacts confirm intent and method.

#### 1.2 Server Collection

```powershell
# Multi-server deployment (DC, DNS, DFS)
.\source\deploy_multi_server.ps1 -Servers "dc01.domain.com","dns01.domain.com","dfs01.domain.com" `
    -AnalystWorkstation "analyst-workstation"

# Output: investigations/[ServerName]/[Timestamp]/collected_files/
```

**Critical Server Artifacts:**
- **DC:** NTDS.dit, Security event logs (4663, 4656, 4624, 4688)
- **DNS:** DNS query logs (drive.google.com, googleapis.com)
- **DFS:** File access metadata, replication logs

#### 1.3 Workstation Collection

```powershell
# Suspect workstation(s)
.\run-collector.ps1 -AnalystWorkstation "analyst-workstation" -Verbose

# Target: investigations/[Workstation]/[Timestamp]/collected_files/
```

**Critical Workstation Artifacts:**
- Browser history (Chrome/Edge/Firefox)
- MFT ($MFT for file system timeline)
- Prefetch (program execution history)
- Recent Items/Jump Lists
- Registry MRUs (typed URLs, recent documents)
- Event logs (Security: 4663, 4688)

---

### Phase 2: Artifact Parsing with Zimmerman Tools

#### 2.1 Prerequisites

**Install Zimmerman Tools:**
1. Download from https://ericzimmerman.github.io/#!index.md
2. Extract to `tools/optional/ZimmermanTools/`
3. Prefer `net9` runtime (requires .NET Desktop Runtime 9)

**Verify Installation:**
```powershell
Test-Path "tools/optional/ZimmermanTools/net9/MFTECmd.exe"
Test-Path "tools/optional/ZimmermanTools/net9/EvtxECmd.exe"
Test-Path "tools/optional/ZimmermanTools/net9/PECmd.exe"
Test-Path "tools/optional/ZimmermanTools/net9/RECmd.exe"
```

#### 2.2 Automated Analysis Template

**Use the Investigation Analysis Template:**
```powershell
# Step 1: Copy template to investigation folder
Copy-Item "templates\Run-Investigation-Analysis.ps1" `
    -Destination "investigations\[Case]\[Workstation]\[Timestamp]\"

# Step 2: Edit configuration variables (lines 20-120)
cd "investigations\[Case]\[Workstation]\[Timestamp]"
notepad .\Run-Investigation-Analysis.ps1

# Step 3: Customize for your case:
#   - $InvestigationPath (path to collection)
#   - $EventLogKeywords (search terms: "drive.google.com", "chrome.exe", etc.)
#   - $EventIDsToFilter (4663, 4656, 4624, 4688)
#   - $MFTSearchPaths ("Google Drive", "Downloads", "Confidential")
#   - Enable/disable phases as needed

# Step 4: Run the analysis
.\Run-Investigation-Analysis.ps1

# Output: Phase3_* folders with parsed CSVs
```

**Template Benefits:**
- **3-4x faster:** Parallel execution of parsing operations
- **Repeatable:** Same analysis for all hosts in case
- **Customizable:** Edit search terms once, reuse for entire investigation
- **Auditable:** Creates Analysis_Execution_Log.txt

#### 2.3 Manual Analysis Operations

If you need more control than the template provides:

**Parse Event Logs (STEP 1 - Required First):**
```powershell
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\[Case]\[Host]\[Timestamp]" `
    -ParseEventLogs -EventLogFormat csv

# Output: Phase3_EventLog_Analysis/Security_parsed.csv
```

**Search Event Logs (STEP 2 - Requires STEP 1):**
```powershell
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\[Case]\[Host]\[Timestamp]" `
    -SearchKeywordsFile "search_terms.txt" `
    -FilterEventIDs 4663,4656,4624,4688 `
    -DetectSuspiciousPatterns

# Output: Phase3_Filtered_EventLog_Results.csv
```

**Parse MFT (STEP 1):**
```powershell
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\[Case]\[Host]\[Timestamp]" `
    -ParseMFT

# Output: Phase3_MFT_Analysis/MFT_Full.csv
```

**Search MFT (STEP 2):**
```powershell
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\[Case]\[Host]\[Timestamp]" `
    -SearchMFTPaths "Google Drive","Downloads","Confidential"

# Output: Phase3_MFT_PathMatches.csv
```

---

### Phase 3: Timeline Reconstruction

#### 3.1 Google Drive Exfiltration Indicators

**Event IDs to Focus On:**
- **4663:** Object access (file opened/read/copied)
- **4656:** Handle to object (file access attempt)
- **4624:** Logon (Type 3=network, Type 10=RDP)
- **4688:** Process creation (Chrome.exe, GoogleDriveSync.exe)
- **7045:** Service installed (persistence mechanism)

**File System Timeline:**
```
1. Sensitive file accessed on DFS share (Event 4663) - 2025-12-15 14:23:00
2. Same file in MFT with Modified time - 2025-12-15 14:23:15
3. Chrome.exe execution in Prefetch - 2025-12-15 14:24:00
4. drive.google.com/upload in browser history - 2025-12-15 14:25:30
5. LNK file in Recent Items - 2025-12-15 14:23:00
```

**Google Drive Sync Folder Locations:**
- `C:\Users\[user]\Google Drive\`
- `C:\Users\[user]\AppData\Local\Google\Drive\`
- `C:\Users\[user]\AppData\Local\Google\DriveFS\`

#### 3.2 Browser History Analysis

**Google Drive URL Patterns:**
- `drive.google.com/file/d/[ID]/view` - File viewing
- `drive.google.com/drive/folders/[ID]` - Folder browsing
- `docs.google.com/document/d/[ID]` - Google Docs
- `docs.google.com/spreadsheets/d/[ID]` - Google Sheets
- POST requests to `drive.google.com/upload` - Upload activity

**Analysis Location:**
```
collected_files/UserActivity_Analysis/Chrome_History_Default.db
collected_files/UserActivity_Analysis/Edge_History_Default.db
```

#### 3.3 Registry Analysis

**Key Registry Artifacts:**
```powershell
# Parse registry with RECmd
cd tools/optional/ZimmermanTools/net9

# Typed URLs (manually typed in browser)
.\RECmd.exe -f "investigations\[Case]\[Host]\[Timestamp]\collected_files\Users\[suspect]\NTUSER.DAT" `
    --bn "BatchExamples\TypedUrls.reb" `
    --csv "investigations\[Case]\[Host]\[Timestamp]\Phase3_Registry_Analysis" `
    --csvf "TypedUrls.csv"

# Office Recent Documents
.\RECmd.exe -f "investigations\[Case]\[Host]\[Timestamp]\collected_files\Users\[suspect]\NTUSER.DAT" `
    --bn "BatchExamples\OfficeMRU.reb" `
    --csv "investigations\[Case]\[Host]\[Timestamp]\Phase3_Registry_Analysis" `
    --csvf "Office_RecentDocs.csv"
```

**Key Locations:**
- `HKCU\Software\Microsoft\Internet Explorer\TypedURLs`
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs`
- `HKCU\Software\Microsoft\Office\[Version]\[App]\File MRU`

#### 3.4 Prefetch Analysis

```powershell
# Parse prefetch to identify Chrome/Drive execution
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\[Case]\[Host]\[Timestamp]" `
    -ParsePrefetch

# Or manually with PECmd
cd tools/optional/ZimmermanTools/net9
.\PECmd.exe -d "investigations\[Case]\[Host]\[Timestamp]\collected_files\Prefetch" `
    --csv "investigations\[Case]\[Host]\[Timestamp]\Phase3_Prefetch_Analysis" `
    --csvf "Prefetch_Timeline.csv"

# Focus on:
# - CHROME.EXE-*.pf (last run time, execution count)
# - GOOGLEDRIVESYNC.EXE-*.pf (Drive desktop app)
# - File paths accessed by these processes
```

---

### Phase 4: Evidence Correlation

#### 4.1 Building the Timeline

**Correlation Matrix:**

| Time | Artifact Source | Event | Indicator |
|------|----------------|-------|-----------|
| 14:23:00 | DC Event Log 4663 | File Access | User opened \\DFS\Share\Confidential\Budget.xlsx |
| 14:23:15 | Workstation MFT | File Modified | C:\Users\suspect\Downloads\Budget.xlsx |
| 14:24:00 | Prefetch | Program Execution | CHROME.EXE last executed |
| 14:24:30 | Browser History | URL Visit | drive.google.com (authenticated) |
| 14:25:30 | Browser History | POST Request | drive.google.com/upload/Budget.xlsx |
| 14:26:00 | Registry MRU | Recent Document | Budget.xlsx in Office MRU |
| 14:27:00 | LNK File | Recent Item | Budget.xlsx.lnk in Recent Items |

#### 4.2 Establishing Intent

**Indicators of Deliberate Exfiltration:**
1. **File Staging:** Copied from server to local Downloads folder
2. **Browser Launch:** Chrome.exe executed immediately after file access
3. **Authentication:** Logged into Google Drive within minutes
4. **Upload Activity:** POST request with filename matching staged file
5. **Cleanup Attempt:** File deleted from Downloads (found in $MFT)
6. **Repeat Pattern:** Multiple sensitive files uploaded within same session

---

### Phase 5: Yara Scanning for Specific Files

```powershell
# Create CSV with sensitive file names and hashes
# Format: FileName,SHA256Hash
# Example: sensitive_files.csv
# Budget_2025_Secret.xlsx,abc123def456...
# Personnel_Records.docx,789xyz012...

# Run Yara scan
.\source\Analyze-Investigation.ps1 -InvestigationPath "investigations\[Case]\[Host]\[Timestamp]" `
    -YaraInputFile "sensitive_files.csv"

# Output: Phase3_Yara_Scan_Results.txt
# Shows if any files matching names/hashes exist in collected data
```

---

## Common Investigation Pitfalls

### 1. Parse Before Search
**Error:** "No parsed event log CSV found. Run Invoke-EventLogParsing first."

**Solution:** Always parse artifacts before searching:
```powershell
# Wrong order - will fail
.\source\Analyze-Investigation.ps1 -SearchKeywords "drive.google.com"

# Correct order
.\source\Analyze-Investigation.ps1 -ParseEventLogs  # Step 1
.\source\Analyze-Investigation.ps1 -SearchKeywords "drive.google.com"  # Step 2
```

### 2. Time Zone Awareness
- Event logs: UTC timestamps
- MFT: Local system time
- Browser history: Usually UTC
- Registry: Mixed (check specific key)

**Best Practice:** Document system time zone and convert all timestamps to UTC for timeline.

### 3. Google Drive Desktop vs. Web
- **Desktop App:** Leaves sync logs in `AppData\Local\Google\Drive\Logs\`
- **Web Browser:** Only browser history and cache
- **Both:** Can be used simultaneously by sophisticated users

### 4. Deleted File Recovery
- MFT retains records even after deletion (marked as unallocated)
- Recycle Bin metadata ($I files) preserves original path
- Browser cache may retain partial file content
- USN Journal tracks deletion events

---

## Advanced Analysis Techniques

### DNS Query Analysis

```powershell
# Parse DC DNS logs for cloud service queries
$dnsLog = "investigations\[Case]\DC01\[Timestamp]\collected_files\EventLogs\Microsoft-Windows-DNSServer%4Analytical.evtx"

# Look for queries matching:
# - drive.google.com
# - docs.google.com
# - googleapis.com
# - ssl.gstatic.com (Google static content)

# Cross-reference query timestamps with file access events
```

### Network Share Access Patterns

```powershell
# From DC Security logs, filter Event 4663
# Look for:
# - Object Name: \\?\UNC\Server\Share\Confidential\*
# - Access Mask: READ_CONTROL, READ_DATA
# - Subject: Suspect user account
# - Process Name: Explorer.exe or Chrome.exe

# Pattern indicating exfiltration:
# Multiple READ_DATA events within short time span on sensitive directory
```

### Office 365 Integration

If organization uses Office 365:
- Check Office 365 audit logs for sharing activity
- Look for external email addresses in Share events
- Cross-reference with local browser history timestamps

---

## Report Generation

```powershell
# Generate comprehensive reports
.\source\Analyze-Investigation.ps1 -GenerateReport -CasePath "investigations\[Case]"

# Outputs:
# - Investigation_Summary.md (case-level)
# - Host_Summary.md (per-host aggregation)
# - Collection summaries for each timestamp
```

**Report Sections:**
1. **Executive Summary:** Timeline, key findings, evidence strength
2. **Technical Analysis:** Artifact breakdown, tool outputs
3. **Timeline:** Chronological event sequence
4. **Evidence Catalog:** Files, hashes, metadata
5. **Recommendations:** Additional data sources, next steps

---

## Best Practices

### 1. Collection Order
✅ Always collect servers before workstations  
✅ Collect suspect workstation last (may alert user)  
✅ Consider after-hours collection to minimize disruption  

### 2. Template Usage
✅ Copy Run-Investigation-Analysis.ps1 to investigation folder  
✅ Customize search terms for specific case  
✅ Save template with case notes for documentation  
✅ Template lives in investigations/ (git-ignored)  

### 3. Documentation
✅ Log all analysis commands in Analysis_Execution_Log.txt  
✅ Screenshot key findings from CSV outputs  
✅ Maintain chain of custody for all artifacts  
✅ Document time zone conversions  

### 4. Collaboration
✅ Share investigation folder structure with team  
✅ Use consistent naming: [Case]-[Host]-[YYYYMMDD]  
✅ Store search terms in case root for reuse  
✅ Keep sensitive_files.csv updated as new files identified  

---

## Quick Reference Commands

```powershell
# Full automated analysis (recommended)
Copy-Item "templates\Run-Investigation-Analysis.ps1" -Destination "investigations\[Case]\[Host]\[Timestamp]\"
# Edit configuration, then run:
.\Run-Investigation-Analysis.ps1

# Manual parsing (if template not suitable)
.\source\Analyze-Investigation.ps1 -InvestigationPath "[path]" -ParseEventLogs
.\source\Analyze-Investigation.ps1 -InvestigationPath "[path]" -ParseMFT
.\source\Analyze-Investigation.ps1 -InvestigationPath "[path]" -ParsePrefetch
.\source\Analyze-Investigation.ps1 -InvestigationPath "[path]" -ParseRegistry

# Manual searching (requires parsing first)
.\source\Analyze-Investigation.ps1 -InvestigationPath "[path]" -SearchKeywordsFile "terms.txt" -FilterEventIDs 4663,4688
.\source\Analyze-Investigation.ps1 -InvestigationPath "[path]" -SearchMFTPaths "Google Drive","Downloads"

# Yara scanning
.\source\Analyze-Investigation.ps1 -InvestigationPath "[path]" -YaraInputFile "sensitive_files.csv"

# Report generation
.\source\Analyze-Investigation.ps1 -GenerateReport -CasePath "investigations\[Case]"
```

---

## Appendix A: Event ID Reference

| Event ID | Source | Description | Forensic Value |
|----------|--------|-------------|----------------|
| 4663 | Security | Object Access | Files opened/read/copied - primary exfiltration indicator |
| 4656 | Security | Handle Requested | File access attempts (before 4663) |
| 4624 | Security | Logon | User authentication (Type 3=network, Type 10=RDP) |
| 4625 | Security | Failed Logon | Authentication failures - lateral movement attempts |
| 4688 | Security | Process Created | Program execution (Chrome, Drive sync, tools) |
| 4689 | Security | Process Terminated | Process end time |
| 7045 | System | Service Installed | Persistence mechanisms, backdoors |

---

## Appendix B: Tool Reference

### Zimmerman Tools
- **MFTECmd:** MFT parsing, file system timeline
- **EvtxECmd:** Event log parsing to CSV/JSON
- **PECmd:** Prefetch parsing, program execution
- **RECmd:** Registry parsing with batch templates
- **LECmd:** LNK file parsing, recent items
- **JLECmd:** Jump list parsing, application history

### HER Native Tools
- **RawCopy.exe:** Extract locked files ($MFT, NTDS.dit, registry)
- **hashdeep64.exe:** SHA256 manifests for chain of custody
- **sigcheck64.exe:** Binary signature verification

---

## Support Resources

- **Project Documentation:** `README.md`, `00_START_HERE.md`
- **Copilot Instructions:** `.github/copilot-instructions.md`
- **Analyst Checklist:** `docs/analyst/ANALYST_DEPLOYMENT_CHECKLIST.md`
- **Artifact Inventory:** `docs/analyst/WINDOWS_SERVER_FORENSICS_PLAN.md`
- **Zimmerman Tools:** https://ericzimmerman.github.io/

---

**End of Insider Threat Investigation Guide**
