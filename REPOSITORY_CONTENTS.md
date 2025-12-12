# Repository Contents - Cado-Batch

## Current Directory Structure

```
Cado-Batch/
├── RUN_ME.bat                           ★ START HERE (sysadmin launcher)
├── collect.ps1                          ★ CORE (main PowerShell script)
├── collect.bat                          (legacy batch wrapper)
├── LICENSE                              (Apache 2.0 license)
├── README.md                            (original README)
├── bins/
│   ├── RawCopy.exe                      ★ REQUIRED (file extraction tool)
│   ├── RawCopy_LICENSE.md               (RawCopy license)
│   └── Zip_License.txt                  (compression tool license)
├── logs/                                (created during execution)
│
├── DOCUMENTATION FILES:
├── QUICK_START.txt                      ← For sysadmins (1-minute guide)
├── SYSADMIN_DEPLOYMENT_GUIDE.md         ← For sysadmins (detailed)
├── ANALYST_DEPLOYMENT_CHECKLIST.md      ← For analysts (planning)
├── WINDOWS_SERVER_FORENSICS_PLAN.md     ← For analysts (technical)
├── TECHNICAL_DOCUMENTATION.md           ← For analysts (deep dive)
├── PACKAGE_SUMMARY.md                   ← Overview of package
├── README_NEW.md                        ← Updated README
└── THIS FILE (REPOSITORY_CONTENTS.md)
```

---

## Critical Files (Must Include in USB)

For the tool to function, USB must contain:

1. **RUN_ME.bat** (required)
   - User-friendly launcher wrapper
   - Handles permission elevation
   - Provides user feedback
   - File: ~23 KB

2. **collect.ps1** (required)
   - Main forensic collection script
   - Contains all collection logic
   - Comprehensive logging
   - File: ~18 KB

3. **bins\RawCopy.exe** (required)
   - Extracts locked files from disk
   - Used for $MFT, $LogFile, $UsnJrnl
   - File size: varies (typically 100-500 KB)

4. **bins\ folder structure** (required)
   - Must exist even if RawCopy.exe is the only tool inside
   - Script creates output in bins\ during execution

---

## Documentation Files

### For Sysadmins (System Administrators)

**QUICK_START.txt** (Print This First!)
- Length: 1-2 pages
- Reading time: 1-2 minutes
- Content: 3 simple steps + troubleshooting
- Use: Print or email to sysadmin
- Purpose: Ultra-brief overview

**SYSADMIN_DEPLOYMENT_GUIDE.md** (Complete Sysadmin Guide)
- Length: 8-10 pages
- Reading time: 10-15 minutes
- Content: Step-by-step instructions, FAQ, troubleshooting
- Use: Print or save for sysadmin reference
- Purpose: Complete deployment guide for non-technical sysadmin

### For Analysts (You)

**ANALYST_DEPLOYMENT_CHECKLIST.md** (Use Before Each Deployment)
- Length: 6-8 pages
- Reading time: 10-15 minutes
- Content: Pre-deployment, during, post-collection checklists
- Use: Print and use as deployment planning tool
- Purpose: Ensure nothing is missed before handing off

**WINDOWS_SERVER_FORENSICS_PLAN.md** (Technical Planning)
- Length: 12-15 pages
- Reading time: 30-40 minutes
- Content: Artifact inventory by role, architecture, challenges
- Use: Reference for understanding what's collected
- Purpose: Deep technical understanding of collection

**TECHNICAL_DOCUMENTATION.md** (Architecture & Analysis)
- Length: 15-18 pages
- Reading time: 30-40 minutes
- Content: Execution flow, logging system, hypervisor support, analysis workflow
- Use: Reference during and after collection
- Purpose: Understand how tool works and how to analyze output

### For Everyone

**README_NEW.md** (Updated Main README)
- Length: 10-12 pages
- Reading time: 15-20 minutes
- Content: Overview, deployment, troubleshooting, analysis
- Use: Reference guide
- Purpose: Central overview document

**PACKAGE_SUMMARY.md** (This Package Overview)
- Length: 10-12 pages
- Reading time: 15-20 minutes
- Content: Features, workflow, checklists, next steps
- Use: Understanding the complete package
- Purpose: High-level summary of what you have

---

## Suggested Reading Order

### Before Your First Deployment

