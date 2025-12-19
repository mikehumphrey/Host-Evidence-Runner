# Host Evidence Runner (HER)

**Version:** 1.0.1  
**Build Date:** December 2025

A PowerShell-based forensic evidence collector for modern Windows systems (Windows 10, Windows 11, Server 2016+). Designed for rapid deployment from USB or network shares in incident response scenarios.

**Origin:** Independently maintained under Apache 2.0 license.

## Quick Start for Sysadmins

**Prerequisites:** PowerShell running as Administrator

Copy and paste these commands **one line at a time** into PowerShell ISE or PowerShell terminal:

```powershell
# Step 1: Create working directory
Set-Location -Path C:\Temp

# Step 2: Copy collector from network share or GitHub releases
# Option A: From network share (replace SHARE_SERVER and SHARE_PATH with your values)
# Copy-Item -Path "\\<SHARE_SERVER>\<SHARE_PATH>\HER-Collector.zip" -Destination C:\Temp\
# 
# Option B: Download from GitHub releases
# Invoke-WebRequest -Uri "https://github.com/your-org/Host-Evidence-Runner/releases/download/v1.0.1/HER-Collector.zip" -OutFile C:\Temp\HER-Collector.zip

# Step 3: Extract the collector
Expand-Archive -Path C:\Temp\HER-Collector.zip -DestinationPath C:\Temp\HER-Collector -Force

# Step 3b: Unblock extracted files (CRITICAL - prevents DLL initialization errors)
Get-ChildItem -Path C:\Temp\HER-Collector -Recurse | Unblock-File

# Step 3c: Verify extraction (optional but recommended)
Test-Path C:\Temp\HER-Collector\tools\bins\RawCopy.exe

# Step 4: Run the collection (non-interactive, works with scheduled tasks)
C:\Temp\HER-Collector\run-collector.ps1 -AnalystWorkstation "localhost"

# For debugging with verbose output (optional - not recommended for automated runs):
# C:\Temp\HER-Collector\run-collector.ps1 -AnalystWorkstation "localhost" -Verbose

# For large collections or to skip compression:
# C:\Temp\HER-Collector\run-collector.ps1 -AnalystWorkstation "localhost" -NoZip

# Alternative: If -AnalystWorkstation is not used, manually copy results to analyst workstation
# Replace ANALYST_HOSTNAME and TIMESTAMP with actual values shown in collection output
# ROBOCOPY "C:\Temp\HER-Collector\investigations" "\\ANALYST_HOSTNAME\c$\Temp\Investigations\%COMPUTERNAME%\TIMESTAMP" /E /DCOPY:T /COPY:DAT /LOG+:"ROBOCopyLog.txt" /TEE
```

**What happens:**
- Collection creates folder: `C:\Temp\HER-Collector\investigations\[HOSTNAME]\[TIMESTAMP]\`
- If `-AnalystWorkstation` is specified, files are automatically transferred after collection
- Without `-AnalystWorkstation`, the collection stays local (use manual ROBOCOPY if needed)
- Look for `COLLECTION_SUMMARY.txt` and `forensic_collection_*.txt` in the output folder

**Troubleshooting:**
- If Step 4 fails with execution policy error, run: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force`
- Verify network share access before Step 2
- Collection takes 15-45 minutes depending on system size

### Tool layout (single bins copy)
- Tools live once under `tools\bins` in the release. The collector auto-resolves tools from `source\bins` (if present) or falls back to `..\tools\bins`, so only one copy is needed.
- If you relocate tools for any reason, keep the structure intact under `tools\bins` to avoid missing-utility errors.

### Building a release
- From the repo root, run `pwsh -NoProfile -ExecutionPolicy Bypass -File .\Build-Release.ps1 -Zip`.
- Output: `releases/<timestamp>/` plus `releases/HER-Collector.zip`.
- Release artifacts in `releases/` are generated and ignored by git; commit the source scripts only.

## Data Sources Collected

HER collects comprehensive forensic artifacts across multiple categories. All collected data is placed in a `collected_files` directory and optionally compressed into `collected_files.zip`.

### Core System Artifacts

