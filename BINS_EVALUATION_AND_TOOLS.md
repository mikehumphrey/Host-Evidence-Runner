# Bins Folder Evaluation & Tool Recommendations

## Current Inventory

### Existing Tools (4 files)

| Tool | Version | Size | Purpose | License | Status |
|------|---------|------|---------|---------|--------|
| **RawCopy.exe** | Latest | ~150 KB | Extract locked NTFS files ($MFT, $LogFile, $UsnJrnl) | Creative Commons CC0 | ✅ Essential |
| **zip.exe** | Info-ZIP | ~100 KB | Compression utility for output packaging | BSD (Info-ZIP) | ✅ Current |
| **RawCopy_LICENSE.md** | - | - | RawCopy license documentation | - | ✅ Present |
| **Zip_License.txt** | - | - | Info-ZIP license documentation | - | ✅ Present |

### Assessment: Current State

**Strengths:**
- RawCopy: Excellent for locked file extraction (critical for forensics)
- zip.exe: Reliable compression for output packaging
- License compliance: Both major tools properly documented

**Gaps Identified:**
- No hash verification tools (SHA256/MD5 for integrity)
- No disk imaging capability (dd-like functionality)
- No registry export/parsing tools
- No advanced memory analysis
- No event log parsing tools
- No network capture capability
- No stealth/anti-forensics detection
- Limited diagnostic tools
- No file signature analysis
- No entropy/randomness detection

---

## Recommended Tools to Add

### Priority Level: CRITICAL (Add Immediately)
These tools address major gaps in current capability.

#### 1. **fciv.exe** - File Checksum Integrity Verifier
- **Purpose:** Compute and verify SHA1/MD5 hashes of collected files
- **Why:** Chain of custody requires integrity verification; detect tampering
- **Size:** ~50 KB
- **License:** Microsoft Public License (MS-PL) - Free
- **Integration:** Add hash manifest generation to collect.ps1
- **Command:** `fciv.exe -r -sha1 .\collected_files > forensics_hashes.txt`
- **Forensic Value:** HIGH - Essential for evidence integrity
- **Platform:** Windows only (perfect fit)

#### 2. **hashdeep.exe** (Alternative to fciv)
- **Purpose:** Generate cryptographic hashes (MD5, SHA1, SHA256, Tiger)
- **Why:** More modern than fciv, supports SHA256, cross-platform validation
- **Size:** ~80 KB
- **License:** Public Domain
- **Integration:** Can create hash trees and compare against baseline
- **Command:** `hashdeep -r -c sha256 .\collected_files > hashes.txt`
- **Forensic Value:** HIGH
- **Recommendation:** Add this instead of fciv for SHA256 support

#### 3. **ewf_tools (libewf/ewfverify.exe)**
- **Purpose:** Create/verify evidence files in EWF format (EnCase/FTK compatible)
- **Why:** Professional forensic format; chain of custody; industry standard
- **Size:** ~400 KB
- **License:** LGPL
- **Integration:** Optional output format for professional analysis
- **Forensic Value:** HIGH - Enables handoff to professional tools
- **Note:** Large but optional; consider for Phase 2

#### 4. **Nirsoft Tools Bundle** (Selective)
- **Purpose:** Registry parsing, log extraction, artifact analysis
- **Options:**
  - **EvtxExCmd.exe** (100 KB) - Parse Windows event logs to CSV/XML
  - **RegScanner.exe** (150 KB) - Registry analysis and export
  - **LastActivityView.exe** (80 KB) - Timeline analysis
- **Why:** Powerful artifact parsing; non-invasive readers
- **License:** Freeware (Nirsoft) - Free for forensic use
- **Forensic Value:** MEDIUM-HIGH
- **Recommendation:** Add EvtxExCmd.exe first for event log parsing

#### 5. **strings.exe** (SysInternals)
- **Purpose:** Extract ASCII/Unicode strings from binary files
- **Why:** Recover hidden strings from registry hives, binaries, unallocated space
- **Size:** ~80 KB
- **License:** Sysinternals license - Free
- **Integration:** Post-collection analysis tool for analysts
- **Forensic Value:** MEDIUM - Useful for deep artifact analysis
- **Command:** `strings.exe -a NTUSER.DAT > NTUSER_Strings.txt`

