# Collection Success Guide

**For System Administrators**  
**HER Version:** 1.0.1  
**Last Updated:** December 18, 2025

---

## Quick Start (5 Minutes)

### Step 1: Prepare Collection Location

```powershell
# Open PowerShell as Administrator
# Create working directory
Set-Location -Path C:\Temp

# Option A: Copy from network share
Copy-Item -Path "\\analyst-share\Tools\HER-Collector.zip" -Destination C:\Temp\

# Option B: Copy from USB
Copy-Item -Path "E:\HER-Collector.zip" -Destination C:\Temp\

# Extract (important - do not skip unblock step)
Expand-Archive -Path C:\Temp\HER-Collector.zip -DestinationPath C:\Temp\HER-Collector -Force

# CRITICAL: Unblock files (prevents errors)
Get-ChildItem -Path C:\Temp\HER-Collector -Recurse | Unblock-File
```

### Step 2: Run Collection

```powershell
# Standard collection (recommended)
C:\Temp\HER-Collector\run-collector.ps1 -AnalystWorkstation "analyst-workstation-name"

# Or for local testing
C:\Temp\HER-Collector\run-collector.ps1 -AnalystWorkstation "localhost"
```

### Option: Silent Collection (Stealth Mode)

Use this for sensitive investigations where you want to minimize visibility to logged-on users.

```powershell
# Runs invisibly, saves to %Temp%, exfiltrates to share, and self-cleans
C:\Temp\HER-Collector\run-silent.ps1 -AnalystWorkstation "\\FileServer\EvidenceShare"
```

**Silent Mode Features:**
- **Hidden Window:** The console window hides immediately upon execution.
- **Temp Execution:** Collects to `%Temp%\HER_Collection_[Timestamp]` instead of the script directory.
- **Auto-Exfiltration:** Sends data to the specified UNC path or Hostname.
- **Self-Cleanup:** Deletes the collected evidence from `%Temp%` after successful transfer.

### Step 3: Verify Completion

Look for this message:
```
============================================================================
COLLECTION COMPLETE!
============================================================================
```

**Output Location:** `C:\Temp\HER-Collector\investigations\[ServerName]\[Timestamp]\`

**Files Created:**
- `collected_files.zip` (main evidence archive)
- `COLLECTION_SUMMARY.txt` (what was collected)
- `forensic_collection_*.txt` (detailed log)

---

## What to Expect

### Timeline

| Server Type | Collection Time | Output Size |
|-------------|----------------|-------------|
| Workstation (100GB drive) | 15-20 minutes | 200-800 MB |
| Small Server (500GB drive) | 20-30 minutes | 500 MB - 2 GB |
| Domain Controller | 25-40 minutes | 1-4 GB |
| Large File Server (1TB+) | 30-60 minutes | 2-8 GB |

**Note:** Times vary based on disk speed, system activity, and number of users.

### What You'll See

```
Starting collection from: C:\Temp\HER-Collector
Files will be copied to analyst workstation: analyst-workstation-name

Using tools from: C:\Temp\HER-Collector\tools\bins
Working directory: C:\Temp\HER-Collector\source
Hypervisor detected: VMware vSphere (or Physical Hardware)
Active Directory Domain Services detected - collecting AD artifacts
DNS Server detected - collecting DNS logs and zones

Successfully collected MFT and LogFile.
Successfully collected EVTX files.
Successfully collected System Registry hives.
Successfully collected prefetch files.
...
Successfully collected user-specific artifacts.
Successfully compressed files to collected_files.zip

Transferring files to analyst workstation...
  Source: C:\Temp\HER-Collector\investigations\SERVER01\20251218_143000
  Destination: \\analyst-workstation\c$\Temp\Investigations\SERVER01\20251218_143000
  Transfer mode: ZIP file only (compression successful)

Successfully transferred ZIP archive to analyst workstation!

============================================================================
COLLECTION COMPLETE!
============================================================================
```

---

## Understanding the Output

### Success Indicators

✅ **Green "Successfully collected..." messages** - Everything working normally  
✅ **"Collection complete" at the end** - All operations finished  
✅ **ZIP file created** - Evidence compressed for transfer  
✅ **"Successfully transferred..."** - Files copied to analyst workstation  

### Warning Indicators

⚠️ **Yellow warnings about MAX_PATH** - Some files have very long paths, collection continues  
⚠️ **Yellow warnings about locked files** - System files in use, RawCopy will handle them  
⚠️ **Compression skipped/failed** - Large collection, uncompressed files still transferred  

**Note:** Warnings are NORMAL and do not indicate failure. Collection continues despite warnings.

### Error Indicators

❌ **Red "FATAL ERROR" message** - Collection stopped, see troubleshooting below  
❌ **"Access is denied"** - Need to run as Administrator  
❌ **"Tools directory not found"** - Files not extracted correctly  

---

## Troubleshooting

### Error: "Tools Directory Not Found"

**Symptom:**
```
FATAL ERROR: Tools Directory Not Found
Expected locations:
  - C:\Temp\HER-Collector\source\bins
  - C:\Temp\HER-Collector\tools\bins
