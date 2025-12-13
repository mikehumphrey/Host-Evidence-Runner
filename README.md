# Cado Evidence Collector

A PowerShell script to collect forensic evidence from modern Windows systems (Windows 10, Windows 11, Server 2016+). This script modernizes the functionality of the original `collect.bat`.

## Data Collected

The script collects the following forensic artifacts:

-   **NTFS Metadata**:
    -   `$MFT` (Master File Table) from the system drive.
    -   `$LogFile` (NTFS Log File) from the system drive.
    -   `$UsnJrnl` (Update Sequence Number Journal) from the system drive.

-   **Windows Event Logs**:
    -   All `.evtx` files from `%SystemRoot%\System32\winevt\logs\`.

-   **Registry Hives**:
    -   System hives: `SYSTEM`, `SOFTWARE`, `SAM`, `SECURITY`, `DEFAULT` from `%SystemRoot%\System32\Config`.
    -   User hives: `NTUSER.DAT` and `UsrClass.dat` from each user profile.

-   **System Information & Configuration**:
    -   Recursive directory listing of the root of the system drive (`C:\`).
    -   HOSTS file from `%SystemRoot%\System32\drivers\etc\`.
    -   Windows Scheduled Tasks (XML files).
    -   Prefetch files from `%SystemRoot%\Prefetch\`.
    -   Amcache.hve (Application Compatibility cache).
    -   SRUM database (`SRUDB.dat`) - System Resource Usage Monitor.

-   **Search & Indexing**:
    -   Windows Search Index database (`Windows.db`).
    -   Per-user Windows Search data.

-   **File System & Storage**:
    -   Recycle Bin metadata (`$Recycle.Bin\`).
    -   Windows Temp directory (`%SystemRoot%\Temp\`).

-   **User Activity & History**:
    -   Browser history (Edge, Chrome, Firefox) for each user.
    -   Recent files and Jump Lists from `AppData\Roaming\Microsoft\Windows\Recent\`.
    -   PowerShell console history (`ConsoleHost_history.txt`).
    -   User Temp directories (`AppData\Local\Temp\`).
    -   OneDrive sync logs and metadata.

-   **Network & Connectivity**:
    -   Network adapter configuration and status.
    -   Routing table information.
    -   RDP (Remote Desktop Protocol) connection history.
    -   WiFi profile names and information.
    -   USB device history from the registry.

All collected data is placed in a `collected_files` directory and then compressed into a single `collected_files.zip` archive.

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