#### 6. **sigcheck.exe** (SysInternals)
- **Purpose:** Verify executable signatures and timestamps
- **Why:** Detect unsigned/tampered binaries; validate tool authenticity
- **Size:** ~100 KB
- **License:** Sysinternals - Free
- **Integration:** Verify collected executables; detect malware
- **Forensic Value:** MEDIUM - Important for executable analysis
- **Command:** `sigcheck.exe -e .\collected_files\Windows\System32\*.exe > executable_signatures.txt`

---

### Priority Level: HIGH (Add in Phase 2, within 2 weeks)
These tools enhance capabilities and add valuable diagnostics.

#### 7. **AccessData's Registry Viewer**
- **Purpose:** GUI-free registry hive parsing and analysis
- **Why:** Parse NTUSER.DAT, SAM, SECURITY offline
- **License:** Free (AccessData)
- **Forensic Value:** HIGH
- **Alternative:** RegRipper (Perl-based, requires Perl runtime)

#### 8. **Wevtutil.exe** (Windows Native)
- **Purpose:** Export and parse Windows event logs
- **Why:** Already included in Windows; no download needed
- **Integration:** Already usable in PowerShell script
- **Forensic Value:** HIGH
- **Note:** Already available on all systems, no addition needed

#### 9. **psexec.exe** (SysInternals)
- **Purpose:** Remote process execution (if WinRM becomes available in future)
- **Why:** Future-proofing for remote collection capability
- **Size:** ~120 KB
- **License:** Sysinternals - Free
- **Forensic Value:** LOW (for future use)
- **Note:** Currently unnecessary due to USB deployment model

#### 10. **dd.exe** (GNU dd for Windows)
- **Purpose:** Low-level disk/partition imaging and copying
- **Why:** Sector-level disk forensics; unallocated space recovery
- **Size:** ~200 KB
- **License:** GPL
- **Forensic Value:** HIGH
- **Challenge:** Large file creation; requires significant disk space
- **Recommendation:** Document as optional advanced tool

#### 11. **sleuthkit/tsk_recover.exe**
- **Purpose:** Recover deleted files and unallocated space analysis
- **Why:** Recover deleted artifacts from disk
- **Size:** ~500 KB
- **License:** IPL/LGPL
- **Forensic Value:** HIGH (but resource intensive)
- **Challenge:** Large, complex tool; may overwhelm sysadmins
- **Recommendation:** Document as analyst-level tool, not for sysadmin execution

#### 12. **EnCase/FTK Imager Lite** (Official)
- **Purpose:** Professional imaging and file export
- **Why:** Industry standard; EWF format support
- **Size:** ~20 MB
- **License:** Free (limited version)
- **Forensic Value:** VERY HIGH
- **Challenge:** Significant size; may be better as separate download
- **Recommendation:** Reference in documentation; not include in USB

---

### Priority Level: MEDIUM (Add in Phase 3, within 4 weeks)
These tools are valuable but specialized.

#### 13. **entropy.exe** (Custom or sourced)
- **Purpose:** Detect encrypted/compressed files by entropy analysis
- **Why:** Identify suspicious files; detect encryption
- **Forensic Value:** MEDIUM
- **Size:** ~50 KB
- **License:** Custom or public domain

#### 14. **exiftool.exe**
- **Purpose:** Parse metadata from images, PDFs, documents
- **Why:** Recover hidden metadata; identify file origins
- **Size:** ~150 KB
- **License:** Perl Artistic + GPL
- **Forensic Value:** MEDIUM

#### 15. **volatility-standalone.exe**
- **Purpose:** Analyze memory dumps for malware, hidden processes
- **Why:** Memory forensics; detect rootkits
- **Size:** ~10+ MB
- **License:** Volatility Foundation
- **Forensic Value:** HIGH (but requires memory dump)
- **Challenge:** Large; requires expertise
- **Note:** Not practical for USB (size) unless specifically requested

#### 16. **yara.exe**
- **Purpose:** Pattern matching for malware signatures and indicators
- **Why:** Detect known malware in collected artifacts
- **Size:** ~500 KB
- **License:** BSD
- **Forensic Value:** MEDIUM-HIGH
- **Requires:** YARA rule files (additional downloads)
- **Recommendation:** Add as optional analyst tool

---

### Priority Level: LOW (Optional/Future)
These are nice-to-have tools for specialized scenarios.

#### 17. **PEiD.exe / Detect It Easy**
- **Purpose:** Identify executable packers and protections
- **Forensic Value:** LOW-MEDIUM
- **Use Case:** Malware analysis