```

**Cause:** Files not extracted correctly or running from wrong location

**Solution:**
1. Verify extraction: `Test-Path C:\Temp\HER-Collector\tools\bins\RawCopy.exe`
2. Re-extract if needed: `Expand-Archive -Path HER-Collector.zip -DestinationPath C:\Temp\HER-Collector -Force`
3. Ensure you're in the HER-Collector directory when running

### Error: "Execution Policy Restricted"

**Symptom:**
```
Execution Policy Restriction Detected
Current Execution Policy:
  CurrentUser: Restricted
  LocalMachine: Restricted
```

**Cause:** PowerShell execution policy blocking scripts

**Solution - Option 1 (Temporary Bypass):**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\run-collector.ps1 -AnalystWorkstation "analyst-workstation"
```

**Solution - Option 2 (Use Batch Launcher):**
```batch
REM Right-click, Run as Administrator
RUN_COLLECT.bat
```

### Error: "Access is Denied"

**Symptom:**
```
Exception: You do not have sufficient access rights
```

**Cause:** Not running as Administrator

**Solution:**
1. Close PowerShell window
2. Right-click PowerShell → "Run as Administrator"
3. Re-run commands

### Warning: "Path length exceeded MAX_PATH limit"

**Symptom:**
```
WARNING: Path length exceeded MAX_PATH limit - skipping this artifact
WARNING: MAX_PATH issue (non-fatal): Could not copy ...
```

**Cause:** Windows has a 260-character path limit. Some deeply nested folders exceed this.

**What Happens:** Specific long-path files are skipped, but collection continues normally.

**Action Required:** None - this is expected behavior in environments with OneDrive or deep folder structures. The collection is still valid and useful.

### Error: "Network path not found" (Analyst Workstation Transfer)

**Symptom:**
```
Error: Failed to transfer files to analyst workstation
Error: Network path not found
```

**Cause:** Cannot reach analyst workstation over network

**Understanding -AnalystWorkstation Parameter:**

The `-AnalystWorkstation` parameter supports multiple values:

**Localhost Variants (Local Transfer):**
- `localhost`
- `127.0.0.1`
- Current computer name (e.g., `$env:COMPUTERNAME`)

All copy to: `C:\Temp\Investigations\[Hostname]\[Timestamp]\`

**Remote Hosts (Network Transfer):**
- Any hostname or IP not matching localhost
- Copies to: `\\[Hostname]\c$\Temp\Investigations\[SourceHost]\[Timestamp]\`

**Transfer Behavior:**
- **ZIP created:** Only transfers `collected_files.zip`, log file, and summary (faster)
- **No ZIP:** Transfers entire directory structure (slower but complete)

**Prerequisites for Remote Transfer:**
1. Network connectivity (SMB port 445 open)
2. Administrative rights on target host
3. C$ administrative share accessible
4. Sufficient disk space on target

**Solution - Option 1 (Manual Transfer):**
```powershell
# Collection files remain in local folder
# Manually copy to analyst:
robocopy "C:\Temp\HER-Collector\investigations\SERVER01\20251218_143000" `
    "\\analyst-workstation\c$\Temp\Investigations\SERVER01\20251218_143000" `
    /E /DCOPY:T /COPY:DAT /R:3 /W:5
```

**Solution - Option 2 (Use Localhost):**
```powershell
# Collect locally, transfer later
.\run-collector.ps1 -AnalystWorkstation "localhost"

# Files saved to C:\Temp\Investigations\
# Copy to USB or network share manually
```

**Solution - Option 3 (Try IP Address):**
```powershell
# Bypass DNS, use direct IP
.\run-collector.ps1 -AnalystWorkstation "192.168.1.100"
```

**Solution - Option 4 (Test Connectivity First):**
```powershell
# Verify host is reachable
Test-Connection -ComputerName analyst-workstation
Test-NetConnection -ComputerName analyst-workstation -Port 445

# Test C$ share access
dir \\analyst-workstation\c$