**Week 1:**
1. Read: `PACKAGE_SUMMARY.md` (understanding what you have)
2. Read: `WINDOWS_SERVER_FORENSICS_PLAN.md` (technical understanding)
3. Read: `ANALYST_DEPLOYMENT_CHECKLIST.md` (planning approach)
4. Prepare: USB with Cado-Batch folder

**Week 2:**
1. Test: Run on non-production Windows Server (optional)
2. Review: `SYSADMIN_DEPLOYMENT_GUIDE.md` (put yourself in sysadmin's shoes)
3. Review: `TECHNICAL_DOCUMENTATION.md` (understand execution flow)
4. Prepare: Sysadmin package (print QUICK_START.txt + SYSADMIN guide)

### Before Each Deployment

1. Use: `ANALYST_DEPLOYMENT_CHECKLIST.md` (pre-deployment section)
2. Review: Target server details and roles
3. Prepare: Sysadmin with printed guides
4. Document: Server name, contact info, timeline

### During Collection

1. Monitor: Check in with sysadmin about progress
2. Be available: For questions or troubleshooting

### After Collection

1. Use: `ANALYST_DEPLOYMENT_CHECKLIST.md` (retrieval section)
2. Review: Logs immediately for errors
3. Review: `TECHNICAL_DOCUMENTATION.md` (analysis workflow section)
4. Analyze: Using structured approach
5. Document: Findings with artifact references

---

## File Descriptions

### Source Code Files

**collect.ps1** (Main Collection Script)
- **Language:** PowerShell 5.1+
- **Size:** ~18 KB
- **Purpose:** Core forensic collection logic
- **Key Features:**
  - Hypervisor detection (vSphere, Hyper-V, etc.)
  - Server role detection (AD/DC, DNS, DFS, CA)
  - Comprehensive error handling and logging
  - Artifact collection (NTFS, registry, events, user data, network)
  - Role-specific collection (if applicable)
- **Execution:** Requires administrator privileges
- **Output:** 
  - Data: `collected_files_[ServerName]_[Timestamp]/`
  - Log: `logs\forensic_collection_[ServerName]_[Timestamp].txt`

**RUN_ME.bat** (Launcher Script)
- **Language:** Batch/CMD
- **Size:** ~23 KB
- **Purpose:** User-friendly launcher for PowerShell script
- **Key Features:**
  - Administrator privilege elevation
  - PowerShell availability check
  - Script validation
  - User guidance and feedback
  - Error logging
  - Optional compression of output
- **Execution:** Double-click on Windows
- **Output:** 
  - Status: Console window with colored messages
  - Log: `FORENSIC_COLLECTION_LOG.txt`

**collect.bat** (Legacy Script)
- **Language:** Batch/CMD
- **Status:** Superseded by RUN_ME.bat + collect.ps1
- **Note:** Kept for reference, not used

### Utility Files

**bins\RawCopy.exe**
- **Purpose:** Extract locked files from live system
- **Use:** $MFT, $LogFile, $UsnJrnl extraction
- **License:** See RawCopy_LICENSE.md
- **Requirement:** Must be in bins\ folder

**bins\RawCopy_LICENSE.md**
- **Content:** RawCopy license text
- **Purpose:** Legal compliance

**bins\Zip_License.txt**
- **Content:** Compression tool license
- **Purpose:** Legal compliance

---

## Documentation Purpose Summary

| Document | Purpose | Keep Updated | Review Frequency |
|----------|---------|--------------|------------------|
| QUICK_START.txt | Sysadmin 1-minute guide | As script changes | Each deployment |
| SYSADMIN_DEPLOYMENT_GUIDE.md | Sysadmin complete guide | As script changes | Each deployment |
| ANALYST_DEPLOYMENT_CHECKLIST.md | Your planning tool | As process evolves | Each deployment |
| WINDOWS_SERVER_FORENSICS_PLAN.md | Technical reference | As artifacts change | When adding features |
| TECHNICAL_DOCUMENTATION.md | Architecture & analysis | As script evolves | When troubleshooting |
| PACKAGE_SUMMARY.md | Package overview | As tool matures | Quarterly |
| README_NEW.md | Central README | Keep current | Monthly |

---

## What Happens During Execution

### On Sysadmin's Server

```
User double-clicks RUN_ME.bat
    ↓
Batch checks for administrator privileges
    ↓
Batch checks for PowerShell availability
    ↓
Batch verifies collect.ps1 exists
    ↓
Batch launches PowerShell with collect.ps1
    ↓
PowerShell script initializes logging
    ↓
Detects hypervisor environment (logged)
    ↓
Detects installed server roles (logged)
    ↓
Collects artifacts:
  - NTFS metadata
  - Registry hives
  - Event logs
  - User artifacts
  - Network configuration
  - Role-specific artifacts (if applicable)
    ↓
Creates output folder: collected_files_[ServerName]_[Timestamp]/
    ↓
Compresses output (optional)
    ↓
Displays completion message
    ↓
User returns USB to analyst
```

### Output on Analyst's System

```
Organized folder structure:
├── System/              (core system artifacts)
├── EventLogs/          (all .evtx files)
├── Users/              (per-user artifacts)
├── Network/            (network configuration)
├── ActiveDirectory/    (if DC - NTDS, sysvol)
├── DNS/               (if DNS - zones, config)
├── DFS/               (if DFS - metadata)
├── CA/                (if CA - certificates)
└── ExecutionLog.txt   (summary of collection)

Plus:
- FORENSIC_COLLECTION_LOG.txt    (batch wrapper log)
- logs\forensic_collection_*.txt (PowerShell script log)
```

---

## Common Customizations

### If You Need to Modify the Script

**Safe to Modify:**
- Add additional artifact paths to collection
- Modify output directory naming
- Adjust logging verbosity
- Add additional role detection

**Don't Modify:**
- Error handling structure (critical for stability)
- Logging function (breaks log consistency)
- Privilege escalation checks (security-critical)
- Output folder structure (analysts rely on it)

### If You Need to Modify Documentation

**Safe to Update:**
- Add server-specific procedures
- Update troubleshooting section
- Add new hypervisor support notes
- Customize sysadmin guide for your organization

**Test After Changing:**
- Always test on non-production server
- Update all affected documentation
- Notify current deployments if critical change

---

## Backup & Version Control

### What to Keep in Git

```
✓ RUN_ME.bat                    (always version controlled)
✓ collect.ps1                   (always version controlled)
✓ All documentation files       (always version controlled)
✓ LICENSE                       (always version controlled)
```

### What NOT to Include in Git

```
✗ collected_files_* folders     (output data, not source)
✗ FORENSIC_COLLECTION_LOG.txt  (runtime logs, not source)
✗ logs/ directory              (runtime logs, not source)
✗ Large binary tools            (use git-lfs if needed)
```

### Before Deployment

1. Commit any changes: `git commit -am "update message"`
2. Tag version: `git tag -a v1.0 -m "version message"`
3. Create backup USB from tagged version
4. Test on non-production before deploying to production

---

## Troubleshooting Reference

### File Missing During Execution

**Error:** "collect.ps1 not found" or "RawCopy.exe not found"
**Check:** USB folder structure
**Solution:** Re-copy Cado-Batch folder to clean USB

### Administrator Error

**Error:** "Access Denied" or "Administrator Required"
**Check:** User permissions and UAC
**Solution:** Right-click > Run as Administrator

### PowerShell Execution Error

**Error:** "PowerShell is disabled" or execution policy error
**Check:** Enterprise Group Policy or local execution policy
**Solution:** May require IT to enable PowerShell or adjust policy

### Permission Denied on Artifacts

**Error:** Individual artifacts not accessible
**Check:** File locks and permissions
**Solution:** Non-critical, script logs and continues

---

## Next Steps

1. **Verify Contents:** Ensure all files listed above are present
2. **Test Execution:** Run on non-production server (optional but recommended)
3. **Prepare USB:** Copy Cado-Batch folder to USB drive
4. **Plan Deployment:** Use ANALYST_DEPLOYMENT_CHECKLIST.md
5. **Hand Off:** Provide sysadmin with QUICK_START.txt and SYSADMIN_DEPLOYMENT_GUIDE.md
6. **Analyze Results:** Use TECHNICAL_DOCUMENTATION.md analysis workflow

---

## Contact & Support

**Questions About the Tool:**
- See: TECHNICAL_DOCUMENTATION.md

**Questions About Deployment:**
- See: ANALYST_DEPLOYMENT_CHECKLIST.md

**Questions About Analysis:**
- See: WINDOWS_SERVER_FORENSICS_PLAN.md

**Questions to Ask Sysadmin:**
- Refer to: SYSADMIN_DEPLOYMENT_GUIDE.md FAQ section

---

**Repository:** Cado-Batch  
**Current Version:** 1.0  
**Last Updated:** December 12, 2025  
**Status:** Production Ready