#### 18. **Wireshark/tshark.exe**
- **Purpose:** Network packet capture and analysis
- **Forensic Value:** LOW (for collection phase)
- **Note:** More useful for live incident response, not forensic collection

#### 19. **OpenSSH.exe** (Windows 10+)
- **Purpose:** Secure data transfer
- **Forensic Value:** LOW (for deployment)
- **Note:** Alternative to built-in compression

---

## Recommended Implementation Plan

### Phase 1: IMMEDIATE (This Week)
**Goal:** Add critical hash verification and log parsing

1. ✅ **hashdeep.exe** (70 KB)
   - Add to `bins/` folder
   - Create `bins/hashdeep_LICENSE.txt`
   - Update `collect.ps1` to generate SHA256 manifest
   - Update documentation

2. ✅ **strings.exe** (SysInternals, 80 KB)
   - Add to `bins/` folder
   - Create `bins/strings_LICENSE.txt`
   - Include in output for analyst use

3. ✅ **sigcheck.exe** (SysInternals, 100 KB)
   - Add to `bins/` folder
   - Create `bins/sigcheck_LICENSE.txt`
   - Verify collected executables

**Total Addition:** ~250 KB

### Phase 2: SHORT-TERM (2 weeks)
**Goal:** Add professional forensic capability and event log parsing

1. ✅ **EvtxExCmd.exe** (Nirsoft, 100 KB)
   - Event log parsing to CSV
   - Integrate into collect.ps1

2. ✅ **dd.exe** (GNU, 200 KB)
   - Optional disk imaging
   - Document as advanced option

**Total Addition:** ~300 KB

### Phase 3: MEDIUM-TERM (4 weeks)
**Goal:** Add specialized analysis tools

1. ✅ **EWF creation tools** (400 KB if needed)
2. ✅ **YARA** (500 KB + rules)
3. ✅ Memory analysis tools (if applicable)

**Total Addition:** ~1 MB

---

## Implementation Strategy for Phase 1

### Step 1: Acquire Tools
1. Download hashdeep from NIST NSRL: https://www.nist.gov/itl/ssd/software-quality-group/national-software-reference-library-nsrl
2. Download strings.exe from SysInternals: https://docs.microsoft.com/en-us/sysinternals/downloads/strings
3. Download sigcheck.exe from SysInternals: https://docs.microsoft.com/en-us/sysinternals/downloads/sigcheck

### Step 2: Create License Files
- Document each tool's licensing terms
- Ensure compliance for redistribution

### Step 3: Update collect.ps1
```powershell
# Add hash verification section
Write-Log "Generating file integrity hashes..."
& ".\bins\hashdeep.exe" -r -c sha256 ".\$outputDir" | Out-File -FilePath ".\$outputDir\SHA256_MANIFEST.txt"
Write-Log "Hash manifest created: SHA256_MANIFEST.txt"

# Add executable signature verification
Write-Log "Verifying executable signatures..."
& ".\bins\sigcheck.exe" -e -nobanner ".\$outputDir\*\*.exe" | Out-File -FilePath ".\$outputDir\ExecutableSignatures.txt" -ErrorAction SilentlyContinue
Write-Log "Signature verification complete"
```

### Step 4: Update Documentation
1. Add section to TECHNICAL_DOCUMENTATION.md: "Hash Verification and Chain of Custody"
2. Update MANIFEST.md with new tools
3. Add to SYSADMIN_DEPLOYMENT_GUIDE.md: "What happens with your data" section covering hash verification

---

## Storage & Organization

### Recommended Structure
```
bins/
├── RawCopy.exe
├── RawCopy_LICENSE.md
├── zip.exe
├── Zip_License.txt
├── hashdeep.exe          [NEW - Phase 1]
├── hashdeep_LICENSE.txt  [NEW - Phase 1]
├── strings.exe           [NEW - Phase 1]
├── strings_LICENSE.txt   [NEW - Phase 1]
├── sigcheck.exe          [NEW - Phase 1]
├── sigcheck_LICENSE.txt  [NEW - Phase 1]
├── EvtxExCmd.exe         [NEW - Phase 2]
├── EvtxExCmd_LICENSE.txt [NEW - Phase 2]
├── dd.exe                [NEW - Phase 2]
└── dd_LICENSE.txt        [NEW - Phase 2]
```

