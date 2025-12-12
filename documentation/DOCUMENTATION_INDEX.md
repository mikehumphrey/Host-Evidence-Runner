# Cado-Batch Documentation Index

**Version:** 2.0 (Phase 2 Complete)  
**Last Updated:** December 12, 2025  
**Status:** Ready for multi-server investigations

---

## Quick Start (5 minutes)

**First time using Cado-Batch?**

1. **Understanding the project:** READ [Project Overview](#project-overview-documentation) → README.md
2. **See what's inside:** READ [Folder Structure](#project-structure-documentation) → PROJECT_STRUCTURE.md
3. **Start collecting:** 
   - Single server: Run `RUN_ME.bat` on target system
   - Multiple servers: Run `deploy_multi_server.ps1` from coordinator

---

## Documentation Structure

### **Project Overview Documentation**

| Document | Purpose | Audience | Read Time |
|----------|---------|----------|-----------|
| **README.md** | Project purpose and high-level overview | Everyone | 5 min |
| **PROJECT_STRUCTURE.md** | Folder organization and workflow | Investigators, Analysts | 15 min |

---

### **Deployment & Collection Documentation**

| Document | Purpose | Audience | Read Time |
|----------|---------|----------|-----------|
| **PHASE_1_FINAL_SUMMARY.md** | Phase 1 implementation status | Technical staff | 10 min |
| **PHASE_2_TOOLS_INSTALLATION.md** | Phase 2 features and optional tools | Technical staff | 20 min |
| **PHASE_2_TESTING_GUIDE.md** | How to test Phase 2 on Windows Server | QA, Testers | 30 min |
| **INVESTIGATION_RESULTS_STRUCTURE.md** | How results are organized by case/host/timestamp | Analysts, Managers | 15 min |

---

### **Technical Documentation**

| Document | Purpose | Audience | Read Time |
|----------|---------|----------|-----------|
| **PHASE_1_TOOLS_INSTALLATION.md** | Download and setup Phase 1 tools | System Admins | 10 min |
| **BINS_ORGANIZATION.md** | Tool inventory and locations | System Admins | 5 min |
| **CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md** | Forensic value of each data source | Analysts, Managers | 20 min |

---

## Workflow Documentation

### **For Single Server Collection**

1. Insert USB drive with Cado-Batch
2. Open `RUN_ME.bat` (double-click)
3. Wait for collection to complete (3-10 minutes)
4. Copy results folder to analyst
5. See: **PHASE_2_TESTING_GUIDE.md** → "Verification Checklist"

---

### **For Multi-Server Investigations**

1. **Preparation:**
   - Read: PROJECT_STRUCTURE.md (folder organization)
   - Create: investigations/[CaseName]/ folder
   - Edit: INVESTIGATION_METADATA.txt with case details

2. **Collection:**
   ```powershell
   .\source\deploy_multi_server.ps1 -InvestigationName "BreachXYZ" `
     -Targets "SERVER01", "SERVER02", "SERVER03"
   ```
   - See: **deploy_multi_server.ps1** (inline help)

3. **Results Organization:**
   - Auto-created: investigations/BreachXYZ/[HostName]/[Timestamp]/
   - See: INVESTIGATION_RESULTS_STRUCTURE.md

4. **Verification:**
   - Check: SHA256_MANIFEST.txt in each collection
   - See: PHASE_2_TESTING_GUIDE.md → "Troubleshooting"

5. **Analysis:**
   - Optional tools: PHASE_2_TOOLS_INSTALLATION.md → "External Tools"
   - Timeline generation: See INVESTIGATION_RESULTS_STRUCTURE.md

---

## Document Purpose Guide

### **Understand Data Collection**
→ CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md
- What data sources are collected
- Why each source matters forensically
- How Cado-Batch compares to Cado Host

### **Deploy and Operate**
→ PROJECT_STRUCTURE.md + PHASE_2_TESTING_GUIDE.md
- How to organize investigations
- How to collect from multiple servers
- How to verify collection success

### **Analyze Results**
→ INVESTIGATION_RESULTS_STRUCTURE.md + PHASE_2_TOOLS_INSTALLATION.md
- Where to find collected artifacts
- How to use optional analysis tools
- Timeline and correlation approaches

### **Troubleshoot Issues**
→ PHASE_2_TESTING_GUIDE.md → "Troubleshooting" section
- Common collection problems
- Solutions and recovery steps
- When to check logs

---

## File Structure Reference

```
Cado-Batch/
│
├── README.md                          ← Start here
│
├── documentation/                     ← All guides
│   ├── PHASE_1_TOOLS_INSTALLATION.md        (setup)
│   ├── PHASE_2_TOOLS_INSTALLATION.md        (features)
│   ├── PHASE_2_TESTING_GUIDE.md             (validation)
│   ├── INVESTIGATION_RESULTS_STRUCTURE.md   (organization)
│   ├── CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md (analysis)
│   ├── PROJECT_STRUCTURE.md                 (folders)
│   ├── BINS_ORGANIZATION.md                 (tools)
│   └── PHASE_1_FINAL_SUMMARY.md             (status)
│
├── source/                            ← Collection scripts
│   ├── collect.ps1                          (Phase 1 & 2)
│   ├── collect.bat
│   ├── RUN_ME.bat                           (entry point)
│   └── deploy_multi_server.ps1              (multi-server)
│
├── tools/                             ← All executables
│   ├── bins/                                (Phase 1 tools)
│   │   ├── hashdeep.exe, hashdeep64.exe
│   │   ├── strings.exe, strings64.exe
│   │   ├── sigcheck.exe, sigcheck64.exe
│   │   ├── RawCopy.exe, zip.exe
│   │   └── MANIFEST.md
│   │
│   └── optional/                           (Phase 2 optional)
│       ├── WinPrefetchView/
│       ├── PECmd/
│       └── AmcacheParser/
│
├── investigations/                    ← Investigation results
│   ├── [InvestigationName_YYYYMMDD]/
│   │   ├── INVESTIGATION_METADATA.txt
│   │   ├── INCIDENT_LOG.txt
│   │   ├── [HostName]/
│   │   │   └── [Timestamp]/
│   │   │       ├── collected_files/
│   │   │       └── forensic_collection_*.txt
│   │   └── ...
│   │
│   └── README_INVESTIGATIONS.md       ← See: INVESTIGATION_RESULTS_STRUCTURE.md
│
├── templates/                         ← Reusable templates
│   ├── investigation_metadata_template.txt
│   ├── incident_log_template.txt
│   ├── collection_report_template.txt
│   └── analysis_summary_template.txt
│
├── logs/                              ← Execution logs (created at runtime)
│   └── forensic_collection_*.txt
│
├── PROJECT_STRUCTURE.md               ← Folder organization guide
├── LICENSE
└── .gitignore
```

---

## Phase Progression

### **Phase 1** (COMPLETE ✅)

**Status:** Production-ready

**What it does:**
- Collects event logs (180+ files)
- Copies registry hives
- Gathers prefetch files (500+)
- Collects LNK/shortcut files (400+)
- Exports scheduled tasks (200+)
- Generates SHA256 manifest (chain of custody)
- Verifies digital signatures
- Extracts strings from artifacts

**Tools Involved:**
- hashdeep.exe (hashing)
- strings.exe (string extraction)
- sigcheck.exe (signature verification)
- RawCopy.exe (locked files)

**Documentation:**
- PHASE_1_TOOLS_INSTALLATION.md
- PHASE_1_FINAL_SUMMARY.md

---

### **Phase 2** (COMPLETE ✅)

**Status:** Production-ready

**What it does:**
- Extracts Chrome browser history
- Extracts Firefox browser history
- Analyzes prefetch files (human-readable)
- Detects suspicious scheduled tasks
- Collects Amcache (program execution history)
- Collects SRUM (system resource usage)
- Gathers browser artifacts (Edge, IE)

**Optional Analysis Tools:**
- WinPrefetchView (prefetch parsing)
- PECmd (detailed timeline)
- AmcacheParser (program execution)
- plaso/log2timeline (master timeline)

**Documentation:**
- PHASE_2_TOOLS_INSTALLATION.md
- PHASE_2_TESTING_GUIDE.md

---

### **Phase 3** (PLANNED 🔵)

**Status:** Planned for future

**Planned additions:**
- Live network connections
- Open file handles
- Running processes (full command-line)
- Loaded DLLs per process
- Volatile memory analysis
- Process injection detection
- Advanced threat indicators

**Documentation:**
- To be created after Phase 2 validation

---

## Data Collection Summary

### **What Gets Collected**

| Category | Count | Phase | Forensic Value |
|----------|-------|-------|-----------------|
| Event Log files | 180+ | 1 | ⭐⭐⭐⭐⭐ |
| Registry hives | 15 | 1 | ⭐⭐⭐⭐⭐ |
| Prefetch files | 500+ | 1 | ⭐⭐⭐⭐ |
| LNK/shortcuts | 400+ | 1 | ⭐⭐⭐⭐ |
| Scheduled tasks | 200+ | 1 | ⭐⭐⭐⭐ |
| Browser profiles | 3-10 | 2 | ⭐⭐⭐⭐⭐ |
| Amcache database | 1 | 2 | ⭐⭐⭐⭐ |
| SRUM database | 1 | 2 | ⭐⭐⭐ |
| **TOTAL** | **~1,400** | - | - |

**Total Size:** 1.2-4 GB per server (Phase 1 + Phase 2)

---

## Use Cases

### **Incident Response**
1. **Initial Investigation:** Collect Phase 1 data for timeline
2. **Deep Dive:** Collect Phase 2 for browser activity and program history
3. **Timeline Building:** Use CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md correlations
4. **Multi-Server:** Use deploy_multi_server.ps1 for rapid domain-wide collection

See: PROJECT_STRUCTURE.md → "Incident Workflow"

---

### **Insider Threat Investigation**
1. **User Activity:** Focus on Phase 2 browser history and prefetch
2. **Lateral Movement:** Check for suspicious scheduled tasks
3. **Data Exfiltration:** Review network SRUM usage and browser bookmarks
4. **Timeline Correlation:** Build master timeline from all sources

See: INVESTIGATION_RESULTS_STRUCTURE.md → "Timeline Analysis"

---

### **Compliance Review**
1. **System State:** Collect Phase 1 registry for installed software
2. **Update Status:** Check Windows patches in registry
3. **Anti-Virus Status:** Review Windows Defender logs in event logs
4. **Anomalies:** Check suspicious scheduled tasks in Phase 2

See: CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md → "Registry/Event Log Value"

---

### **Malware Analysis**
1. **Execution Timeline:** Prefetch shows program execution
2. **Persistence Mechanisms:** Scheduled tasks reveal autostart methods
3. **Command & Control:** Browser history shows attacker C2 domains
4. **Lateral Movement:** Event logs show privilege escalation attempts

See: CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md → "Analysis Guide"

---

## Troubleshooting Index

**Issue** | **Documentation** | **Section**
----------|------------------|----------
Can't find collected data | PROJECT_STRUCTURE.md | "Troubleshooting"
Collection failed | PHASE_2_TESTING_GUIDE.md | "Troubleshooting"
Tools not found | BINS_ORGANIZATION.md | Full doc
Browser data missing | PHASE_2_TESTING_GUIDE.md | "Test 1-3"
Prefetch incomplete | PHASE_2_TESTING_GUIDE.md | "Troubleshooting"
Multi-server deployment issues | deploy_multi_server.ps1 | Inline help

---

## Decision Tree: Which Document to Read

```
START: I need to...

  ├─ Understand what Cado-Batch does
  │  └─→ README.md
  │
  ├─ Deploy collection on 1 server
  │  └─→ RUN_ME.bat (click it)
  │      Then: PHASE_2_TESTING_GUIDE.md → Verification
  │
  ├─ Deploy collection on 10+ servers
  │  └─→ deploy_multi_server.ps1 (inline help)
  │      Then: INVESTIGATION_RESULTS_STRUCTURE.md
  │
  ├─ Understand investigation folder structure
  │  └─→ PROJECT_STRUCTURE.md
  │
  ├─ Analyze collected data
  │  └─→ CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md
  │
  ├─ Set up optional analysis tools
  │  └─→ PHASE_2_TOOLS_INSTALLATION.md
  │
  ├─ Test Phase 2 features
  │  └─→ PHASE_2_TESTING_GUIDE.md
  │
  ├─ Troubleshoot collection problems
  │  └─→ PHASE_2_TESTING_GUIDE.md → Troubleshooting
  │      Or: Check forensic_collection_*.txt log files
  │
  ├─ Understand data organization
  │  └─→ INVESTIGATION_RESULTS_STRUCTURE.md
  │
  ├─ Learn about Phase 1 tools
  │  └─→ PHASE_1_TOOLS_INSTALLATION.md
  │
  └─ See overall project status
     └─→ PHASE_1_FINAL_SUMMARY.md
```

---

## Key Contacts & Resources

**For Technical Questions:**
- See PHASE_2_TESTING_GUIDE.md → Troubleshooting
- Check forensic_collection_*.txt log files
- Review documentation for your specific issue

**For Analysis Support:**
- CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md → Forensic Value Ratings
- PHASE_2_TOOLS_INSTALLATION.md → Analysis Tool Options
- INVESTIGATION_RESULTS_STRUCTURE.md → Timeline Building

**For Deployment Questions:**
- PROJECT_STRUCTURE.md → Deployment Scenarios
- deploy_multi_server.ps1 → Inline help (-?)
- INVESTIGATION_RESULTS_STRUCTURE.md → Workflow

---

## Document Versions

| Document | Version | Last Updated |
|----------|---------|--------------|
| README.md | 1.0 | 2025-12-12 |
| PROJECT_STRUCTURE.md | 1.0 | 2025-12-12 |
| PHASE_1_TOOLS_INSTALLATION.md | 1.1 | 2025-12-12 |
| PHASE_2_TOOLS_INSTALLATION.md | 1.0 | 2025-12-12 |
| PHASE_2_TESTING_GUIDE.md | 1.0 | 2025-12-12 |
| INVESTIGATION_RESULTS_STRUCTURE.md | 2.0 | 2025-12-12 |
| CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md | 1.0 | 2025-12-12 |
| BINS_ORGANIZATION.md | 1.0 | 2025-12-12 |
| PHASE_1_FINAL_SUMMARY.md | 1.0 | 2025-12-12 |
| DOCUMENTATION_INDEX.md | 2.0 | 2025-12-12 |

---

## Summary

✅ **What's Ready:**
- Phase 1 code: Complete and tested
- Phase 2 code: Complete and documented
- Tools: All Phase 1 tools installed and verified
- Folder structure: Organized for multi-server investigations
- Documentation: Comprehensive guides for all use cases

🔵 **What's Next:**
- Windows Server testing (in-progress)
- Phase 3 planning (optional)
- Optional analysis tool installation

---

**Questions? Start with the Decision Tree above, then reference the specific document for your use case.**
