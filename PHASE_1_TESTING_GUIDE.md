# Phase 1 Testing & Deployment Quick Start

**Status:** ✅ Tools Installed - Ready to Test  
**Next Step:** Run on Windows Server 2016+

---

## Quick Test (5 minutes)

### Verify Tools Are Working

```powershell
# Navigate to project folder
cd 'C:\Users\[YourName]\OneDrive - Municipality of Anchorage\Documents\Development\GitHub\Cado-Batch'

# Test 1: Check hashdeep
.\bins\hashdeep.exe -v
# Should display version information

# Test 2: Check strings
.\bins\strings.exe -h
# Should display help text

# Test 3: Check sigcheck
.\bins\sigcheck.exe -h
# Should display help text

# All three should run without errors ✅
```

---

## Full Test (30-45 minutes)

### On a Windows Server 2016 or later (Physical or VM):

```powershell
# Step 1: Copy project to server
# Copy entire C:\path\to\Cado-Batch folder to test server

# Step 2: Navigate to folder
cd C:\Users\[User]\Desktop\Cado-Batch
# (or wherever you copied it)

# Step 3: Run collection
.\RUN_ME.bat

# Watch for progress messages:
# - Administrator check
# - PowerShell validation
# - Collection starting
# - File collection progress
# - Phase 1 tools running:
#   * SHA256 hash generation
#   * Signature verification
#   * String extraction
# - Compression
# - Completion message

# Step 4: Verify output
dir collected_files\
# Should see:
# - Registry/ (hives)
# - Prefetch/ (programs)
# - Users/ (user data)
# - EVTX files
# - SHA256_MANIFEST.txt ← Phase 1 ✅
# - ExecutableSignatures.txt ← Phase 1 ✅
# - Various *_Strings.txt ← Phase 1 ✅

# Step 5: Check logs
type logs\forensic_collection_*.txt
# Should show all Phase 1 operations completed

# Step 6: Verify compressed output
dir *.zip
# collected_files.zip should be present
```

---

## Expected Output Files (Phase 1)

### New Files Created by Phase 1 Tools

1. **SHA256_MANIFEST.txt**
   - Contains: SHA256 hashes of all collected files
   - Size: 5-15 KB
   - Purpose: Proves evidence integrity
   - Example:
     ```
     SHA256^abc123....|C:\collected_files\NTUSER.DAT|2048576
     SHA256^def456....|C:\collected_files\Registry\SYSTEM|4096000
     ```

2. **ExecutableSignatures.txt**
   - Contains: Digital signature verification results
   - Size: 2-10 KB
   - Purpose: Detects tampered executables
   - Example:
     ```
     Path: C:\collected_files\Windows\System32\svchost.exe
     Signed: Yes
     Signer: Microsoft Windows
     ```

3. **Users\[username]\[filename]_Strings.txt**
   - Contains: Readable strings from registry hives
   - Size: 10-50 KB per file
   - Purpose: Extract hidden data for analysis
   - Created for: NTUSER.DAT files

4. **Detailed Logs**
   - Location: logs\forensic_collection_[ServerName]_[Timestamp].txt
   - Shows: All Phase 1 operations with timestamps
   - Check for: No critical errors

---

## Success Criteria ✅

### All of the following should be true:

- [ ] Script runs without crashing
- [ ] Output folder `collected_files/` created
- [ ] SHA256_MANIFEST.txt created (can be opened in text editor)
- [ ] ExecutableSignatures.txt created (shows signature data)
- [ ] *_Strings.txt files created (show extracted strings)
- [ ] collected_files.zip created (compressed archive)
- [ ] Logs show Phase 1 operations completed
- [ ] No "CRITICAL ERROR" messages in logs
- [ ] Script completes with success message

**If all above are true → Phase 1 is working correctly ✅**

---

## Troubleshooting

### Issue: hashdeep.exe not found
**Solution:** Verify file exists: `dir bins\hashdeep.exe`  
**If missing:** Extract from md5deep/ subfolder or re-download

### Issue: strings.exe not found
**Solution:** Verify file exists: `dir bins\strings.exe`  
**If missing:** Check Strings/ subfolder

### Issue: sigcheck.exe not found
**Solution:** Verify file exists: `dir bins\sigcheck.exe`  
**If missing:** Check Sigcheck/ subfolder

### Issue: SHA256_MANIFEST.txt empty or missing
**Solution:** Check logs for "hashdeep.exe not found" message  
**If found:** Verify hashdeep.exe in bins/ and is executable

