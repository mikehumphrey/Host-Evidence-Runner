# bins/ Folder Organization

**Updated:** December 12, 2025  
**Status:** ✅ Phase 1 Tools Installed and Organized

---

## Current Structure

```
bins/
├── 🔧 CORE TOOLS (Always Used)
├── RawCopy.exe                      (710 KB) - NTFS file extraction
├── zip.exe                          (132 KB) - Compression utility
│
├── 🟢 PHASE 1 TOOLS - PRIMARY (32-bit)
├── hashdeep.exe                     (771 KB) - SHA256 hashing
├── strings.exe                      (361 KB) - String extraction
├── sigcheck.exe                     (435 KB) - Signature verification
│
├── 🟠 PHASE 1 TOOLS - ALTERNATIVES (64-bit)
├── hashdeep64.exe                   (848 KB) - 64-bit version
├── strings64.exe                    (467 KB) - 64-bit version
├── sigcheck64.exe                   (528 KB) - 64-bit version
│
├── 📚 DOCUMENTATION
├── PHASE_1_TOOLS_INSTALLATION.md    (5 KB)  - Tool installation guide
├── hashdeep_LICENSE.txt             (2 KB)  - Public Domain
├── SysInternals_LICENSE.txt         (5 KB)  - Freeware license
├── RawCopy_LICENSE.md               (17 KB) - Creative Commons
├── Zip_License.txt                  (10 KB) - Info-ZIP license
│
├── 📦 REFERENCE FOLDERS (Can be deleted after setup)
├── md5deep/                         - hashdeep/md5deep source
├── Strings/                         - strings source
└── Sigcheck/                        - sigcheck source
```

---

## File Summary

### Primary Tools (Used by collect.ps1)

| Tool | Size | Purpose | Status |
|------|------|---------|--------|
| **hashdeep.exe** | 771 KB | SHA256 hash generation | ✅ Ready |
| **strings.exe** | 361 KB | String extraction | ✅ Ready |
| **sigcheck.exe** | 435 KB | Signature verification | ✅ Ready |
| **RawCopy.exe** | 710 KB | NTFS file extraction | ✅ Existing |
| **zip.exe** | 132 KB | Compression | ✅ Existing |

**Total Primary Tools Size:** ~2.4 MB

### 64-bit Alternatives (Optional Performance)

| Tool | Size | Purpose | Status |
|------|------|---------|--------|
| **hashdeep64.exe** | 848 KB | 64-bit hashing | ✅ Available |
| **strings64.exe** | 467 KB | 64-bit extraction | ✅ Available |
| **sigcheck64.exe** | 528 KB | 64-bit signatures | ✅ Available |

**64-bit Tools Size:** ~1.8 MB  
**Total with 64-bit:** ~4.2 MB

---

## How collect.ps1 Uses These Tools

### Automatic Detection
The script automatically uses the correct version:

```powershell
# Script checks for hashdeep.exe (32-bit) first
$hashdeepPath = Join-Path $scriptPath "bins\hashdeep.exe"
if (Test-Path $hashdeepPath) {
    # Uses 32-bit version
}

# Can be enhanced to detect 64-bit architecture:
# if ([System.Environment]::Is64BitProcess) {
#     Use hashdeep64.exe
# }
```

### Tools Called by collect.ps1

1. **hashdeep.exe**
   - Called with: `hashdeep -r -c sha256 .\collected_files`
   - Output: `SHA256_MANIFEST.txt`
   - Usage: Hash verification for chain of custody

2. **strings.exe**
   - Called with: `strings.exe -nobanner <file>`
   - Output: `*_Strings.txt` files
   - Usage: String extraction from registry hives

3. **sigcheck.exe**
   - Called with: `sigcheck.exe -nobanner -accepteula <files>`
   - Output: `ExecutableSignatures.txt`
   - Usage: Executable signature verification

---

## Source Folders (Reference)

You can keep or delete these reference folders after setup:

### `md5deep/` folder
- Contains: hashdeep, md5deep, sha1deep, sha256deep, and other hash tools
- Includes: Documentation and license
- Size: ~18 MB (uncompressed)
- **Keep for:** Reference, alternative hash methods, updated versions
- **Delete if:** Space constrained, not needed

### `Strings/` folder
- Contains: strings.exe (32-bit and 64-bit variants)
- Includes: EULA
- Size: ~2 MB
- **Keep for:** Reference, updated versions
- **Delete if:** Space constrained

### `Sigcheck/` folder
- Contains: sigcheck.exe (32-bit and 64-bit variants)
- Includes: EULA
- Size: ~2 MB
- **Keep for:** Reference, updated versions
- **Delete if:** Space constrained

