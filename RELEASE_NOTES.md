# Release Notes - HER Collector

## Latest Release: 20251217_091555

### Summary
Production-ready forensic evidence collection toolkit with MAX_PATH resilience, non-interactive execution, and robust error handling.

### Key Improvements in This Release

#### 1. MAX_PATH Error Resilience ✓
- **Problem**: Collection failed when encountering paths exceeding Windows 260-character limit, particularly with nested user profiles in OneDrive environments
- **Solution**: 
  - Replaced `Copy-Item` with `robocopy` for Recent Items collection (robocopy handles long paths better)
  - Added intelligent error detection in catch block to distinguish MAX_PATH errors from fatal errors
  - MAX_PATH errors now log warnings and continue collection instead of aborting
  - Collection completes despite encountering some long-path artifacts
- **Impact**: Robust collection in real-world environments with deep folder structures

#### 2. Error Handling & Resilience ✓
- Collection continues despite MAX_PATH errors
- Non-fatal errors: Warnings logged, collection proceeds
- Fatal errors: Graceful exit with user-friendly messages
- Summary report includes artifact counts and any warnings

#### 3. Non-Interactive Execution ✓
- No interactive prompts or dialogs during collection
- Suitable for automated/scheduled execution via Windows Task Scheduler
- `$ProgressPreference = 'SilentlyContinue'` suppresses progress bars
- `$ErrorActionPreference = 'Continue'` allows resilient error handling

#### 4. Parameter Passing Fixed ✓
- Changed from array syntax to hashtable for proper PowerShell parameter binding
- Resolves: "A positional parameter cannot be found that accepts argument"

#### 5. File Unblocking ✓
- Automatic unblocking of files extracted from ZIP
- Prevents DLL initialization errors (exit code -1073741502)

#### 6. RUN_COLLECT.bat Improvements ✓
- Robust admin elevation checking
- OneDrive path compatibility (uses `pushd` instead of `cd /d`)
- Color-coded output for user guidance
- Analyst workstation prompt with localhost default
- Error messages with troubleshooting steps

---

## What Gets Collected

**400+ forensic artifacts** across these categories:

### System Events & Logs
- Event logs (System, Security, Application, PowerShell, Sysmon, Windows Defender, etc.)
- Windows Update history
- Task Scheduler events

### File System & Activity
- Windows Prefetch (Program execution history)
- Recycle Bin (deleted files)
- MFT (Master File Table)
- LogFile (NTFS transaction log)
- USN Journal (File change tracking)
- HOSTS file

### User Activity
- Browser history (Chrome, Edge, Firefox)
- PowerShell command history
- Recent files/jump lists
- Typed URLs
- Office recent documents

### System Configuration
- Registry hives (SYSTEM, SOFTWARE, SAM, NTUSER.DAT)
- Network configuration (IP, DNS, routing)
- Installed programs
- Scheduled tasks
- Services configuration

### Windows Search & Indexing
- Windows Search database
- Prefetch + Search index analysis

### Specialized Artifacts
- SRUM (System Resource Usage Monitor)
- Amcache (program execution history)
- User profiles
- OneDrive sync logs

### Server Role-Specific Data
- **Active Directory**: NTDS.dit, SYSVOL
- **DNS**: Zone files, DNS logs
- **IIS**: Log files, configuration
- **Hyper-V**: Virtual machine files
- **DFS**: Namespace and replication metadata
- **Print Server**: Print queue and spool files

---

## Usage

### Quick Start (Sysadmins)
```batch
REM Right-click RUN_COLLECT.bat
REM Select "Run as administrator"
REM When prompted, enter analyst workstation hostname (or press Enter for localhost)
```

### PowerShell Launch
```powershell
# From extracted directory (with analyst workstation)
.\run-collector.ps1 -AnalystWorkstation "analyst-workstation"

# Or without analyst workstation transfer (local collection only)
.\run-collector.ps1
```

### Automated/Scheduled Execution
```powershell
# Run via Windows Task Scheduler, Group Policy, or management tools
# Example: Task Scheduler action
# Program: C:\Temp\HER-Collector\run-collector.ps1
# Arguments: -AnalystWorkstation "analyst-workstation-hostname"
# Run with highest privileges: Yes
```

---

## Known Limitations

