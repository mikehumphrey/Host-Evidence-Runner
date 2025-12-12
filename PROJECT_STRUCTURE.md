# Cado-Batch Project Structure

**Last Updated:** December 12, 2025  
**Purpose:** Organize forensic collection tool for multi-server investigations

---

## Directory Organization

```
Cado-Batch/
├── source/                          # Collection scripts
│   ├── collect.ps1                  # Main collection script (Phase 1 & 2)
│   ├── collect.bat                  # Batch launcher (non-admin awareness)
│   └── RUN_ME.bat                   # User-friendly entry point
│
├── tools/                           # All executables and utilities
│   ├── bins/                        # Phase 1: Core tools
│   │   ├── hashdeep.exe             # SHA256 hashing (771 KB, 32-bit)
│   │   ├── hashdeep64.exe           # SHA256 hashing (848 KB, 64-bit)
│   │   ├── strings.exe              # String extraction (361 KB, 32-bit)
│   │   ├── strings64.exe            # String extraction (467 KB, 64-bit)
│   │   ├── sigcheck.exe             # Signature verification (435 KB, 32-bit)
│   │   ├── sigcheck64.exe           # Signature verification (528 KB, 64-bit)
│   │   ├── RawCopy.exe              # Locked file extraction (710 KB)
│   │   ├── zip.exe                  # Compression utility (132 KB)
│   │   ├── hashdeep_LICENSE.txt
│   │   ├── SysInternals_LICENSE.txt
│   │   └── MANIFEST.md              # Tool inventory with SHA256 hashes
│   │
│   ├── optional/                    # Phase 2+: Optional analysis tools
│   │   ├── WinPrefetchView/         # Prefetch parser (download instructions)
│   │   ├── PECmd/                   # Advanced prefetch analysis
│   │   └── AmcacheParser/           # Program execution history
│   │
│   └── README_TOOLS.md              # Tool setup and usage guide
│
├── investigations/                  # Investigation results (data separate from code)
│   ├── [Investigation_Name]/        # Each investigation gets a folder
│   │   ├── INVESTIGATION_METADATA.txt
│   │   ├── INCIDENT_LOG.txt
│   │   │
│   │   ├── [HostName_01]/
│   │   │   ├── [20251212_143022]/   # Results by hostname + timestamp
│   │   │   │   ├── collected_files/
│   │   │   │   │   ├── EventLogs/
│   │   │   │   │   ├── Registry/
│   │   │   │   │   ├── Prefetch/
│   │   │   │   │   ├── LNK_Files/
│   │   │   │   │   ├── ScheduledTasks/
│   │   │   │   │   ├── Phase2_Advanced_Analysis/
│   │   │   │   │   │   ├── Chrome_History_*.db
│   │   │   │   │   │   ├── Firefox_History_*.db
│   │   │   │   │   │   ├── Prefetch_Analysis.txt
│   │   │   │   │   │   ├── Suspicious_Scheduled_Tasks.txt
│   │   │   │   │   │   ├── Amcache.hve
│   │   │   │   │   │   └── SRUM_Database.dat
│   │   │   │   │   ├── SHA256_MANIFEST.txt
│   │   │   │   │   ├── ExecutableSignatures.txt
│   │   │   │   │   └── collected_files.zip
│   │   │   │   └── forensic_collection_[HostName_01]_[timestamp].txt
│   │   │   │
│   │   │   └── [20251212_150000]/   # Multiple timestamps = re-collections
│   │   │
│   │   ├── [HostName_02]/
│   │   │   └── [20251212_143500]/
│   │   │
│   │   └── [HostName_03]/
│   │       └── [20251212_144200]/
│   │
│   ├── [Investigation_Name_2]/      # Multiple investigations
│   │   └── [HostNames]/
│   │       └── [timestamps]/
│   │
│   └── README_INVESTIGATIONS.md     # Investigation management guide
│
├── documentation/                   # Guides, reports, and references
│   ├── PHASE_1_TOOLS_INSTALLATION.md
│   ├── PHASE_2_TOOLS_INSTALLATION.md
│   ├── PHASE_2_TESTING_GUIDE.md
│   ├── PHASE_1_FINAL_SUMMARY.md
│   ├── BINS_ORGANIZATION.md
│   ├── CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md
│   ├── PROJECT_STRUCTURE.md          # This file
│   └── DOCUMENTATION_INDEX.md        # Master navigation guide
│
├── templates/                       # Output format templates
│   ├── investigation_metadata_template.txt
│   ├── incident_log_template.txt
│   ├── collection_report_template.txt
│   └── analysis_summary_template.txt
│
├── logs/                            # Collection logs (created at runtime)
│   └── forensic_collection_*.txt    # Timestamped logs per collection
│
├── README.md                        # Project overview
├── LICENSE                          # Project license
└── .gitignore                       # Git exclusions (investigations/ etc)
```

---

## Key Organization Principles

