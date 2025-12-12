# Cado Evidence Collector - Windows Server Forensics

A comprehensive PowerShell-based forensic collection tool for Windows Servers with domain services roles (AD/DC, DNS, DFS, CA). Designed for end-user deployment via USB or network share without requiring WinRM.

---

## Quick Overview

**What This Does:**
- Collects forensic artifacts from Windows Servers
- Works on physical servers and VMs (vSphere, Hyper-V, etc.)
- Detects server roles automatically (AD/DC, DNS, DFS, CA)
- Generates detailed logs and error reports
- Suitable for sysadmins with no forensics knowledge

**Key Features:**
- ✅ Simple USB deployment (double-click and run)
- ✅ Comprehensive error handling and logging
- ✅ Automatic server role detection
- ✅ Hypervisor detection (vSphere, Hyper-V, etc.)
- ✅ Works without WinRM or network access
- ✅ Produces forensically sound output

---

## For Different Users

### For Sysadmins (Receiving This Tool)
👉 **Read:** `QUICK_START.txt` (1-minute version) or `SYSADMIN_DEPLOYMENT_GUIDE.md`

**Summary:**
1. Copy tool to USB
2. Plug USB into server
3. Double-click `RUN_ME.bat`
4. Return USB with output folder

### For Forensic Analysts (Deploying This Tool)
👉 **Read:** `WINDOWS_SERVER_FORENSICS_PLAN.md` + `TECHNICAL_DOCUMENTATION.md`

---

## Installation & Deployment

### Step 1: Prepare USB Drive

1. **Copy the entire Cado-Batch folder to USB:**
   ```
   USB:\Cado-Batch\
   ├── RUN_ME.bat
   ├── collect.ps1
   ├── bins\
   │   └── RawCopy.exe (and other tools)
   └── (all other files)
   ```

