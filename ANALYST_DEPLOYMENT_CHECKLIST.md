# Deployment Checklist - Analyst

**Use this checklist before handing off the forensic collection tool to a sysadmin.**

---

## Pre-Deployment Preparation

### Documentation Review
- [ ] Read `WINDOWS_SERVER_FORENSICS_PLAN.md` - understand what will be collected
- [ ] Review `TECHNICAL_DOCUMENTATION.md` - understand architecture & error handling
- [ ] Review `SYSADMIN_DEPLOYMENT_GUIDE.md` - understand end-user experience
- [ ] Print or save `QUICK_START.txt` - provide to sysadmin

### USB Drive Preparation
- [ ] Copy entire `Cado-Batch` folder to USB root
- [ ] Verify file structure matches:
  ```
  USB:\Cado-Batch\
  ├── RUN_ME.bat                     ← CRITICAL
  ├── collect.ps1                    ← CRITICAL
  ├── bins\RawCopy.exe               ← CRITICAL
  ├── LICENSE
  ├── QUICK_START.txt
  ├── SYSADMIN_DEPLOYMENT_GUIDE.md
  ├── WINDOWS_SERVER_FORENSICS_PLAN.md
  ├── TECHNICAL_DOCUMENTATION.md
  └── logs\
  ```
- [ ] Verify `RUN_ME.bat` is readable and executable
- [ ] Verify `collect.ps1` is readable
- [ ] Verify `RawCopy.exe` exists in `bins\` folder
- [ ] Test on non-production server if possible
- [ ] USB has at least 20GB free space

### Sysadmin Communication
- [ ] Identify target sysadmin and point of contact
- [ ] Provide clear instructions:
  - [ ] Print or email `QUICK_START.txt`
  - [ ] Print or email `SYSADMIN_DEPLOYMENT_GUIDE.md`
  - [ ] Explain physical handoff process
  - [ ] Set expectations on timeline (15-30 min collection + return time)
- [ ] Clarify what sysadmin should return:
  - [ ] `collected_files_[ServerName]_[Date]` folder
  - [ ] `FORENSIC_COLLECTION_LOG.txt` file

### Server Assessment
- [ ] Confirm target server details:
  - [ ] Server name/IP
  - [ ] OS version (Windows Server 2016+?)
  - [ ] Estimated disk size (impacts collection size)
  - [ ] Hypervisor type (if VM)
  - [ ] Installed roles (AD/DC, DNS, DFS, CA?)
- [ ] Identify collection window:
  - [ ] Best time to collect (off-peak hours preferred)
  - [ ] Risk assessment (read-only collection is safe)
  - [ ] Backup status (collection won't interfere)

---

## During Collection

### Monitor for Issues
- [ ] Stay available for questions from sysadmin
- [ ] Have phone number or contact method sysadmin can reach you
- [ ] Be prepared to troubleshoot if needed

### Expected Timeline
- [ ] USB delivery: ~ 1-5 minutes
- [ ] Initial setup on server: ~ 2-5 minutes
- [ ] Collection execution: 15-30 minutes (larger servers may take 45-60 min)
- [ ] USB return: ~ 1-5 minutes
- [ ] Total elapsed time: ~ 20 minutes to 1 hour

---

## Post-Collection Retrieval

### Receiving Output
- [ ] Receive USB back from sysadmin
- [ ] Extract `collected_files_*` folder
- [ ] Extract `FORENSIC_COLLECTION_LOG.txt`
- [ ] Review `FORENSIC_COLLECTION_LOG.txt` immediately for errors

### Log Review Checklist
- [ ] Check for `[Error]` entries - indicate critical failures
- [ ] Check for `[Warning]` entries - note what was skipped
- [ ] Verify server name and timestamp logged
- [ ] Verify hypervisor type detected
- [ ] Verify server roles detected correctly
- [ ] Confirm collection completed successfully

### Output Validation
- [ ] Folder named `collected_files_[ServerName]_[Timestamp]` present
- [ ] Expected subdirectories created:
  - [ ] `System\` (registry, MFT, etc.)
  - [ ] `EventLogs\` (evtx files)
  - [ ] `Users\` (user artifacts)
  - [ ] `Network\` (network config)
  - [ ] Role-specific folders (ActiveDirectory\, DNS\, etc. if applicable)
- [ ] `ExecutionLog.txt` present
- [ ] Output folder size reasonable (not suspiciously small)

### Failure Scenarios
- [ ] If collection failed entirely:
  - [ ] Review logs for error
  - [ ] Assess if issue is critical or recoverable
  - [ ] Plan for re-collection if needed
  - [ ] May need to adjust PowerShell execution policy or permissions
- [ ] If collection partially succeeded:
  - [ ] Note missing artifacts
  - [ ] Determine if re-collection necessary
  - [ ] Proceed with analysis of available data
- [ ] If collection completed with warnings:
  - [ ] Note what was skipped (usually optional items)
  - [ ] Determine impact on analysis
  - [ ] Document in final report

---

## Analysis Preparation

### Organize Collected Data
- [ ] Create forensic case folder
- [ ] Copy output folder into case
- [ ] Backup original output (not modified)
- [ ] Document chain of custody

### Begin Analysis
- [ ] Review `TECHNICAL_DOCUMENTATION.md` analysis workflow
- [ ] Start with timeline analysis (event logs + prefetch + recent)
- [ ] Cross-reference artifacts
- [ ] Build hypothesis and test with multiple sources
- [ ] Document findings with artifact references

### Document Findings
- [ ] Note any collection issues that may affect findings
- [ ] Reference specific log files and artifacts
- [ ] Use timestamps from event logs as anchors
- [ ] Consider gaps in data (if some artifacts missing)

---

## Lessons Learned (Post-Analysis)

After completing analysis:

- [ ] Document what worked well
- [ ] Note any improvements needed for future collections
- [ ] Record any server-specific issues
- [ ] Update sysadmin contact for next time
- [ ] Consider improvements to documentation if sysadmin had questions

### Potential Improvements
- [ ] If sysadmin struggled, update `SYSADMIN_DEPLOYMENT_GUIDE.md`
- [ ] If PowerShell issues occurred, document resolution
- [ ] If certain artifacts were missing, document workaround
- [ ] If output was larger than expected, adjust guidance

---

## Troubleshooting Guide (For You)

### Problem: `RUN_ME.bat` didn't execute
**Diagnosis:**
- Check if batch file is readable
- Verify PowerShell availability on target server
- Check execution policy

**Resolution:**
- Test batch file locally first
- Provide sysadmin with instructions to run as admin
- May need GPO change for PowerShell execution policy

### Problem: Collection took >2 hours
**Diagnosis:**
- Server has very large event logs or recycle bin
- Network latency (if on network share)
- Compression step is slow
- Antivirus interference

**Resolution:**
- Document as normal for large servers
- Can exclude compression in future if not needed
- May need to increase expected time guidance

### Problem: RawCopy.exe not found
**Diagnosis:**
- bins\ folder not copied properly
- USB corruption

**Resolution:**
- Verify bins\ folder present in root
- Re-copy Cado-Batch folder to clean USB
- Collection can continue without RawCopy (some files won't be collected)

### Problem: Output folder missing or very small
**Diagnosis:**
- Collection script encountered error early
- Permissions denied
- Script exited prematurely

**Resolution:**
- Review `FORENSIC_COLLECTION_LOG.txt` for error
- Check Windows PowerShell execution logs
- May need to re-run with different user context or permissions
- Try on different server to isolate issue

### Problem: Event logs mostly missing
**Diagnosis:**
- Event log location may have changed
- Permissions denied
- Event logs archived/rotated

**Resolution:**
- Verify output folder for EVTX files
- Check if archived logs directory exists
- May need manual collection of specific logs
- Document in analysis report

---

## Final Checklist Before Handoff

- [ ] USB contains all required files
- [ ] Sysadmin has printed `QUICK_START.txt`
- [ ] Sysadmin has printed `SYSADMIN_DEPLOYMENT_GUIDE.md`
- [ ] Sysadmin understands 3-step process (run, wait, return)
- [ ] Sysadmin has your contact info for issues
- [ ] Expected output location communicated
- [ ] Timeline expectations set
- [ ] Server name and role documented
- [ ] Collection window scheduled

---

## Notes

**Server Name:** _______________________

**Server Role:** _______________________

**Hypervisor (if VM):** _______________________

**Collection Date/Time:** _______________________

**Sysadmin Name/Contact:** _______________________

**Expected Output Location:** _______________________

**Special Instructions:**
```
[Space for special notes specific to this deployment]
```

**Known Issues/Workarounds:**
```
[Space for notes about this server or environment]
```

---

**Last Updated:** December 12, 2025