| Data Source | Location | Forensic Value |
|-------------|----------|----------------|
| **$MFT** | `C:\$MFT` | Master File Table - complete file system timeline, reveals deleted files, file creation/modification times, file sizes, parent directories |
| **$LogFile** | `C:\$LogFile` | NTFS transaction log - tracks recent file system changes, captures file deletions and modifications before MFT updates |
| **$UsnJrnl** | `C:\$Extend\$UsnJrnl` | Update Sequence Number Journal - chronological log of all file system changes, critical for timeline reconstruction |
| **Event Logs** | `%SystemRoot%\System32\winevt\logs\*.evtx` | System, Security, Application logs - user logons, process execution, service installations, failed authentication attempts |

### Registry Hives

| Data Source | Location | Forensic Value |
|-------------|----------|----------------|
| **SYSTEM** | `%SystemRoot%\System32\Config\SYSTEM` | Network configuration, mounted devices, USB history, services, Windows version, last shutdown time |
| **SOFTWARE** | `%SystemRoot%\System32\Config\SOFTWARE` | Installed applications, file associations, user assist (program execution counts), MRU lists |
| **SAM** | `%SystemRoot%\System32\Config\SAM` | Local user accounts, password hashes (NTLM), account creation dates, last logon times |
| **SECURITY** | `%SystemRoot%\System32\Config\SECURITY` | Security policy settings, audit configurations, Kerberos tickets cache |
| **DEFAULT** | `%SystemRoot%\System32\Config\DEFAULT` | Default user profile settings applied to new accounts |
| **NTUSER.DAT** | `C:\Users\[user]\NTUSER.DAT` | Per-user settings, recent documents, typed URLs, Run MRU, search history |
| **UsrClass.dat** | `C:\Users\[user]\AppData\Local\Microsoft\Windows\UsrClass.dat` | COM object interactions, ShellBags (folder access history), file type associations |

### Program Execution Evidence