2. **Verify USB contents:**
   - Ensure `RUN_ME.bat` is present
   - Ensure `collect.ps1` is present
   - Ensure `bins\` folder with `RawCopy.exe` exists

### Step 2: Hand Off to Sysadmin

1. **Print or email:**
   - `QUICK_START.txt` (brief instructions)
   - `SYSADMIN_DEPLOYMENT_GUIDE.md` (detailed guide)

2. **Deliver USB** with the tool

### Step 3: Receive Results

Sysadmin returns USB with:
- `collected_files_[ServerName]_[Timestamp]/` folder
- `FORENSIC_COLLECTION_LOG.txt` file

---

## What Gets Collected

### All Servers Collect:

**System Artifacts:**
- Windows Event Logs (all .evtx files)
- Registry hives (SYSTEM, SOFTWARE, SAM, SECURITY, DEFAULT)
- NTFS metadata ($MFT, $LogFile, $UsnJrnl)
- System configuration files
- Prefetch files
- Scheduled tasks

**User Activity:**
- Browser history (Edge, Chrome, Firefox)
- Recent files and jump lists
- PowerShell command history
- User profiles and settings

**Network & Storage:**
- Network configuration
- RDP connection history
- WiFi profiles
- USB device history
- Recycle bin contents
- Temporary files

### Role-Specific Collections:

**If Active Directory/Domain Controller:**
- NTDS.DIT (AD database)
- Sysvol replication folder
- Directory Service event logs

**If DNS Server:**
- DNS zone files
- DNS configuration
- DNS event logs

**If DFS Server:**
- DFSR metadata
- Replication staging folders
- DFS event logs

**If Certificate Authority:**
- Certificate database
- CRL distribution points
- CA event logs

---

## Output Structure

```
collected_files_[ServerName]_[Date]_[Time]/
├── System/                    (Registry, logs, system files)
├── EventLogs/                (All .evtx event log files)
├── ActiveDirectory/          (If DC - NTDS, sysvol, logs)
├── DNS/                      (If DNS - zone files, config)
├── DFS/                      (If DFS - metadata, staging)
├── CA/                       (If CA - certificates, CRL)
├── Users/                    (Per-user artifacts)
├── Network/                  (Network configuration)
└── ExecutionLog.txt         (Collection summary)
```

Output also includes:
- `FORENSIC_COLLECTION_LOG.txt` - Detailed execution log with any errors

---

## System Requirements

**Server Requirements:**
- Windows Server 2016 or newer
- Administrator access
- ~10GB free disk space (USB or local)
- 15-30 minutes runtime
- PowerShell execution enabled

**No Requirements For:**
- WinRM
- Network connectivity (USB works offline)
- External tools or dependencies
- Special configuration

---

## Deployment Methods

### Method 1: USB (Recommended for Isolated Networks)
```
1. Copy Cado-Batch to USB root
2. Deliver USB to sysadmin
3. Sysadmin plugs USB into server
4. Double-click RUN_ME.bat
5. Return USB with output folder
```

### Method 2: Network Share
```
1. Copy Cado-Batch to network share
2. Provide sysadmin share path
3. Sysadmin maps drive or opens in explorer
4. Runs RUN_ME.bat from share
5. Output collected to server or return location
```

### Method 3: Remote Console/RDP
```
1. RDP to server
2. Copy script locally or from USB
3. Run RUN_ME.bat
4. Collect output
```

---

## How to Use This Tool (Analyst)

### Preparing for Deployment

1. **Review Planning Document**
   - Read: `WINDOWS_SERVER_FORENSICS_PLAN.md`
   - Understand artifacts being collected
   - Assess hypervisor compatibility

2. **Prepare USB Drive**
   - Copy entire Cado-Batch folder
   - Verify all files present
   - (Optional) Test on non-production server

3. **Create Sysadmin Package**
   - Print or email `QUICK_START.txt`
   - Include `SYSADMIN_DEPLOYMENT_GUIDE.md`
   - Provide clear instructions for collection

### During Collection

- Sysadmin runs the tool (no analyst involvement needed)
- Tool handles all error cases automatically
- Comprehensive logging captures any issues

### After Collection

1. **Retrieve Output**
   - Get `collected_files_*` folder from USB
   - Get `FORENSIC_COLLECTION_LOG.txt`

2. **Review Logs**
   - Check for errors or warnings
   - Assess completeness of collection
   - Note any missing artifacts

3. **Begin Analysis**
   - Use organized artifact structure
   - Cross-reference events and artifacts
   - See `TECHNICAL_DOCUMENTATION.md` for analysis guidance

---

## Troubleshooting

### For Sysadmins (During Collection)

See `SYSADMIN_DEPLOYMENT_GUIDE.md` for troubleshooting.

### For Analysts (Before/After Collection)

**"RawCopy.exe not found"**
- Tool attempts collection without it
- Some locked files won't be collected
- Error is logged but non-critical

**"NTDS.DIT missing" (on Domain Controller)**
- Current version doesn't collect live NTDS.DIT
- Uses VSS in future versions
- Registry data partially compensates

**"Long runtime (>1 hour)"**
- Normal on large servers
- Event logs can be very large
- Recycle bin and temp folders accumulate
- Compression takes additional time

**"PowerShell execution disabled"**
- Check execution policy with sysadmin
- May require GPO change
- Batch wrapper attempts ExecutionPolicy bypass

**Incomplete collection**
- Check `FORENSIC_COLLECTION_LOG.txt` for errors
- Partial data is often still valuable
- Note missing artifacts in analysis

---

## Analysis Workflow

### 1. Initial Assessment
- Review execution log
- Check for errors/warnings
- Verify expected artifacts present
- Confirm server role detection

### 2. Artifact Analysis
**Timeline Analysis:** Event logs + prefetch + recent items
**User Activity:** Browser history + PowerShell history + recent items
**System Configuration:** Registry + scheduled tasks + network config
**File System:** $MFT + $UsnJrnl + recycle bin
**Specialized (AD/DNS/DFS/CA):** Role-specific artifacts

### 3. Correlation & Investigation
- Cross-reference multiple sources
- Build timeline of events
- Identify anomalies
- Document findings

---

## Technical Details

### Hypervisor Support

Tested and working on:
- ✅ VMware vSphere
- ✅ Microsoft Hyper-V
- ✅ Citrix XenServer
- ✅ Oracle VirtualBox
- ✅ KVM
- ✅ Physical Hardware

Script automatically detects and logs hypervisor environment.

### Role Detection

Automatically detects:
- Active Directory Domain Services
- DNS Server
- DFS (Distributed File System)
- Certificate Authority (ADCS)
- File Services
- Standalone servers (no specialized roles)

### Error Handling

**Critical Errors (exit script):**
- Administrator privileges not obtained
- PowerShell disabled or unavailable
- Required script files missing

**Non-Critical Errors (continue collection):**
- Individual artifact collection fails
- Optional artifacts unavailable
- Permissions denied on specific files
- Tools missing (RawCopy.exe, etc.)

All errors logged with context and timestamp.

---

## Security Considerations

**Data Protection:**
- Collection is read-only (no files modified)
- No credentials stored or transmitted
- No network communication (USB-based)
- NTFS permissions honored

**Execution:**
- Runs with administrator privileges
- All operations logged to audit trail
- No external dependencies or downloads
- Forensically sound collection methods

---

## Documentation Files

| File | Audience | Purpose |
|------|----------|---------|
| `QUICK_START.txt` | Sysadmin | 1-minute summary |
| `SYSADMIN_DEPLOYMENT_GUIDE.md` | Sysadmin | Complete deployment guide |
| `WINDOWS_SERVER_FORENSICS_PLAN.md` | Analyst | Technical planning & artifacts |
| `TECHNICAL_DOCUMENTATION.md` | Analyst | Architecture & analysis guide |
| `README.md` | Both | This file - overview |

---

## Support & Troubleshooting

### If Collection Fails

1. **Check the logs:**
   - `FORENSIC_COLLECTION_LOG.txt` (batch wrapper)
   - `logs\forensic_collection_*.txt` (PowerShell)

2. **Review error messages:**
   - Errors in red text during execution
   - Error context logged to file

3. **Common resolutions:**
   - See Troubleshooting section above
   - Review SYSADMIN_DEPLOYMENT_GUIDE.md
   - Check TECHNICAL_DOCUMENTATION.md

### Data Retrieved But Incomplete

- Check ExecutionLog.txt for warnings
- Note missing artifacts in report
- Partial data is still forensically valuable
- Can supplement with manual collection if needed

---

## Version History

**Version 1.0** (December 2025)
- Initial release
- Support for Windows Server 2016+
- Hypervisor detection
- Comprehensive logging
- End-user friendly deployment

---

## Future Enhancements

Planned for future versions:
- VSS integration for live NTDS.DIT collection
- Parallel collection optimization
- Hash verification of artifacts
- Encrypted output option
- Per-role collection modes
- Automated upload to forensic platform

---

## Licensing

This tool is provided under the Apache 2.0 License.
See LICENSE file for details.

---

## Created By

**Author:** Michael O. Humphrey  
**Date:** December 12, 2025  
**Repository:** Cado-Batch  
**Purpose:** Windows Server Forensic Evidence Collection

---

## Questions?

**For Sysadmins:**
- See: SYSADMIN_DEPLOYMENT_GUIDE.md
- Contact: The analyst who provided this tool

**For Analysts:**
- See: WINDOWS_SERVER_FORENSICS_PLAN.md
- See: TECHNICAL_DOCUMENTATION.md
- See: QUICK_START.txt (sysadmin perspective)