### USB Space Requirements
- Current: ~250 KB (scripts + zips)
- After Phase 1: ~500 KB
- After Phase 2: ~800 KB
- After Phase 3: ~2 MB

**Recommendation:** All phases fit comfortably on USB (even smallest USB devices have 8-32 GB)

---

## Tool Decision Matrix

| Tool | Forensic Value | Ease of Use | Storage | CPU/RAM | Priority | Recommendation |
|------|---|---|---|---|---|---|
| hashdeep | 🟢 HIGH | 🟢 Simple | 🟢 70 KB | 🟢 Minimal | CRITICAL | **Add Now** |
| strings | 🟡 MEDIUM | 🟡 Moderate | 🟡 80 KB | 🟢 Low | HIGH | **Add Now** |
| sigcheck | 🟡 MEDIUM | 🟢 Simple | 🟡 100 KB | 🟡 Moderate | HIGH | **Add Now** |
| EvtxExCmd | 🟢 HIGH | 🟢 Simple | 🟡 100 KB | 🟢 Low | HIGH | **Add in Phase 2** |
| dd | 🟢 HIGH | 🔴 Complex | 🔴 200 KB | 🔴 High | MEDIUM | **Add in Phase 2** |
| YARA | 🟡 MEDIUM | 🔴 Complex | 🔴 500 KB | 🟡 Moderate | MEDIUM | **Add in Phase 3** |
| Volatility | 🟢 HIGH | 🔴 Expert | 🔴 10+ MB | 🔴 High | LOW | **Document Only** |
| sleuthkit | 🟢 HIGH | 🔴 Complex | 🔴 500 KB | 🔴 High | LOW | **Document Only** |

---

## Legal/License Compliance Summary

### Current Tools (✅ Compliant)
- **RawCopy.exe**: Creative Commons CC0 (Public Domain equivalent)
- **zip.exe**: Info-ZIP BSD License (Free for distribution)

### Recommended Tools (✅ All Compliant)
- **hashdeep.exe**: Public Domain (NIST NSRL)
- **strings.exe**: SysInternals freeware license
- **sigcheck.exe**: SysInternals freeware license
- **EvtxExCmd.exe**: Nirsoft freeware (free for forensic use)
- **dd.exe**: GNU GPL (compliance requires source code availability)

**Recommendation:** Include GPL license notice in repository; link to source if dd.exe included.

---

## Testing Checklist for Implementation

- [ ] hashdeep correctly generates SHA256 hashes
- [ ] strings.exe extracts readable strings from registry hives
- [ ] sigcheck.exe verifies Windows binary signatures
- [ ] All tools execute without admin elevation issues
- [ ] All tools work on Windows Server 2016+
- [ ] All tools work on hypervisor VMs (vSphere, Hyper-V)
- [ ] License files are complete and accurate
- [ ] Output files are correctly generated
- [ ] Log entries properly document tool execution
- [ ] Error handling works if tools are missing
- [ ] Disk space requirements documented
- [ ] Performance impact negligible

---

## Summary & Recommendations

### What to Do Now (Phase 1)
1. **Add hashdeep.exe** - Critical for chain of custody
2. **Add strings.exe** - Valuable for artifact analysis
3. **Add sigcheck.exe** - Verify executable integrity
4. **Update collect.ps1** - Integrate hash generation
5. **Update documentation** - Explain new capabilities

### Short-Term (Phase 2, 2 weeks)
6. Add EvtxExCmd.exe for event log parsing
7. Add dd.exe documentation and optional support

### Medium-Term (Phase 3, 4 weeks)
8. Add YARA for malware pattern matching
9. Add advanced analysis tools as needed

### Not Recommended
- Volatility (too large, requires expertise)
- Encase Imager (better as external tool)
- Full sleuthkit (complex, alternative: document steps)
- Wireshark (not applicable to forensic collection)

---

## Next Actions

**Immediate (This Sprint):**
1. Review and approve Phase 1 tool additions
2. Download and verify hashdeep, strings, sigcheck
3. Create license files for each
4. Update collect.ps1 with hash verification code
5. Test on Windows Server 2016+ instance
6. Update MANIFEST.md and documentation

**Optional Enhancement:**
- Create TOOLS_MANIFEST.md documenting all utilities
- Create TOOLS_USAGE_GUIDE.md with examples for analysts
- Build tool verification script to ensure all are present on USB