# Run validation test script
.\tests\Test-AnalystWorkstation.ps1 -AnalystWorkstation "analyst-workstation"
```

### Collection Takes Longer Than Expected

**Symptom:** Running for more than 60 minutes

**Possible Causes:**
- Very large server (TB+ of data)
- Slow disk (spinning drives vs. SSD)
- High system activity during collection
- Network transfer of large ZIP file

**What to Do:**
✅ **Let it finish** - Do not stop the collection  
✅ **Monitor progress** - Green messages still appearing = working normally  
✅ **Check disk space** - Ensure target has enough space  
✅ **Review last message** - Shows which operation is running  

**When to Stop:**
❌ No new messages for >30 minutes  
❌ PowerShell window frozen (not accepting Ctrl+C)  
❌ Disk space exhausted  

### Compression Failed

**Symptom:**
```
Warning: Could not compress collected files: [error details]
Compressed Archive: (Compression failed - files remain uncompressed)
```

**Cause:** Typically happens with very large collections (>20 GB)

**Impact:** Files remain uncompressed but transfer still occurs (takes longer)

**Action:** None required - collection is still successful

**Prevention:** Use `-NoZip` parameter for large collections:
```powershell
.\run-collector.ps1 -AnalystWorkstation "analyst-pc" -NoZip
```

---

## Verifying Successful Collection

### Checklist

After collection completes, verify:

- [ ] **"COLLECTION COMPLETE!" message appeared**
- [ ] **Output folder exists:** `C:\Temp\HER-Collector\investigations\[ServerName]\[Timestamp]\`
- [ ] **Main files present:**
  - `collected_files.zip` (or `collected_files\` folder if compression skipped)
  - `COLLECTION_SUMMARY.txt`
  - `forensic_collection_*.txt`
- [ ] **Summary report shows high success rate:**
  - Open `COLLECTION_SUMMARY.txt`
  - Check "Success Rate" (should be >90%)
- [ ] **Transfer completed (if using -AnalystWorkstation):**
  - Look for "Successfully transferred..." message
  - Or check destination: `\\analyst-workstation\c$\Temp\Investigations\`

### Reading the Summary Report

Open `COLLECTION_SUMMARY.txt`:

```
============================================================================
HOST EVIDENCE RUNNER (HER) - COLLECTION SUMMARY
============================================================================

Collection Date: 2025-12-18 14:30:22
Computer Name: SERVER01
Duration: 00:27:15

============================================================================
COLLECTION STATISTICS
============================================================================

Total Items Attempted: 45
Successful Collections: 43
Warnings: 2
Errors: 0

Success Rate: 95.6%
```

**Good:** Success Rate >90%, Errors = 0  
**Acceptable:** Success Rate >80%, Errors <5  
**Review Needed:** Success Rate <80% or Errors >5 - check log file

### Reading the Detailed Log

Open `forensic_collection_*.txt` to see detailed operations:

```
[2025-12-18 14:30:22] [Info] Starting collection...
[2025-12-18 14:31:05] [Info] Successfully collected MFT and LogFile.
[2025-12-18 14:32:18] [Info] Successfully collected EVTX files.
[2025-12-18 14:33:45] [Warning] MAX_PATH issue (non-fatal): Could not copy C:\Users\...
[2025-12-18 14:35:12] [Info] Successfully collected System Registry hives.
...
[2025-12-18 14:57:37] [Info] Collection Process Completed Successfully
```

**Look for:**
- More [Info] than [Warning]
- No [Error] entries
- "Completed Successfully" at end

---

## Advanced Options

### Skip Compression (For Large Collections)

```powershell
# Skip ZIP creation to save time
.\run-collector.ps1 -AnalystWorkstation "analyst-pc" -NoZip
```

**When to use:**
- Collections expected to be >10 GB
- Compression is taking >30 minutes
- You have fast network for transfer

**Trade-off:** Transfer takes longer but collection finishes faster

### Collect Locally (No Network Transfer)

```powershell
# Collect to local disk only
.\run-collector.ps1 -AnalystWorkstation "localhost"
```

**When to use:**
- Network connectivity issues
- Testing before production deployment
- Manual transfer preferred

**Output:** `C:\Temp\Investigations\[ServerName]\[Timestamp]\`

### Verbose Output (Debugging)

```powershell
# Show detailed progress
.\run-collector.ps1 -AnalystWorkstation "analyst-pc" -Verbose
```

**When to use:**
- Troubleshooting issues
- Understanding what's happening
- First-time deployment testing

**Note:** Produces a LOT of output - not recommended for production

---

## Scheduled/Automated Collection

### Windows Task Scheduler

```powershell
# Create scheduled task (run as Administrator)
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument `
  "-NoProfile -ExecutionPolicy Bypass -File C:\HER-Collector\run-collector.ps1 -AnalystWorkstation 'analyst-server'"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "HER-DailyCollection" -Trigger $trigger -Action $action -Principal $principal
```

### Group Policy Deployment

