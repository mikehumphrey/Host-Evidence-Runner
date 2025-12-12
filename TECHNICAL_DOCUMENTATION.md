# Technical Documentation - Cado-Batch Forensic Collection Tool

**For Forensic Analysts and IT Professionals**

---

## Overview

This document provides technical details about the Cado-Batch forensic collection tool, including architecture, artifact collection, error handling, and analysis guidance.

---

## 1. Tool Architecture

### 1.1 Components

```
Cado-Batch/
├── RUN_ME.bat                           (User-friendly launcher)
├── collect.ps1                          (Main PowerShell collection script)
├── bins/
│   ├── RawCopy.exe                      (For raw file extraction)
│   └── (other required utilities)
├── logs/                                (Log output directory)
├── SYSADMIN_DEPLOYMENT_GUIDE.md        (End-user documentation)
├── WINDOWS_SERVER_FORENSICS_PLAN.md    (Technical planning doc)
└── TECHNICAL_DOCUMENTATION.md          (This file)
```

### 1.2 Execution Flow

```
RUN_ME.bat (Batch Wrapper)
    ↓
[Permission Check]
    ↓
[Initialize Logging]
    ↓
[Verify PowerShell]
    ↓
[Verify Script Exists]
    ↓
collect.ps1 (PowerShell Script)
    ├── [Initialize Logging]
    ├── [Detect Hypervisor]
    ├── [Detect Server Roles]
    ├── [Collect Core Artifacts]
    │   ├── NTFS Metadata
    │   ├── Event Logs
    │   ├── Registry
    │   └── ...
    ├── [Collect Role-Specific Artifacts]
    │   ├── AD/DC (NTDS.DIT, Sysvol)
    │   ├── DNS (Zone Files)
    │   ├── DFS (Metadata)
    │   └── CA (Certificates)
    ├── [Error Handling]
    └── [Output/Compression]
```

---

## 2. Data Collection Details

### 2.1 Core Artifacts (All Servers)

**NTFS Metadata:**
- `$MFT` (Master File Table) - collected via RawCopy.exe
- `$LogFile` (NTFS Journal) - collected via RawCopy.exe
- `$UsnJrnl` (Update Sequence Number Journal) - collected via RawCopy.exe