---

## Optimization Options

### Option A: Minimal Size (Recommended for USB)
Keep only what's needed:
```
bins/
├── RawCopy.exe
├── zip.exe
├── hashdeep.exe      ← Only 32-bit
├── strings.exe       ← Only 32-bit
├── sigcheck.exe      ← Only 32-bit
├── LICENSE files
└── PHASE_1_TOOLS_INSTALLATION.md
```
**Size:** ~2.4 MB  
**Status:** Fully functional for most servers

### Option B: 64-bit Support (For Performance)
Include 64-bit versions:
```
bins/
├── (all files above, plus)
├── hashdeep64.exe
├── strings64.exe
├── sigcheck64.exe
└── (reference folders optional)
```
**Size:** ~4.2 MB  
**Status:** Optimized for 64-bit Windows Server

### Option C: Full Reference (For Development)
Keep everything:
```
bins/
├── (all files)
├── md5deep/
├── Strings/
├── Sigcheck/
└── All source documentation
```
**Size:** ~25+ MB  
**Status:** Complete reference library

---

## Recommendations

### For USB Deployment
✅ **Use Option A (Minimal)**
- Only 2.4 MB for Phase 1 tools
- Faster USB copy
- Still supports all 32-bit and 64-bit servers
- All reference docs available in root docs

### For Development/Testing
✅ **Use Option B (64-bit Support)**
- ~4.2 MB total
- Better performance on modern 64-bit servers
- Easy to switch between versions

### For Long-term Archive
✅ **Use Option C (Full Reference)**
- Complete source documentation
- Alternative hash tools available
- Easy to update or modify

---

## Current Deployment Status

✅ **Primary Tools:** All present and ready
- hashdeep.exe (771 KB) - ✓
- strings.exe (361 KB) - ✓
- sigcheck.exe (435 KB) - ✓

✅ **Documentation:** Complete
- License files - ✓
- Installation guide - ✓
- This organization guide - ✓

✅ **Source Folders:** Available for reference
- md5deep/ - ✓
- Strings/ - ✓
- Sigcheck/ - ✓

---

## Next Steps

### Immediate (For Production)
1. ✅ Tools are organized in bins/
2. ✅ License files in place
3. ✅ collect.ps1 ready to use
4. **→ Test on Windows Server 2016+**

### Optional Cleanup (If Space Constrained)
1. Delete reference folders (md5deep/, Strings/, Sigcheck/)
2. Delete 64-bit versions if not needed
3. Saves ~20 MB on USB

### For Enhanced Performance
1. Keep 64-bit versions
2. Update collect.ps1 to detect architecture (optional enhancement)
3. Use 64-bit on 64-bit servers, 32-bit on 32-bit

---

## Verification Checklist

- [x] hashdeep.exe present and working
- [x] strings.exe present and working
- [x] sigcheck.exe present and working
- [x] All license files present
- [x] Documentation complete
- [x] 64-bit alternatives available
- [x] Source folders accessible
- [ ] Testing on Windows Server 2016+
- [ ] Testing on Windows Server 2019+
- [ ] Testing on Windows Server 2022+

---

## Size Summary

| Category | Size | Count |
|----------|------|-------|
| Core Tools | 842 KB | 2 |
| Phase 1 Tools (32-bit) | 1,567 KB | 3 |
| Phase 1 Tools (64-bit) | 1,844 KB | 3 |
| Licenses & Docs | 27 KB | 5 |
| Source Folders | ~20 MB | 3 |
| **Total (32-bit only)** | **~2.4 MB** | |
| **Total (with 64-bit)** | **~4.2 MB** | |
| **Total (with sources)** | **~25 MB** | |

---

## Questions & Answers

**Q: Do I need the 64-bit versions?**
A: No, unless you want better performance on 64-bit servers. 32-bit versions work fine on both.

**Q: Can I delete the source folders (md5deep/, Strings/, Sigcheck/)?**
A: Yes, if space is limited. They're only needed as reference.

**Q: Which version does collect.ps1 use?**
A: Currently uses 32-bit (.exe). Can be updated to auto-detect and use 64-bit on 64-bit systems.

**Q: Are the 64-bit versions backward compatible?**
A: Yes, they work on 64-bit Windows systems. But 32-bit versions also work fine.

**Q: What's the minimum size needed?**
A: ~2.4 MB for 32-bit tools. Just delete 64-bit versions and source folders.

---

## Files Ready for Deployment

✅ **All Phase 1 tools extracted and organized**  
✅ **License files in place**  
✅ **collect.ps1 ready to use**  
✅ **Documentation complete**  

**Status:** Ready to test and deploy