| Data Source | Location | Forensic Value |
|-------------|----------|----------------|
| **Prefetch** | `%SystemRoot%\Prefetch\*.pf` | Program execution history, run counts, last execution time, files/directories accessed by programs |
| **Amcache.hve** | `%SystemRoot%\appcompat\Programs\Amcache.hve` | Application compatibility cache - SHA1 hashes of executables, first execution time, program paths |
| **SRUM** | `%SystemRoot%\System32\sru\SRUDB.dat` | System Resource Usage Monitor - application runtime, network usage per app, bandwidth consumption |
| **Scheduled Tasks** | `%SystemRoot%\System32\Tasks\` | Persistence mechanisms, scheduled malware execution, legitimate task configurations |

### User Activity & Browser Data

| Data Source | Location | Forensic Value |
|-------------|----------|----------------|
| **Browser History** | `AppData\Local\[Browser]\User Data\Default\History` | Web browsing history (URLs, visit times), download history, search queries |
| **Recent Files** | `AppData\Roaming\Microsoft\Windows\Recent\` | LNK files showing recently opened documents, Jump Lists with frequent/pinned items |
| **PowerShell History** | `AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt` | All PowerShell commands executed by user, reveals scripting activity and administrative actions |
| **OneDrive Logs** | `AppData\Local\Microsoft\OneDrive\logs\` | Cloud synchronization activity, file uploads/downloads, sync errors |
| **Windows Search** | `AppData\Local\Microsoft\Windows Search\Data\Applications\Windows\Windows.db` | File content indexing database, can reveal document contents and metadata |

### Network & Connectivity

| Data Source | Location | Forensic Value |
|-------------|----------|----------------|
| **RDP History** | Registry: `HKCU\Software\Microsoft\Terminal Server Client\Default` | Remote Desktop connection targets, reveals lateral movement or remote access patterns |
| **WiFi Profiles** | `netsh wlan show profile` output | Wireless networks previously connected to, helps establish device location history |
| **USB Device History** | Registry: `HKLM\SYSTEM\CurrentControlSet\Enum\USBSTOR` | All USB storage devices connected, vendor/product IDs, serial numbers, connection timestamps |
| **Network Configuration** | `ipconfig /all`, `Get-NetAdapter`, `Get-NetRoute` | IP addresses, MAC addresses, DNS servers, routing tables, adapter status |
| **HOSTS File** | `%SystemRoot%\System32\drivers\etc\hosts` | DNS override entries, may reveal malware C2 redirection or development environments |

### File System & Storage

| Data Source | Location | Forensic Value |
|-------------|----------|----------------|
| **Recycle Bin** | `C:\$Recycle.Bin\` | Deleted files metadata ($I files), original filenames and paths, deletion timestamps |
| **Windows Temp** | `%SystemRoot%\Temp\` | System-level temporary files, installer remnants, crash dumps, malware staging areas |
| **User Temp** | `AppData\Local\Temp\` | User-level temporary files, browser cache, application temp data, downloaded executables |
| **C:\ Directory Listing** | Root directory enumeration | Top-level file/folder structure, reveals unusual directories or staging areas |

### Domain Controller & Server Role Artifacts
*(Collected automatically when roles are detected)*

| Data Source | Location | Forensic Value |
|-------------|----------|----------------|
| **NTDS.dit** | `C:\Windows\NTDS\ntds.dit` | Active Directory database - all domain users, computers, groups, password hashes, Kerberos keys |
| **SYSVOL** | `C:\Windows\SYSVOL\sysvol\` | Group Policy Objects (GPOs), logon scripts, domain-wide policies, persistence mechanisms |
| **DNS Logs** | `C:\Windows\System32\dns\dns.log` | DNS queries and responses, can reveal command & control (C2) communications |
| **DNS Zone Files** | `C:\Windows\System32\dns\*.dns` | DNS zone configurations, A/AAAA/CNAME records, helps map internal network infrastructure |
| **DHCP Database** | `C:\Windows\System32\dhcp\*.mdb` | IP address leases, MAC to IP mappings, device hostname history, connection timestamps |
| **IIS Logs** | `C:\inetpub\logs\LogFiles\` | Web server access logs (last 90 days), POST/GET requests, authentication attempts, suspicious URIs |
| **IIS Configuration** | `C:\Windows\System32\inetsrv\config\` | Web application configurations, virtual directories, authentication settings, installed modules |
| **Hyper-V Config** | `C:\ProgramData\Microsoft\Windows\Hyper-V\` | Virtual machine configurations, reveals rogue VMs or compromised guest systems |
| **DFS Metadata** | `C:\System Volume Information\DFSR\` | Distributed File System replication logs, file staging activity across domain controllers |
| **Print Server Metadata** | `C:\Windows\System32\spool\PRINTERS\` | Print job metadata, reveals document names, user activity, potential data exfiltration |

### Chain of Custody & Verification

| Data Source | Purpose | Forensic Value |
|-------------|---------|----------------|
| **SHA256 Manifest** | Generated with `hashdeep64.exe` | Cryptographic hashes of all collected files, ensures data integrity and admissibility |
| **Collection Log** | `forensic_collection_[HOSTNAME]_[TIMESTAMP].txt` | Complete collection timeline, warnings, errors, tool execution details, establishes provenance |
| **Collection Summary** | `COLLECTION_SUMMARY.txt` | Statistics, success rate, detected server roles, hypervisor information, quick reference report |

### Optional Features

- **`-NoZip` Parameter**: Skip compression for collections >4GB or when immediate analysis is needed
- **Automatic 64-bit Tool Selection**: Prefers 64-bit binaries (hashdeep64, sigcheck64, strings64) for better performance
- **Path Flattening**: Long registry paths (>200 chars) automatically copied to flat structure for hash compatibility
- **Role-Based Collection**: Automatically detects and collects Domain Controller, DNS, DHCP, IIS, Hyper-V, DFS, and Print Server artifacts

# How to execute

1.  Open PowerShell with administrative privileges.
2.  Navigate to the script directory.
3.  Run the script: `.\collect.ps1`

For detailed, real-time output of the script's actions, use the `-Verbose` flag:

```powershell
.\collect.ps1 -Verbose
```

This will create a file "collected_files.zip" which can be imported into a forensic processing platform such as Cado Response.

## Phase 3: Post-Collection Analysis

Use `source/Analyze-Investigation.ps1` to analyze a specific investigation folder after collection.

### Prerequisites
- Zimmerman Tools installed under `tools/optional/ZimmermanTools/` with `net9` preferred (falls back to `net8`/`net6`).
- .NET Desktop Runtime 9 installed for `net9` tools.
- Investigation path format: `investigations/<Case>/<Host>/<YYYYMMDD_HHMMSS>`.

### Common Outputs
- `Phase3_EventLog_Analysis/` with parsed event logs CSV/JSON.
- `Phase3_Filtered_EventLog_Results.csv` with keyword/pattern filtered events.
- `Phase3_MFT_Analysis/MFT_Full.csv` with full MFT records.
- `Phase3_MFT_PathMatches.csv` with matched file/path records from the MFT.
 - Reporting:
     - Per-collection: `Collection` folder `Investigation_Summary.md`
     - Per-host: host folder `Host_Summary.md`
     - Investigation: case root `Investigation_Summary.md`

### Examples

Parse event logs:

```powershell
.\n+source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\Host\20250101_120000" -ParseEventLogs -EventLogFormat csv
```

Search event logs with keywords from a file, filter by Event IDs, and detect suspicious patterns:

```powershell
.
source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\Host\20250101_120000" `
    -SearchKeywordsFile "investigations\Case\search_terms_unique.txt" `
    -FilterEventIDs 4624,4688,7045 `
    -DetectSuspiciousPatterns