### 1. **Code/Scripts Separated from Data**
- **source/**: All collection scripts (version controlled)
- **tools/**: All executables and utilities (version controlled)
- **investigations/**: All collected data (NOT version controlled)

This allows clean git history without massive data files.

### 2. **Investigation-Based Organization**
```
investigations/
├── Ransomware_BreachXYZ/           # Investigation name
├── APT_Incident_Client_A/
└── Insider_Threat_Review/
```

Each investigation contains its own namespace for results.

### 3. **Host and Timestamp Tracking**
```
investigations/MyCase/HostName_01/20251212_143022/
                      ↓              ↓
                  HostName       Timestamp
```

Enables:
- Multiple collections from same host (different times)
- Results clearly labeled with source and date
- Easy historical analysis

### 4. **Data Structure Within Collections**
```
[Investigation]/[HostName]/[Timestamp]/
├── collected_files/                # Raw artifacts
│   ├── EventLogs/
│   ├── Registry/
│   ├── Prefetch/
│   ├── Phase2_Advanced_Analysis/   # Browser, prefetch analysis, etc.
│   ├── SHA256_MANIFEST.txt         # Chain of custody
│   ├── ExecutableSignatures.txt    # Code signing verification
│   └── collected_files.zip         # Compressed archive
│
└── forensic_collection_[host]_[timestamp].txt  # Collection log
```

---

## Deployment Scenarios

### **Scenario 1: Single Server (USB Deployment)**

1. Prepare USB drive with:
   - source/
   - tools/bins/
   - tools/optional/ (if needed)
   - RUN_ME.bat on root

2. Run on target server:
   ```
   Insert USB → Open RUN_ME.bat → Data collected to USB
   ```

3. Copy results to investigation folder:
   ```
   investigations/MyInvestigation/TargetServer/20251212_143022/
   ```

### **Scenario 2: Multiple Servers (Central Deployment)**

1. Network deployment from central console

2. Collect from multiple hosts:
   ```
   Server_A/20251212_143000/
   Server_B/20251212_143015/
   Server_C/20251212_143030/
   ```

3. Central analysis in `investigations/CaseXYZ/`

### **Scenario 3: Incident Response Chain**

1. Initial collection:
   ```
   investigations/BreachABC/Workstation_01/20251212_090000/
   ```

2. Follow-up collection after findings:
   ```
   investigations/BreachABC/Workstation_01/20251212_150000/
   ```

3. Analysis compares both timestamps

---

## File Organization Best Practices

### **For Investigators**

1. **Create investigation folder**:
   ```powershell
   mkdir investigations\IncidentName_YYYYMMDD
   ```

2. **Document the investigation**:
   ```powershell
   cp templates\investigation_metadata_template.txt `
      investigations\IncidentName_YYYYMMDD\INVESTIGATION_METADATA.txt
   ```

3. **Track collections**:
   ```powershell
   cp templates\incident_log_template.txt `
      investigations\IncidentName_YYYYMMDD\INCIDENT_LOG.txt
   ```

4. **Collect from each host**:
   ```powershell
   # Results auto-organize by hostname and timestamp
   # E.g., investigations\IncidentName_YYYYMMDD\SERVER01\20251212_143022\
   ```

### **For Multi-Server Investigations**

```
investigations/
└── RansomwareIncident_20251212/
    ├── INVESTIGATION_METADATA.txt          # Case info, investigators, scope
    ├── INCIDENT_LOG.txt                    # Collection timeline
    ├── FILE_MANIFEST.txt                   # Total files collected
    │
    ├── DC01_DomainController/
    │   └── 20251212_080000/                # Initial collection
    │   └── 20251212_150000/                # Re-collection with updated tools
    │
    ├── FileServer01/
    │   └── 20251212_081500/
    │
    ├── Workstation_User_A/
    │   └── 20251212_082000/
    │
    └── Analysis_Reports/                   # Generated analysis
        ├── Timeline_Master.csv             # Cross-system timeline
        ├── Indicators_of_Compromise.txt
        └── Recommendations.txt
```

---

## Version Control Considerations

### **Include in Git**
- ✅ source/ (scripts)
- ✅ tools/bins/ (with manifests)
- ✅ tools/optional/ (download instructions only)
- ✅ documentation/
- ✅ templates/

### **Exclude from Git** (.gitignore)
- ❌ investigations/ (collected data)
- ❌ logs/ (runtime logs)
- ❌ collected_files/ (artifacts)

**Example .gitignore:**
```
# Investigation data
investigations/
logs/
collected_files/

# System files
*.zip
*.log
Thumbs.db

# Optional tools (too large)
tools/optional/*/WinPrefetchView.exe
tools/optional/*/PECmd.exe
tools/optional/*/AmcacheParser.exe
```

---

## Investigation Workflow

### **Step 1: Prepare Investigation**
```powershell
# Create investigation folder
mkdir investigations\Incident_XYZ_20251212
cd investigations\Incident_XYZ_20251212