### MAX_PATH Constraints
- Windows MAX_PATH limit is 260 characters (directories: 248 characters)
- Some artifacts in very deep folder structures may be skipped
- Skipped artifacts are logged as warnings in collection log
- Collection continues despite MAX_PATH errors

### RawCopy.exe Artifacts
- Collections requiring forensic-grade locked file access (MFT, LogFile, USN Journal, NTDS.dit, SRUM, Amcache) depend on RawCopy.exe availability
- RawCopy.exe included in `tools/bins/`
- Works on Windows 7+ and Windows Server 2008+

---

## Collection Time Estimates

| Scenario | Time |
|----------|------|
| Small workstation (100GB drive, clean) | 15-20 minutes |
| Medium workstation (500GB+ drive, moderate activity) | 25-35 minutes |
| Large collection (1TB+ drive, heavy activity) | 45+ minutes |
| With robocopy analyst transfer | Add 5-10 minutes |
| Large collections without ZIP (-NoZip) | Can save 10-15 minutes compression time |

*Times vary based on disk speed, number of artifacts, and network latency for analyst transfer.*

---

## Troubleshooting

### Collection Exits With No Error
- Check Windows Event Viewer for PowerShell errors
- Ensure adequate disk space (30GB+ recommended for complete collection)
- Verify RawCopy.exe is present in tools/bins/

### RUN_COLLECT.bat Closes Immediately
- Ensure running as Administrator (right-click → Run as administrator)
- Check Windows Event Viewer → Windows Logs → Application for errors

### "Path length exceeded MAX_PATH" Warnings
- **This is expected in OneDrive/nested folder environments**
- Collection continues and completes normally
- Affected artifacts are skipped and logged in collection log
- Not a failure condition - collection succeeds despite MAX_PATH warnings

### Analyst Workstation Transfer Fails
- Verify network connectivity to analyst workstation
- Ensure C$ admin share is accessible
- Check firewall rules for robocopy (TCP 445 SMB)
- Files remain in local collection folder if transfer fails

### Collection Hangs or Very Slow
- Large collections can take 30+ minutes
- Monitor disk I/O in Task Manager
- If truly hung, terminate and run with `-NoZip` to save compression time

---

## Files Included

```
HER-Collector/
├── run-collector.ps1          # PowerShell launcher (main entry point)
├── RUN_COLLECT.bat            # Batch file launcher (alternative for cmd-only)
├── source/
│   └── collect.ps1            # Main forensic collection engine
├── tools/
│   └── bins/                   # Forensic tools (RawCopy, hashdeep, sigcheck, strings)
├── templates/                   # Incident log templates
├── README.md                    # Comprehensive documentation
└── LICENSE                      # MIT License
```

---

## Technical Details

### RawCopy.exe Usage
- Used for locked files: MFT, LogFile, USN Journal, NTDS.dit, SRUM, Amcache
- Invoked with `-WorkingDirectory` parameter for robust path handling
- Non-fatal errors: Missing files logged, collection continues

### Robocopy Usage
- Recent Items collection (long path resilience)
- Analyst workstation transfer (reliable network copy)
- Fallback for long-path artifacts

### Hashing & Integrity
- SHA256 manifest generated via hashdeep64.exe
- Hash computation handles MAX_PATH errors gracefully
- Files exceeding MAX_PATH path lengths excluded from hash manifest with warning

### Compression
- ZIP format (default): ~8-12GB collection compresses to 2-3GB
- Can skip via `-NoZip` flag for faster collection (no compression overhead)
- Timestamp sanitization (1980-2107 range) for ZIP compatibility

---

## Version Information
- **Version**: 1.0.1
- **Release Date**: December 17, 2025
- **Release ID**: 20251217_094106
- **PowerShell**: 5.1+ (Windows 7 SP1 and later)
- **Windows**: Windows 7 SP1 and later, Windows Server 2008 R2 and later

---

## Support & Feedback

For issues, feedback, or feature requests, refer to project documentation or contact your IT department.

**Key Contact Points**:
- Issues with specific artifact collection → Check collection log
- Network transfer problems → Verify SMB/445 connectivity
- Long path errors → Expected in OneDrive environments, collection continues
- Performance tuning → Use `-NoZip` for faster collection without compression