```

Search the Master File Table (MFT) for paths and filenames:

```powershell
.
source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\Host\20250101_120000" `
    -SearchMFTPaths "temp\test_files" `
    -SearchMFTPathsFile "investigations\Case\search_terms_unique.txt"
```

Run a Yara scan against collected files using a CSV of filenames and SHA256 hashes:

```powershell
.
source\Analyze-Investigation.ps1 -InvestigationPath "investigations\Case\Host\20250101_120000" `
    -YaraInputFile ".\sensitive_files.csv"
```

### Notes
- Tools are auto-detected with preference order: `net9` → `net8` → `net6`.
- Large datasets are processed in-memory; expect longer runtimes on big hosts.
- Results are written into the investigation folder alongside `collected_files`.

### Reporting Only (Summaries)
- Generate summaries across a case:
```powershell
.
source\Analyze-Investigation.ps1 -GenerateReport -CasePath "investigations\Case"
```

- Generate summaries for a host:
```powershell
.
source\Analyze-Investigation.ps1 -GenerateReport -HostPath "investigations\Case\Host"
```

- Generate summary for a single collection:
```powershell
.
source\Analyze-Investigation.ps1 -GenerateReport -CollectionPath "investigations\Case\Host\YYYYMMDD_HHMMSS"
```

Outputs include per-collection `Investigation_Summary.md`, aggregated `Host_Summary.md`, and top-level `Investigation_Summary.md`.

## Automated & Scheduled Execution

HER is designed to run non-interactively for integration with management tools and scheduled tasks:

### Windows Task Scheduler
```powershell
# Example: Schedule daily collection at 2 AM
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument `
  "-NoProfile -ExecutionPolicy Bypass -File C:\HER-Collector\run-collector.ps1 -AnalystWorkstation 'analyst-server'"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "HER-DailyCollection" -Trigger $trigger -Action $action -Principal $principal
```

### Group Policy / Management Tool
```powershell
C:\HER-Collector\run-collector.ps1 -AnalystWorkstation "analyst-workstation"
```

**Key features for automation:**
- **Non-interactive**: No prompts or dialogs, safe for scheduled/unattended execution
- **No verbose output**: Production mode silent (use `-Verbose` only for debugging)
- **Auto-unblock**: Extracted files are automatically unblocked on first run
- **Large collections**: Handles 30GB+ collections with automatic compression handling
- **Error resilience**: Continues collection even if individual artifacts fail
- **Comprehensive logging**: All results captured in `COLLECTION_SUMMARY.txt` and detailed log file