### Issue: ExecutableSignatures.txt missing
**Solution:** Script may not have found .exe files  
**Check:** If collected_files has Windows\System32\ folder

### Issue: *_Strings.txt files missing
**Solution:** Check logs for string extraction messages  
**If not found:** Verify registry files were collected

### Issue: Permission denied errors
**Solution:** Run as administrator  
**Command:** Right-click RUN_ME.bat → Run as administrator

---

## File Organization for Testing

```
Test Server Structure:
C:\Testing\
├── Cado-Batch\              ← Copy entire folder here
│   ├── RUN_ME.bat
│   ├── collect.ps1
│   ├── bins/
│   │   ├── hashdeep.exe ✅
│   │   ├── strings.exe ✅
│   │   ├── sigcheck.exe ✅
│   │   └── (other files)
│   └── (documentation files)
│
├── collected_files/         ← Created during execution
│   ├── Registry/
│   ├── Users/
│   ├── Prefetch/
│   ├── SHA256_MANIFEST.txt ← Phase 1 ✅
│   ├── ExecutableSignatures.txt ← Phase 1 ✅
│   └── *_Strings.txt ← Phase 1 ✅
│
├── collected_files.zip      ← Compressed output
└── logs/
    └── forensic_collection_*.txt
```

---

## Test Scenarios

### Scenario 1: Quick Verification (15 min)
1. Run RUN_ME.bat on test server
2. Watch for progress
3. Check for output files
4. Verify SHA256_MANIFEST.txt created
5. Done ✅

### Scenario 2: Detailed Testing (45 min)
1. Run RUN_ME.bat
2. Monitor all progress messages
3. Check each output file exists
4. Open log and verify no errors
5. Verify compressed file created
6. Delete output and test again
7. Done ✅

### Scenario 3: Comprehensive Testing (60+ min)
1. Run on Windows Server 2016
2. Verify all Phase 1 files created
3. Run on Windows Server 2019
4. Verify again
5. Run on Windows Server 2022
6. Verify all work correctly
7. Test 64-bit version (if applicable)
8. Done - Ready for production ✅

---

## Next Steps After Testing

### If All Tests Pass ✅
1. Copy to USB for deployment
2. Print guides for sysadmins
3. Deploy to target servers
4. Monitor first execution
5. Collect and analyze results

### If Issues Found 🔴
1. Check logs for error messages
2. Verify tools are present
3. Run with verbose logging
4. Check administrator permissions
5. Consult BINS_ORGANIZATION.md
6. Try alternative tools (64-bit if on 64-bit server)

### If Errors Persist
1. Check Phase 1 documentation
2. Review logs carefully
3. Ensure Windows Server 2016+ (not Win10/11)
4. Verify tools are executable
5. Try alternate versions (32-bit vs 64-bit)

---

## Performance Expectations

### On Windows Server 2016+
- **Collection time:** 15-30 minutes
- **Phase 1 operations:** 5-10 minutes additional
- **Compression time:** 2-5 minutes
- **Total:** 30-45 minutes

### Disk Space Used
- **Collected files:** 50-100 MB
- **Hash manifest:** 5-15 KB
- **Signature report:** 2-10 KB
- **String files:** 20-100 KB
- **Compressed output:** 30-50 MB
- **Total output:** ~150 MB

### CPU Usage
- **Medium during collection:** 20-40%
- **High during compression:** 80-100%
- **Peak during Phase 1:** 30-50%

---

## Deployment Ready Checklist

After successful testing:

- [ ] All Phase 1 files created
- [ ] No critical errors in logs
- [ ] Tools working correctly
- [ ] Output files readable
- [ ] Compression successful
- [ ] Ready to deploy to production

---

## Quick Reference

| Action | Command |
|--------|---------|
| **Test tools** | `.\bins\hashdeep.exe -v` |
| **Run collection** | `.\RUN_ME.bat` |
| **Check output** | `dir collected_files\` |
| **View logs** | `type logs\forensic_*.txt` |
| **Verify manifest** | `type collected_files\SHA256_MANIFEST.txt` |
| **Check signatures** | `type collected_files\ExecutableSignatures.txt` |

---

## Status Summary

🟢 **READY FOR TESTING**

All tools installed and ready to use. Script is fully prepared for Phase 1 operations:
- ✅ Hash verification ready
- ✅ Signature verification ready
- ✅ String extraction ready
- ✅ Logging ready

**Next action:** Run on Windows Server 2016+ to verify successful execution.

