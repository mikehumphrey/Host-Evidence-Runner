# Quick Start Guide - Cado-Batch Phase 2

**For:** Forensic investigators and system administrators  
**Time Required:** 5 minutes (reading) + collection time varies  
**Version:** 2.0 (Phase 2 Complete)

---

## 30-Second Overview

**Cado-Batch** is a forensic collection tool that gathers evidence from Windows servers.

- **Phase 1:** Event logs, registry, prefetch, shortcuts, scheduled tasks (always runs)
- **Phase 2:** Browser history, program execution, resource usage (always runs)
- **Total collected:** ~1,400 files per server
- **Total size:** 1.2-4 GB per server
- **Time:** 5-15 minutes per server

---

## Three Ways to Use It

### **Option 1: Single Server (Easiest)**

1. Insert USB drive with Cado-Batch
2. Open `RUN_ME.bat`
3. Wait 5-10 minutes
4. Copy `collected_files` folder to analyst

✅ Data automatically organized  
✅ Chain of custody documented  
✅ Phase 1 + Phase 2 completed  

---

### **Option 2: Multiple Servers (Professional)**

1. Run PowerShell script on your analyzer computer:
   ```powershell
   .\source\deploy_multi_server.ps1 -InvestigationName "BreachXYZ" `
     -Targets "SERVER01","SERVER02","SERVER03"
   ```

2. Results auto-organized in:
   ```
   investigations/BreachXYZ/
   ├── SERVER01/20251212_143000/collected_files/
   ├── SERVER02/20251212_143015/collected_files/
   └── SERVER03/20251212_143030/collected_files/
   ```

✅ Coordinated collection  
✅ Automatic timestamp tracking  
✅ Investigation metadata templates  
✅ Deployment report generated  

---

### **Option 3: Analyze What Was Collected**

Once you have collected_files/:

```powershell
# View what was collected
dir .\collected_files\