# Create metadata
Copy-Item ..\..\templates\investigation_metadata_template.txt INVESTIGATION_METADATA.txt
# Edit with case details, investigators, scope, authorization
```

### **Step 2: Collect from Target Host**
```powershell
# On collection machine, run:
.\source\collect.ps1  # Data collected to results folder

# Script automatically creates:
# investigations\Incident_XYZ_20251212\[HostName]\[Timestamp]\collected_files\
```

### **Step 3: Verify Collection**
```powershell
# Check that all expected files exist
Test-Path "investigations\Incident_XYZ_20251212\[HostName]\[Timestamp]\collected_files\SHA256_MANIFEST.txt"
Test-Path "investigations\Incident_XYZ_20251212\[HostName]\[Timestamp]\collected_files\Phase2_Advanced_Analysis\"
```

### **Step 4: Document Results**
```powershell
# Add to INCIDENT_LOG.txt
# - Collection hostname
# - Collection timestamp
# - Total files collected
# - Any issues or notes
# - Analyst name
```

### **Step 5: Analyze Data**
```powershell
# Use optional tools:
# - WinPrefetchView for prefetch analysis
# - PECmd for detailed timeline
# - AmcacheParser for program execution

# Cross-reference with event logs
# Build master timeline
```

---

## Tool Organization Details

### **Phase 1 Tools** (in tools/bins/)

| Tool | Size | Purpose | Status |
|------|------|---------|--------|
| hashdeep.exe | 771 KB | SHA256 hashing | ✅ Installed |
| hashdeep64.exe | 848 KB | SHA256 (64-bit) | ✅ Installed |
| strings.exe | 361 KB | String extraction | ✅ Installed |
| strings64.exe | 467 KB | Strings (64-bit) | ✅ Installed |
| sigcheck.exe | 435 KB | Signature verify | ✅ Installed |
| sigcheck64.exe | 528 KB | SigCheck (64-bit) | ✅ Installed |
| RawCopy.exe | 710 KB | Locked file copy | ✅ Installed |
| zip.exe | 132 KB | Compression | ✅ Installed |
| **TOTAL** | **4.2 MB** | | **Ready** |

### **Phase 2 Tools** (optional, in tools/optional/)

| Tool | Purpose | Download |
|------|---------|----------|
| WinPrefetchView | Prefetch parsing | https://www.nirsoft.net/utils/win_prefetch_view.html |
| PECmd | Advanced prefetch | https://github.com/EricZimmerman/PECmd/releases |
| AmcacheParser | Program timeline | https://github.com/EricZimmerman/AmcacheParser/releases |
| plaso/log2timeline | Master timeline | https://github.com/log2timeline/plaso |

---

## Investigation Data Management

### **Data Retention**

Recommended retention periods:
- **Active investigation**: Keep all versions/timestamps
- **Closed investigation**: Keep latest collection, archive others
- **Legal hold**: Keep all versions (may be subpoenaed)

### **Storage Considerations**

Expected sizes:
- **Single host collection**: 1.2-4 GB (Phase 1 + Phase 2)
- **10-host investigation**: 15-40 GB
- **100-host incident**: 150-400 GB

Disk space recommendations:
- Investigation folder: Fast SSD preferred
- Archive storage: USB external drives
- Cloud storage: Encrypted S3 with IAM controls

### **Compliance**

Ensure investigation folder structure supports:
- ✅ Chain of custody (timestamps, logs)
- ✅ Data integrity (SHA256 manifests)
- ✅ Audit trails (forensic_collection_*.txt logs)
- ✅ Evidence separation (per-host organization)

---

## Troubleshooting Structure Issues

### **Issue: Can't find collected data**
**Solution:** Check expected path:
```powershell
Get-ChildItem investigations\[InvestigationName]\
```

### **Issue: Multiple collections from same host**
**Expected:** Each in separate timestamp folder
```powershell
investigations\[Case]\[HostName]\20251212_143000\
investigations\[Case]\[HostName]\20251212_150000\  ← Different timestamp
```

### **Issue: Need to compare collections**
**Solution:** Tools can read both directories:
```powershell
# Compare event logs between two collections
Compare-Object (gc investigations\Case\Host\[time1]\...\Application.evtx) `
               (gc investigations\Case\Host\[time2]\...\Application.evtx)
```

---

## Document References

- **PHASE_2_TOOLS_INSTALLATION.md** - Tool setup and usage
- **PHASE_2_TESTING_GUIDE.md** - Validation procedures
- **CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md** - Forensic value of each data source
- **DOCUMENTATION_INDEX.md** - Master navigation

---

## Summary

This structure enables:
- ✅ Clean separation of code and data
- ✅ Investigation-based organization
- ✅ Multi-host deployment tracking
- ✅ Historical comparisons (timestamps)
- ✅ Professional forensic standards
- ✅ Version control best practices

**Ready for deployment across multiple servers and investigations.**