**Event Logs:**
- Location: `%SystemRoot%\System32\winevt\logs\`
- Formats: .evtx files (binary format)
- Channels: Security, System, Application, Directory Service, DNS, DFS, etc.

**Registry:**
- HKEY_LOCAL_MACHINE hives:
  - SYSTEM
  - SOFTWARE
  - SAM
  - SECURITY
  - DEFAULT
- User hives:
  - NTUSER.DAT (per-user)
  - UsrClass.dat (per-user, COM+ objects)

**System Configuration:**
- HOSTS file (`%SystemRoot%\System32\drivers\etc\hosts`)
- Scheduled Tasks (XML files from `%SystemRoot%\System32\Tasks`)
- Windows Search Index (`Windows.db`)
- Prefetch files (`%SystemRoot%\Prefetch\*.pf`)
- Amcache.hve (Application Compatibility cache)
- SRUM database (System Resource Usage Monitor)

**File System & Storage:**
- Recycle Bin metadata (`$Recycle.Bin\`)
- Windows Temp directory (`%SystemRoot%\Temp\`)
- User Temp directories (`%AppData%\Local\Temp\`)

**User Activity:**
- Browser history (Edge, Chrome, Firefox)
- Recent items and Jump Lists
- PowerShell console history
- OneDrive metadata (if configured)

**Network & Connectivity:**
- Network adapter configuration
- Routing table
- RDP connection history
- WiFi profiles
- USB device history

### 2.2 Role-Specific Artifacts

#### Active Directory / Domain Controller

**Critical Files:**
- `NTDS.DIT` - Active Directory database (collected via VSS if future versions support)
- `NTDS.WSHADOW` - Write-shadow database
- EDB transaction logs (`EDB*.LOG`)
- `Sysvol\` - Replication folder
- DCPromo logs (`%SystemRoot%\debug\dcpromo.*`)

**Registry Keys:**
- `HKLM\System\CurrentControlSet\Services\NTDS`
- `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Directory Services`

**Event Log Channels:**
- Directory Service
- DFS Replication
- File Replication Service

#### DNS Server

**Zone Files:**
- Location: `%SystemRoot%\System32\dns\`
- Format: Standard text-based DNS zone files
- Extension: `.dns`

**Configuration:**
- Registry: `HKLM\System\CurrentControlSet\Services\DNS\`
- Debug logs (if enabled): `%SystemRoot%\System32\dns\dns.log`

#### DFS (DFSR)

**Metadata:**
- Location: `%ProgramData%\Microsoft\DFS Replication\`
- ConflictAndDeleted folder
- Staging folder
- Database files

#### Certification Authority

**Database:**
- Location varies by configuration
- Certificate store
- CRL files
- Configuration: `HKLM\System\CurrentControlSet\Services\CertSvc\`

---

## 3. Logging System

### 3.1 Log File Format

```
[YYYY-MM-DD HH:MM:SS] [Level] Message
```

**Log Levels:**
- `[Info]` - Normal operation messages
- `[Warning]` - Non-critical issues (missing optional artifacts, etc.)
- `[Error]` - Critical failures

### 3.2 Log File Location

- **Batch Wrapper Log:** `FORENSIC_COLLECTION_LOG.txt` (root directory)
- **PowerShell Log:** `logs\forensic_collection_[ComputerName]_[Timestamp].txt`

### 3.3 Log Contents

Each execution logs:
- Start timestamp
- Computer name and user
- Server roles detected
- Hypervisor environment
- PowerShell version
- Each artifact collection attempt
- Success/warning/error messages
- End timestamp and status

---

## 4. Hypervisor Detection

The script automatically detects the following virtualization platforms:

**Detected Hypervisors:**
- VMware vSphere (checks manufacturer string "VMware")
- Microsoft Hyper-V
- Citrix XenServer
- KVM
- QEMU
- Oracle VirtualBox
- Physical Hardware (default if none detected)

**Detection Method:**
- Queries `Win32_ComputerSystem` WMI class
- Checks manufacturer and model strings
- Queries `Win32_PnPSignedDevice` for specific devices
- Logs detected environment

**Optimization:**
- Most collection methods are hypervisor-agnostic
- Network artifacts may show virtual network adapters (expected)
- Storage artifacts collected normally from virtual disks
- No special handling required for snapshot-based collection

---

## 5. Error Handling & Recovery

### 5.1 Error Categories

**Critical Errors** (Script exits):
- Administrator privileges not obtained
- PowerShell execution disabled
- Required script files missing
- Unrecoverable I/O errors

**Non-Critical Errors** (Script continues):
- Individual artifact collection fails
- Optional artifacts unavailable
- Permissions denied for specific files
- Tool utilities missing (RawCopy.exe)

### 5.2 Error Messages

All errors are:
- Written to console (colored red for visibility)
- Logged to both batch and PowerShell log files
- Descriptive with actionable resolution steps
- Include error context (line, exception details)

### 5.3 Partial Collection

If an error occurs:
- Successfully collected artifacts are preserved
- Error is logged with timestamp
- Script attempts to continue with remaining artifacts
- Output is still usable for partial forensic analysis

---

## 6. Output Structure

### 6.1 Directory Layout

```
collected_files_[ServerName]_[Timestamp]/
├── System/
│   ├── Registry/                    (HKEY_LOCAL_MACHINE hives)
│   │   ├── SYSTEM
│   │   ├── SOFTWARE
│   │   ├── SAM
│   │   ├── SECURITY
│   │   └── DEFAULT
│   ├── MFT_C.bin                   ($MFT from C: drive)
│   ├── LogFile_C.bin               ($LogFile from C: drive)
│   ├── UsnJrnl_C.bin               ($UsnJrnl from C: drive)
│   ├── C_Dir.txt                   (C: drive root directory listing)
│   ├── HOSTS                       (Network hosts file)
│   └── Prefetch/                   (*.pf files)
│
├── EventLogs/
│   ├── Application.evtx
│   ├── Security.evtx
│   ├── System.evtx
│   ├── Directory Service.evtx      (if DC)
│   ├── DNS Server.evtx             (if DNS)
│   ├── DFS Replication.evtx        (if DFS)
│   └── (other .evtx channels)
│
├── ScheduledTasks/                 (XML files from System32\Tasks)
├── Windows_Temp/                   (Temporary files)
├── RecycleBin/                     ($Recycle.Bin contents)
├── Amcache.hve                     (Application compatibility)
├── SRUDB.dat                       (System Resource Usage Monitor)
│
├── ActiveDirectory/                (If DC role detected)
│   ├── NTDS_Data/                 (NTDS.DIT and related)
│   ├── Sysvol/                    (Replication folder)
│   └── Logs/                      (Directory Service logs)
│
├── DNS/                            (If DNS role detected)
│   ├── Zones/                     (*.dns zone files)
│   ├── dns.log                    (Debug log, if enabled)
│   └── Logs/                      (DNS event logs)
│
├── DFS/                            (If DFS role detected)
│   ├── Metadata/                  (DFSR database)
│   ├── Staging/                   (Staging folders)
│   └── Logs/                      (DFS event logs)
│
├── CA/                             (If CA role detected)
│   ├── CertStore/                 (Certificate storage)
│   ├── CRL/                       (Certificate Revocation Lists)
│   └── Logs/                      (CA event logs)
│
├── Users/
│   └── [Username]/
│       ├── NTUSER.DAT
│       ├── UsrClass.dat
│       ├── RecentItems/           (LNK files, Jump Lists)
│       ├── Edge_History           (Edge browser history)
│       ├── Chrome_History         (Chrome browser history)
│       ├── Firefox_History        (Firefox browser history)
│       ├── ConsoleHost_history.txt (PowerShell history)
│       ├── LocalTemp/             (User temp files)
│       ├── OneDrive_Logs/         (Cloud sync metadata)
│       └── WindowsSearch/         (User search index)
│
├── Network/
│   ├── Network_IPConfig.txt       (IP configuration)
│   ├── Network_Adapters.txt       (Adapter details)
│   ├── Network_Routes.txt         (Routing table)
│   ├── RDP_ConnectionHistory.txt  (RDP connections)
│   └── WiFi_Profiles.txt          (WiFi profiles)
│
└── ExecutionLog.txt               (PowerShell execution summary)
```

### 6.2 Output Naming Convention

```
collected_files_[ComputerName]_[YYYYMMdd_HHmmss]/
```

Example:
```
collected_files_DC01_20251212_143022/
collected_files_FileServer_20251212_150845/
```

---

## 7. Analysis Workflow

### 7.1 Initial Assessment

1. **Check Execution Log**
   - Review `ExecutionLog.txt` and batch log
   - Note any warnings or partial collection
   - Identify errors that may affect analysis

2. **Review Server Configuration**
   - Check detected roles and hypervisor
   - Review network configuration
   - Assess system specifications

3. **Artifact Validation**
   - Verify all expected artifacts present
   - Check file sizes (unusually small = potential error)
   - Compare against known baselines

### 7.2 Analysis by Artifact

**Timeline Analysis:**
- Use event logs (EVTX files)
- Cross-reference with file system timestamps
- Examine prefetch files for execution history
- Review recent items and jump lists

**User Activity:**
- Analyze browser history for URL access patterns
- Review PowerShell history for command execution
- Examine recent items for accessed resources
- Check OneDrive logs for sync activity

**System Configuration:**
- Review registry for installed software
- Analyze scheduled tasks for automation
- Check network configuration for anomalies
- Review DNS cache and queries (in event logs)

**File System:**
- Examine USN Journal for file activity
- Analyze file permissions from MFT
- Review recycle bin for deleted files
- Check temp directories for artifacts

**Active Directory (if DC):**
- Analyze NTDS.DIT for user/computer objects
- Review sysvol for replication status
- Examine Directory Service event logs
- Check for unauthorized modifications

**DNS (if DNS Server):**
- Analyze zone files for DNS records
- Review DNS event logs for queries
- Check for unauthorized entries
- Examine DNS configuration for anomalies

**DFS (if DFSR Server):**
- Review DFSR metadata for replication status
- Analyze ConflictAndDeleted folders
- Examine DFS event logs
- Check staging folder contents

**Certificate Authority (if CA):**
- Review certificate database for issued certs
- Analyze request logs
- Check revocation list
- Examine CA event logs

---

## 8. Deployment Scenarios

### 8.1 USB Deployment (Recommended for Isolated Networks)

**Preparation:**
1. Copy entire Cado-Batch folder to USB root
2. Verify all files present (especially bins\RawCopy.exe)
3. Test on non-production server if possible

**Deployment:**
1. Physical delivery of USB to sysadmin
2. Provide SYSADMIN_DEPLOYMENT_GUIDE.md
3. Sysadmin double-clicks RUN_ME.bat
4. Script executes locally

**Collection:**
1. Sysadmin runs on server
2. Tool generates logs and output folder
3. Both are on USB drive

**Retrieval:**
1. Sysadmin returns USB drive
2. Analyst copies `collected_files_*` and logs
3. Analyst reviews logs for issues

### 8.2 Network Share Deployment

**Preparation:**
1. Copy Cado-Batch folder to secure network share
2. Set appropriate NTFS permissions
3. Ensure sysadmins can read share

**Deployment:**
1. Sysadmin maps network drive: `net use Z: \\server\share`
2. Navigates to Z:\Cado-Batch
3. Runs `RUN_ME.bat` from share

**Output:**
1. Data collected to local server
2. Copy output back to share for analyst
3. Or package for return via USB

### 8.3 Hypervisor (vSphere) Considerations

**VMs with Snapshots:**
- Collection is safe during snapshots
- No special configuration needed
- VSS operations work in VMs
- File locks handled via RawCopy.exe

**Network I/O:**
- May saturate VM network adapter temporarily
- Schedule collection during low-activity periods
- Consider network limitations

**Disk I/O:**
- VM storage may show increased latency
- Non-destructive read-only operations
- No impact on running applications

**vSphere Tools:**
- VMware tools not required
- Physical hardware detection works in VMs
- Network features accessible normally

---

## 9. Troubleshooting Guide

### 9.1 Common Issues and Resolution

**Issue: "Access Denied" on Registry Hives**
- Expected behavior (some hives are locked)
- RoboCopy continues with available files
- Errors logged but non-critical

**Issue: NTDS.DIT Too Small or Missing (on DC)**
- NTDS.DIT is live-locked by AD
- Current version collects system files as fallback
- Consider enabling VSS for future enhancement

**Issue: Long Runtime (>1 hour)**
- Normal on large servers with extensive logs
- Recycle Bin and Temp folders can be large
- Network delays if on network share
- Compression step will take additional time

**Issue: PowerShell Disabled**
- Enterprise policy may block PS execution
- Check `Get-ExecutionPolicy`
- May require GPO change or local admin approval
- Batch wrapper uses `-ExecutionPolicy Bypass`

**Issue: RawCopy.exe Not Found**
- Check bins\ folder exists on USB/share
- Verify RawCopy.exe file present
- File locks collection continues without it
- Error logged but script continues

**Issue: Log File Not Created**
- Verify write permissions to script directory
- Check USB drive has space
- Verify logs\ subdirectory created
- Check disk isn't full

### 9.2 Analysis of Log Errors

**Log Messages to Investigate:**
- `[Error]` messages - critical failures
- `[Warning]` messages - optional items missing
- File size mismatches - potential corruption
- Missing expected artifacts - check permissions

---

## 10. Security Considerations

### 10.1 Execution Context

**SYSTEM Privileges:**
- Batch wrapper elevates to admin
- PowerShell runs in elevated context
- Can access locked system files
- Credentials not stored (uses inherent SYSTEM account)

**Audit Trail:**
- All operations logged to text files
- Windows Event Log may record execution
- NTFS audit logs capture file access
- Complete timestamp trail in script log

### 10.2 Data Handling

**Collection Operations:**
- Read-only (no files modified)
- No network transmission (USB-based)
- No credential handling
- No external dependencies

**Output Files:**
- All files forensically clean (copies, not originals)
- Timestamps preserved
- No data modification
- Safe to transfer and analyze

---

## 11. Performance Metrics

### 11.1 Typical Collection Times

| Server Type | Size | Runtime | Output Size |
|------------|------|---------|------------|
| Workgroup Server | Small | 10-15 min | 500MB-1GB |
| File Server | Medium | 20-30 min | 2-5GB |
| Domain Controller | Large | 30-45 min | 3-8GB |
| Busy DC | Very Large | 45-60+ min | 5-15GB |

*Times vary based on disk activity, network, antivirus scanning*

### 11.2 Disk Space Requirements

**Pre-Collection:**
- Script itself: ~5MB
- RawCopy.exe and tools: ~15MB
- Total required: ~20MB free

**Output (varies by server):**
- Estimate: 1-2x current server active data size
- Recommend: 10GB+ free space on USB/target
- Compression reduces by 50-80% typically

---

## 12. Future Enhancements

**Planned Features:**
- VSS integration for live NTDS.DIT collection
- Parallel collection for multi-core optimization
- Hash verification of collected files
- Automated upload to forensic platform
- Encrypted output for sensitive environments
- Per-role collection modes (AD-only, DNS-only, etc.)

---

## 13. Contact & Support

**For Analysts:**
- Refer to WINDOWS_SERVER_FORENSICS_PLAN.md for detailed artifact info
- Review log files for error context
- Cross-reference artifacts for corroboration

**For Sysadmins:**
- Refer to SYSADMIN_DEPLOYMENT_GUIDE.md
- Provide analyst with log files
- Follow prompts on screen carefully

---

**Document Version:** 1.0  
**Created:** December 12, 2025  
**Compatibility:** Windows Server 2016 and newer  
**Last Updated:** December 12, 2025