```powershell
# Script path for GPO:
\\domain.com\SYSVOL\domain.com\scripts\HER-Collector\run-collector.ps1

# Parameters:
-AnalystWorkstation "analyst-workstation"

# Run as: SYSTEM or NT AUTHORITY\NETWORK SERVICE
# Schedule: Startup or daily
```

**Best Practices for Automation:**
- Use `-AnalystWorkstation` parameter (no prompts)
- Ensure target has sufficient disk space (20 GB recommended)
- Schedule during off-hours (2-4 AM)
- Monitor destination folder for new collections
- Alert on missing collections

---

## What Gets Collected

### All Servers

- **System Files:** $MFT, $LogFile, $UsnJrnl (file system metadata)
- **Event Logs:** All .evtx files (Security, System, Application, etc.)
- **Registry:** SYSTEM, SOFTWARE, SAM, SECURITY, user hives
- **User Data:** Browser history, recent files, PowerShell history
- **System Config:** Scheduled tasks, prefetch, HOSTS file
- **Network:** IP config, RDP history, WiFi profiles, USB history

### Domain Controllers (Auto-Detected)

- **Active Directory:** NTDS.dit database, transaction logs
- **SYSVOL:** Group Policy objects, logon scripts
- **AD Logs:** Additional event channels

### DNS Servers (Auto-Detected)

- **DNS Zones:** Zone files (.dns)
- **DNS Logs:** Debug logs, query logs

### DFS Servers (Auto-Detected)

- **DFS Metadata:** Replication database, staging folders

**Note:** Role detection is automatic - no configuration needed.

---

## Security & Privacy

### What the Tool Does

✅ **Read-only operations** - No files modified  
✅ **No credentials collected** - Passwords not captured  
✅ **No network scanning** - Only local artifacts  
✅ **Respects NTFS permissions** - Only collects accessible files  
✅ **Temporary admin rights** - Only for collection duration  

### What the Tool Does NOT Do

❌ Does not decrypt encrypted files  
❌ Does not bypass Windows security  
❌ Does not capture live memory  
❌ Does not install software permanently  
❌ Does not modify system configuration  

### Chain of Custody

- **SHA256 hashes** generated for all files (SHA256_MANIFEST.txt)
- **Detailed logging** of every operation (forensic_collection_*.txt)
- **Timestamps** on all actions
- **Integrity verification** with hashdeep64.exe

---

## Contact & Support

### When to Contact Analyst

Contact the analyst who provided this tool if:
- Collection fails with errors (success rate <80%)
- Execution policy prevents running
- Network transfer consistently fails
- Collection takes >2 hours
- Unclear instructions

### Information to Provide

When contacting analyst, include:
1. Server name and role (DC, DNS, File Server, etc.)
2. Full error message (screenshot or copy/paste)
3. Files from output folder:
   - `COLLECTION_SUMMARY.txt`
   - `forensic_collection_*.txt`
4. Collection duration
5. Any warnings or errors seen

### Do NOT Include

❌ User passwords or credentials  
❌ Actual collected evidence files  
❌ Sensitive document contents  

---

## Quick Reference Card

**Print this section and keep nearby during collection:**

```
┌─────────────────────────────────────────────────────────────────┐
│                  HER COLLECTION QUICK REFERENCE                  │
├─────────────────────────────────────────────────────────────────┤
│ 1. PREPARE:                                                     │
│    Set-Location C:\Temp                                         │
│    Copy and extract HER-Collector.zip                          │
│    Get-ChildItem -Recurse | Unblock-File                       │
│                                                                 │
│ 2. RUN:                                                         │
│    C:\Temp\HER-Collector\run-collector.ps1 \                   │
│        -AnalystWorkstation "analyst-pc"                         │
│                                                                 │
│ 3. VERIFY:                                                      │
│    Look for "COLLECTION COMPLETE!" message                      │
│    Check COLLECTION_SUMMARY.txt (Success Rate >90%)            │
│    Verify transfer or copy to analyst manually                  │
│                                                                 │
│ 4. TIMEFRAMES:                                                  │
│    Workstations: 15-20 min                                      │
│    Small Servers: 20-30 min                                     │
│    Domain Controllers: 25-40 min                                │
│    Large Servers: 30-60 min                                     │
│                                                                 │
│ 5. TROUBLESHOOTING:                                             │
│    "Execution Policy" → Set-ExecutionPolicy Bypass              │
│    "Access Denied" → Right-click → Run as Administrator        │
│    "Tools Not Found" → Verify extraction path                   │
│    "MAX_PATH warnings" → Normal, continue                       │
│    "Network path not found" → Use localhost, transfer manually  │
└─────────────────────────────────────────────────────────────────┘
```

---

**End of Collection Success Guide**