# Expected folders:
# - EventLogs/          (system activity timeline)
# - Registry/           (system configuration)
# - Prefetch/           (program execution history)
# - ScheduledTasks/     (automation persistence)
# - Phase2_Advanced_Analysis/
#   ├── Chrome_History_*.db        (web activity)
#   ├── Firefox_History_*.db       (web activity)
#   ├── Amcache.hve                (program history)
#   ├── SRUM_Database.dat          (resource usage)
#   └── Suspicious_Scheduled_Tasks.txt (threat indicators)
```

---

## What Gets Collected

### **Phase 1 (Automatic)**

| Data Source | What It Shows | Files |
|------------|---------------|-------|
| **Event Logs** | System activity timeline, logins, errors | 180+ |
| **Registry** | System config, installed software, user activity | 15 |
| **Prefetch** | Programs executed (last 8 times each) | 500+ |
| **LNK Files** | Recent file access, USB connections | 400+ |
| **Scheduled Tasks** | Automated programs and persistence | 200+ |

**Forensic Value:** Chain of custody evidence

---

### **Phase 2 (Automatic)**

| Data Source | What It Shows | Size |
|------------|--------------|------|
| **Chrome History** | Websites visited, search queries, bookmarks | 50-200 MB |
| **Firefox History** | Websites visited, search history | 20-100 MB |
| **Prefetch Analysis** | Program execution timeline (human-readable) | 1-5 MB |
| **Amcache** | Program execution over days/weeks | 10-30 MB |
| **SRUM** | CPU/network usage per application over time | 10-50 MB |
| **Task Analysis** | Suspicious scheduled task detection | 1-2 MB |
| **Edge/IE Cache** | Cached web content, cookies | 50-150 MB |

**Forensic Value:** User objectives, threat indicators, timeline

---

## Where to Find Data

```
collected_files/
├── EventLogs/
│   ├── Application.evtx        ← App errors and events
│   ├── System.evtx             ← System events
│   ├── Security.evtx           ← Login attempts
│   └── PowerShell_Operational.evtx  ← Script execution
│
├── Registry/
│   ├── SYSTEM                  ← Boot, networks, hardware
│   ├── SOFTWARE                ← Installed programs
│   └── Users/*/NTUSER.DAT      ← User activity
│
├── Prefetch/
│   ├── EXPLORER.EXE-[hash].pf  ← File browser
│   ├── POWERSHELL.EXE-[hash].pf ← PowerShell use
│   └── ... (500+ more)
│
├── Phase2_Advanced_Analysis/
│   ├── Chrome_History_Default.db
│   ├── Firefox_History_*.db
│   ├── Amcache.hve
│   ├── SRUM_Database.dat
│   └── Suspicious_Scheduled_Tasks.txt
│
├── SHA256_MANIFEST.txt         ← Chain of custody (CRITICAL)
├── ExecutableSignatures.txt    ← Code signing verification
└── collected_files.zip         ← Compressed copy
```

---

## Validation (Verify It Worked)

### **Quick Check**

```powershell
# Did everything collect?
dir .\collected_files\ | wc -l   # Should see 200+ items

# Is chain of custody documented?
Test-Path .\collected_files\SHA256_MANIFEST.txt   # Should be TRUE

# How much data?
(dir .\collected_files\ -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB  # Should be 1-4
```

### **Full Validation**

See: `PHASE_2_TESTING_GUIDE.md` (in documentation folder)

---

## Analysis Workflow

### **Step 1: Understand the Timeline**
```
Start with: Event Logs → Show system activity
Then cross-ref with: Prefetch → Program execution
Then add: Browser history → User objectives
Result: Master timeline of what happened
```

### **Step 2: Find Suspicious Activity**
```
Check: Suspicious_Scheduled_Tasks.txt
Look for: PowerShell, CMD, certutil, rundll32, etc.
Verify with: Event logs for execution evidence
Investigate: Prefetch to see when it ran
```

### **Step 3: Track User Actions**
```
Browser history: What websites visited
Prefetch: What programs used
Jump lists (LNK files): What documents accessed
Amcache: Long-term program execution
Result: Full picture of user activity
```

### **Step 4: Build Evidence**
```
Timeline: Cross-reference all sources
Integrity: Verify SHA256 manifests
Documentation: Collection log shows what was gathered
Chain of Custody: Maintained throughout
```

---

## Optional Advanced Analysis

If you have optional tools installed:

**For Prefetch Timeline:**
- Use: WinPrefetchView or PECmd
- Creates: Human-readable program execution timeline

**For Master Timeline:**
- Use: plaso/log2timeline
- Creates: CSV with all artifacts in chronological order

**For Program History:**
- Use: AmcacheParser
- Creates: CSV with program installations and executions

See: `PHASE_2_TOOLS_INSTALLATION.md` for download links

---

## Multi-Server Investigation Example

```powershell
# Set up investigation
mkdir investigations\RansomwareCase_20251212
cd investigations\RansomwareCase_20251212

# Run collection
..\..\source\deploy_multi_server.ps1 -InvestigationName "RansomwareCase" `
  -Targets "FileServer01", "FileServer02", "DC01"

# Results automatically created
RansomwareCase_20251212/
├── FileServer01/
│   ├── 20251212_080000/
│   │   └── collected_files/
│   └── 20251212_140000/         (re-collection for comparison)
│
├── FileServer02/
│   └── 20251212_081500/
│       └── collected_files/
│
└── DC01/
    └── 20251212_082000/
        └── collected_files/
```

---

## Common Questions

**Q: How long does collection take?**  
A: 5-15 minutes per server. Depends on system size and disk speed.

**Q: Can I run it while users are working?**  
A: Yes, but browser data and some logs may be locked. Best on quiet system.

**Q: What size is the output?**  
A: 1.2-4 GB per server (Phase 1 + Phase 2). Depends on event log size.

**Q: Can I do remote collection?**  
A: Yes! Use `deploy_multi_server.ps1` for multi-server deployment.

**Q: How do I preserve evidence?**  
A: SHA256_MANIFEST.txt in collected_files/ documents all file hashes.

**Q: Can I compare collections from different times?**  
A: Yes! Timestamps organize by collection time. Compare folder structures.

**Q: What if something fails?**  
A: Check `forensic_collection_*.txt` log file for details. Script continues on errors.

**Q: Where's the browser history?**  
A: In `Phase2_Advanced_Analysis/Chrome_History_*.db` and `Firefox_History_*.db`

---

## Troubleshooting

### **Collection failed**
→ Check: `forensic_collection_[hostname]_[timestamp].txt` log file
→ Shows: Exact error and what succeeded

### **Missing browser data**
→ Possible: Browser was running (lock file issue)
→ Solution: Close browser, re-run collection

### **No Phase 2 data**
→ Check: `Phase2_Advanced_Analysis/` folder exists
→ If missing: Check collection log for errors
→ Optional: Phase 2 tools gracefully degrade (collection continues)

### **Where's my file?**
→ Use: `dir .\collected_files\ -Recurse | where Name -like "*filename*"`
→ Or: Check SHA256_MANIFEST.txt for all collected files

### **How do I verify integrity?**
→ Run: 
```powershell
# Test that all files listed in manifest still exist
Get-Content .\collected_files\SHA256_MANIFEST.txt | 
  foreach { Verify-FileHash $_ }
```

---

## Next Steps After Collection

### **Short Term (Today)**
- [ ] Verify collection completed (see validation above)
- [ ] Copy results to safe location (SSD or archive)
- [ ] Create backup of investigation folder

### **Analysis (This Week)**
- [ ] Review Event logs for suspicious activity
- [ ] Check browser history for malicious sites
- [ ] Analyze scheduled tasks for persistence
- [ ] Build timeline from multiple sources

### **Reporting (Before Case Closes)**
- [ ] Document all findings
- [ ] Verify chain of custody (SHA256 manifests)
- [ ] Archive investigation folder
- [ ] Prepare evidence for legal if needed

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `RUN_ME.bat` | Entry point for single server |
| `source/collect.ps1` | Main collection script |
| `source/deploy_multi_server.ps1` | Multi-server orchestration |
| `forensic_collection_*.txt` | Collection log (check if issues) |
| `SHA256_MANIFEST.txt` | Chain of custody (CRITICAL) |
| `Phase2_Advanced_Analysis/` | Browser, program, resource data |

---

## Documentation Quick Links

| Want to... | Read |
|-----------|------|
| Understand the tool | README.md |
| Learn about data sources | CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md |
| Set up multi-server | PROJECT_STRUCTURE.md |
| Test Phase 2 | PHASE_2_TESTING_GUIDE.md |
| Understand folder organization | INVESTIGATION_RESULTS_STRUCTURE.md |
| Find specific document | DOCUMENTATION_INDEX.md |

---

## Summary

✅ **Insert USB → Run RUN_ME.bat → Wait → Copy results**

**OR**

✅ **Run deploy_multi_server.ps1 → Results auto-organized → Start analysis**

**All data collected:**
- Phase 1: Event logs, registry, prefetch, tasks, shortcuts
- Phase 2: Browser history, program execution, resource usage

**Chain of custody maintained:**
- SHA256 hashes in manifest
- Collection log documents process
- Timestamps track when collected

**Professional organization:**
- By investigation name
- By hostname
- By timestamp
- By data type

---

**Ready to investigate. Questions? See DOCUMENTATION_INDEX.md for complete guide reference.**
