# Windows Server Forensic Collection Tool - Implementation Plan

## Executive Summary
This document outlines the architecture and implementation strategy for a forensic collection tool designed for Windows Server environments with AD, DC, DNS, DFS, and CA roles. The tool will execute locally on each server without requiring WinRM, suitable for USB-based deployment and isolated network environments.

---

## 1. Analysis: Server-Specific Forensic Artifacts

### 1.1 Active Directory Domain Controller (AD/DC)
**Unique Artifacts:**
- **Active Directory Database Files**
  - `NTDS.DIT` - Main AD database (locked while running, requires VSS)
  - `NTDS.WSHADOW` - Active Directory write-shadow
  - `EDB.CHK` - Extensible Storage Engine checkpoint
  - `EDB.LOG` and `EDB*.LOG` - Transaction logs
  - Location: `%SystemRoot%\NTDS\`

- **Active Directory Logs**
  - Directory Service event log (already in EVTX collection)
  - Replication diagnostics
  - DCPromo logs: `%SystemRoot%\debug\dcpromo.*`

- **Sysvol Shared Folder**
  - Replication metadata
  - Group Policy files
  - Default location: `%SystemRoot%\sysvol\`

- **ADCS Certificate Store** (if CA role present)
  - Certificate database
  - CRL files
  - Request logs

### 1.2 DNS Server
**Unique Artifacts:**
- **DNS Zone Files**
  - Location: `%SystemRoot%\System32\dns\`
  - Standard zones (*.dns files)
  - Reverse lookup zones

- **DNS Logs**
  - Debug logs (if enabled): `%SystemRoot%\System32\dns\dns.log`
  - Event logs (Security, System, Application channels)
  - DNS Analytics events (newer servers)

- **DNS Server Configuration**
  - Registry hives containing DNS settings
  - `HKLM\System\CurrentControlSet\Services\DNS\`

### 1.3 DFS (Distributed File System)
**Unique Artifacts:**
- **DFS Metadata**
  - DFSR database: `%ProgramData%\Microsoft\DFS Replication\`
  - ConflictAndDeleted folder
  - PreExisting folder
  
- **DFS Configuration**
  - Registry: `HKLM\Software\Microsoft\Dfs\`
  - Group Policy applications

- **DFS Replication Logs**
  - Event logs: DFS Replication channel
  - Debug logs (if enabled)

### 1.4 Certification Authority (CA)
**Unique Artifacts:**
- **PKI Database**
  - Certificate database files
  - Location varies: `%ProgramData%\Microsoft\Crypto\RSA\MachineKeys\` or ADCS database

- **CA Configuration**
  - Registry: `HKLM\System\CurrentControlSet\Services\CertSvc\`
  - CA policy files
  - CRL distribution points

- **CA Logs**
  - Certification Authority log
  - Security audit logs
  - Request/renewal history

### 1.5 Common to All Server Roles
**Shared with Win11 Collection:**
- Registry hives
- Event logs (more extensive on servers)
- NTFS metadata ($MFT, $LogFile, $UsnJrnl)
- Prefetch files
- Scheduled tasks
- System configuration

---

## 2. Implementation Strategy

### 2.1 Architecture Overview

```
collect-server.ps1 (Main Script)
├── Config Section (Role detection, paths)
├── Core Collections (Common to all)
├── Role-Specific Modules
│   ├── AD/DC Collection
│   ├── DNS Collection
│   ├── DFS Collection
│   └── CA Collection
├── VSS Shadow Copy Management
├── Error Handling & Logging
└── Output & Compression
```

### 2.2 Key Design Decisions

**A. Volume Shadow Copy Service (VSS) Integration**
- **Requirement**: NTDS.DIT cannot be copied while AD is running
- **Solution**: Create VSS shadow copy at start, access files from shadow copy
- **Fallback**: Attempt collection with NTDS backup utility if VSS unavailable

**B. Role Detection**
- Automatically detect installed roles via WMI `Win32_ServerFeature`
- Allow manual override via parameters for targeted collection
- Skip irrelevant collections to reduce runtime

**C. Local Execution**
- No WinRM dependency
- Deploy via USB, network share, or remote console
- Standalone execution model
- Comprehensive logging for remote verification

**D. Credential Handling**
- Run as local SYSTEM (via Task Scheduler if needed for elevated operations)
- Embedded service account logic for cross-domain AD queries
- Alternatively: Pre-staged with appropriate domain credentials

**E. Output Structure**
```
collected_files_[ServerName]_[Timestamp]/
├── System/
│   ├── Registry/
│   ├── EventLogs/
│   ├── MFT/
│   └── SystemConfig/
├── ActiveDirectory/
│   ├── NTDS_Backup/
│   ├── Sysvol/
│   └── Logs/
├── DNS/
│   ├── Zones/
│   └── Logs/
├── DFS/
│   ├── Metadata/
│   └── Logs/
├── CA/
│   ├── Database/
│   └── Logs/
└── ExecutionLog.txt
```

---

## 3. Detailed Collection Requirements by Role

### 3.1 Active Directory / Domain Controller

**Critical Files (High Priority):**
- NTDS.DIT (via VSS backup)
- NTDS.WSHADOW
- EDB transaction logs
- Sysvol replication folder
- DCPromo logs

**Configuration:**
- `HKLM\System\CurrentControlSet\Services\NTDS`
- `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Directory Services`

**Event Log Channels:**
- Directory Service
- DFS Replication (if DFSR enabled)
- File Replication Service (legacy)

**Collection Method:**
```powershell
# VSS approach for NTDS.DIT
$vssWriter = Get-WmiObject Win32_ShadowCopy | Where-Object {$_.ID -like "*{backup}*"}
# Mount shadow copy and extract files
```

### 3.2 DNS Server

**Critical Files:**
- `%SystemRoot%\System32\dns\*.dns` - All zone files
- DNS debug log (if enabled)
- DNS server registry hive portion

**Event Log Channels:**
- DNS Server log
- System log (DNS events)
- DNS Analytics (Windows Server 2016+)

**Configuration Extraction:**
```powershell
# Export DNS zones and settings
Get-DnsServerZone | Export-Csv
dnscmd.exe /info > DNSServerInfo.txt
```

### 3.3 DFS (DFSR)

**Critical Locations:**
- `%ProgramData%\Microsoft\DFS Replication\*`
- DFSR staging folder
- ConflictAndDeleted folder

**Registry Keys:**
- `HKLM\Software\Microsoft\Dfs\`
- `HKLM\System\CurrentControlSet\Services\DFSR\`

**Event Logs:**
- DFS Replication channel
- File Replication Service (legacy)

### 3.4 Certification Authority

**Database Files:**
- Varies by CA type (Enterprise, Standalone)
- Location: Registry pointer in `HKLM\System\CurrentControlSet\Services\CertSvc\Configuration`

**Configuration:**
- CA policy files
- Root certificate files
- CRL distribution points

**Logs:**
- Certification Authority event log
- Request/revocation history (database-backed)

---

## 4. Technical Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| NTDS.DIT locked by AD | Use VSS shadow copy or ntdsutil backup |
| Large files (DB, logs) | Implement file size checks, selective compression |
| Replication traffic during collection | Schedule at off-hours or throttle network I/O |
| Requires elevated privileges | Embed into scheduled task or require admin context |
| Domain trust issues | Use computer account or pre-staged credentials |
| No WinRM availability | Standalone script with local execution only |
| Multi-role servers | Modular detection and conditional collection |

---

## 5. Implementation Phases

### Phase 1: Core Server Collection (Week 1-2)
- [ ] Base collect-server.ps1 with role detection
- [ ] Registry and event log collection
- [ ] NTFS metadata collection (same as Win11)
- [ ] Basic logging and error handling
- [ ] Output structuring

### Phase 2: Role-Specific Modules (Week 2-3)
- [ ] AD/DC module with NTDS.DIT via VSS
- [ ] DNS module with zone file collection
- [ ] DFS module with metadata
- [ ] CA module with certificate data
- [ ] Role detection and conditional execution

### Phase 3: Advanced Features (Week 3-4)
- [ ] Performance optimization (parallel collection where safe)
- [ ] Comprehensive credential handling
- [ ] Recovery/resume functionality
- [ ] Pre-flight validation checks
- [ ] Detailed forensic reporting

### Phase 4: Testing & Documentation (Week 4-5)
- [ ] Test on each role combination
- [ ] Document procedure for each role
- [ ] Create recovery instructions
- [ ] Performance benchmarking
- [ ] Security audit of collection method

---

## 6. Credential Handling Without WinRM

### Option A: SYSTEM Context Execution (Recommended)
**Method:**
- Package script as scheduled task XML or BAT wrapper
- Execute via Task Scheduler at SYSTEM level
- Script file deployed to accessible location

**Advantages:**
- No credential storage needed
- Highest privilege level
- Works across domain trusts

**Implementation:**
```powershell
# Create scheduled task to run script as SYSTEM
Register-ScheduledTask -TaskName "ForensicCollection" -Principal (New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest)
```

### Option B: Pre-Staged Domain Service Account
**Method:**
- Deploy with hardcoded service account credentials
- Use `Invoke-Command` with credentials for sensitive operations
- Script file signed and access-controlled

**Advantages:**
- Works with limited context execution
- Can target cross-domain operations
- Auditable via event logs

**Disadvantages:**
- Credentials in script (mitigation: encrypted config file)
- Requires maintenance (password changes)

### Option C: USB Deployment with Interactive Auth
**Method:**
- USB contains baseline script
- User provides credentials at execution time
- Script uses provided credentials for privileged operations

**Advantages:**
- No credential storage
- Maximum security awareness
- Works in isolated environments

**Disadvantages:**
- Manual intervention required
- Not suitable for mass deployment
- Slower execution

**Recommendation:** Use Option A (SYSTEM context) for automated deployment, Option B for cross-domain scenarios.

---

## 7. Deployment Methods (No WinRM)

### Method 1: USB Drive Deployment
**Steps:**
1. Copy collect-server.ps1 to USB root
2. Physical delivery to server
3. Execute from USB via local console or batch file
4. Collect output back to USB

**Best for:** Isolated networks, air-gapped systems

### Method 2: Network Share Deployment
**Steps:**
1. Place script on accessible SMB share
2. Use net use or Map-Network-Drive
3. Execute via `.\collect-server.ps1` from share
4. Output to local drive or secondary share

**Best for:** Internal network collection campaigns

### Method 3: Group Policy/Scheduled Task
**Steps:**
1. Deploy as startup/logon script via GPO
2. Scheduled execution via Domain-linked task
3. Output to centralized collection share
4. Post-process collected archives

**Best for:** Multi-server environments with AD

### Method 4: Remote Console / RDP Execution
**Steps:**
1. RDP/Console into server
2. Copy script locally or from USB
3. Execute in PowerShell
4. Retrieve output locally

**Best for:** Small-scale, targeted collection

---

## 8. Security Considerations

**Risk:** Malware detection from extensive collection operations
- **Mitigation:** Exclude AV scanning of script, output directory; execute during maintenance window

**Risk:** Credential exposure in script parameters
- **Mitigation:** Use SYSTEM context, environment variables, or encrypted config files

**Risk:** Collection interferes with running services
- **Mitigation:** Non-invasive read-only operations, VSS for locked files, test on non-production first

**Risk:** Output archive too large or performance impact
- **Mitigation:** Implement size limits, compression options, parallel collection on multi-core systems

**Risk:** Insufficient audit trail
- **Mitigation:** Comprehensive logging to script output, hash collection outputs, timestamp all operations

---

## 9. Success Metrics

- [ ] Script successfully executes on all 5 role types
- [ ] All critical forensic artifacts collected
- [ ] No data corruption (hash verification)
- [ ] Execution time < 30 minutes (targeted optimization)
- [ ] Output properly organized and indexed
- [ ] Clear execution log with any errors/warnings
- [ ] Compression ratio > 3:1 (typical for text-heavy logs)
- [ ] Script resilient to missing artifacts

---

## 10. Next Steps

1. **Create Role Detection Module**
   - WMI query for installed roles
   - Validate tool availability (RawCopy, etc.)

2. **Implement VSS Shadow Copy Logic**
   - Create VSS snapshot
   - Extract NTDS.DIT and related files
   - Clean up snapshots post-collection

3. **Develop Role-Specific Collection Functions**
   - AD/DC: NTDS backup, sysvol, logs
   - DNS: Zone files, configuration
   - DFS: Metadata, staging, logs
   - CA: Certificates, database, logs

4. **Build Modular Architecture**
   - Separate concerns (logging, error handling, I/O)
   - Allow enabling/disabling specific roles
   - Support dry-run mode

5. **Create Deployment Package**
   - Script + required tools (RawCopy.exe, etc.)
   - README with per-role instructions
   - Examples for each deployment method

---

## 11. Reference Architecture Comparison

| Aspect | Win11 Client | Server (Proposed) |
|--------|--------------|-------------------|
| Deployment | USB, local | USB, network, scheduled task |
| Privileges | Admin user | SYSTEM/Local Admin |
| Unique Artifacts | Browser, user profiles | NTDS, DNS zones, DFS, PKI |
| VSS Required | No | Yes (for NTDS.DIT) |
| Size Estimate | 500MB - 2GB | 2GB - 10GB (AD database) |
| Runtime | 5-10 minutes | 15-30 minutes |
| WinRM | Optional | Not used |

---

## Appendix A: Tool Requirements

**Required Tools:**
- RawCopy.exe (for locked files) - already available
- vshadow.exe (VSS utilities) - Windows SDK
- Optional: Nirsoft tools for registry/browser analysis

**PowerShell Modules:**
- Built-in cmdlets (no external dependencies)
- Optional: Active Directory module for AD queries

**External Dependencies:**
- None mandatory (graceful degradation if tools missing)

---

## Appendix B: Sample Role Combination Scenarios

1. **AD/DC Only** (Traditional Domain Controller)
   - Collect: System, Registry, NTDS, Sysvol, Directory Service logs

2. **AD/DC + DNS** (Domain Controller with integrated DNS)
   - Add: DNS zones, DNS configuration, DNS logs

3. **AD/DC + DFS** (DFS Namespace or Replication server)
   - Add: DFSR metadata, staging folders, replication logs

4. **AD/DC + CA** (Enterprise PKI)
   - Add: Certificate store, CRL, CA configuration

5. **Full Stack** (All roles)
   - Comprehensive collection of all above

6. **DNS Only** (Standalone DNS server)
   - System, Registry, DNS zones, DNS logs

7. **File Server with DFS**
   - System, Registry, DFSR metadata, file auditing

---

**Document Version:** 1.0  
**Created:** December 12, 2025  
**Status:** Planning Phase  
**Next Review:** After Phase 1 completion
