# Phase 1 Tools Installation Guide

This document provides instructions for obtaining and installing Phase 1 forensic tools.

## Tools to Install

### 1. hashdeep.exe
**Purpose:** Generate SHA256 hashes of collected files for chain of custody verification

**Download Instructions:**
1. Visit: https://sourceforge.net/projects/md5deep/files/md5deep/4.4.0/
2. Download: `md5deep-4.4.0-win64.zip` (approximately 70 KB)
3. Extract the ZIP file
4. Copy `hashdeep.exe` to this `bins/` directory
5. If hashdeep.exe not found, copy `md5deep.exe` and rename to `hashdeep.exe`

**Verification:**
```powershell
.\bins\hashdeep.exe --version
```

**License:** Public Domain (NIST NSRL)

---

### 2. strings.exe (SysInternals)
**Purpose:** Extract readable ASCII/Unicode strings from binary files (registry hives, executables)

**Download Instructions:**
1. Visit: https://docs.microsoft.com/en-us/sysinternals/downloads/strings
2. Download: `strings.zip` (approximately 80 KB)
3. Extract the ZIP file
4. Copy `strings.exe` to this `bins/` directory

**Verification:**
```powershell
.\bins\strings.exe -h
```

**License:** SysInternals Freeware License

---

### 3. sigcheck.exe (SysInternals)
**Purpose:** Verify executable signatures and timestamps; detect unsigned/tampered binaries

**Download Instructions:**
1. Visit: https://docs.microsoft.com/en-us/sysinternals/downloads/sigcheck
2. Download: `sigcheck.zip` (approximately 100 KB)
3. Extract the ZIP file
4. Copy `sigcheck.exe` to this `bins/` directory

**Verification:**
```powershell
.\bins\sigcheck.exe -h
```

**License:** SysInternals Freeware License

---

## Installation Steps (Windows)

### Option A: Manual Download
1. Download each tool above manually
2. Extract ZIP files
3. Copy .exe files to `bins/` directory
4. Verify using commands above

### Option B: Automated Script
Run the following PowerShell script:

```powershell
# Navigate to Cado-Batch directory
cd 'C:\Users\[YourUsername]\OneDrive - Municipality of Anchorage\Documents\Development\GitHub\Cado-Batch'

# Function to test if tool exists
function Test-Tool {
    param($ToolName)
    $path = ".\bins\$ToolName"
    if (Test-Path $path) {
        Write-Host "✓ $ToolName found" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ $ToolName NOT found" -ForegroundColor Red
        return $false
    }
}

# Verify all tools
Write-Host "Checking Phase 1 tools..." -ForegroundColor Cyan
$hashdeep = Test-Tool "hashdeep.exe"
$strings = Test-Tool "strings.exe"
$sigcheck = Test-Tool "sigcheck.exe"

if ($hashdeep -and $strings -and $sigcheck) {
    Write-Host "`nAll Phase 1 tools installed successfully!" -ForegroundColor Green
} else {
    Write-Host "`nMissing tools. Please download manually using instructions above." -ForegroundColor Yellow
}
```

---

## Verification Checklist

- [ ] hashdeep.exe present in `bins/` directory
- [ ] strings.exe present in `bins/` directory
- [ ] sigcheck.exe present in `bins/` directory
- [ ] All three tools are executable (no corruption)
- [ ] License files created for each tool
- [ ] collect.ps1 updated with hash verification code
- [ ] Documentation updated with new capabilities

---

## File Sizes (Reference)

| Tool | Filename | Size | License |
|------|----------|------|---------|
| hashdeep | hashdeep.exe | ~70 KB | Public Domain |
| strings | strings.exe | ~80 KB | SysInternals Freeware |
| sigcheck | sigcheck.exe | ~100 KB | SysInternals Freeware |
| **Total** | | **~250 KB** | |

---

## Troubleshooting

### hashdeep.exe not found after download
- Check if the file is named `md5deep.exe` instead
- Rename to `hashdeep.exe` to match script expectations
- Verify extraction worked: `Get-ChildItem -Filter "*md5deep*" -Recurse`

### strings.exe or sigcheck.exe not running
- Verify Windows can execute it: `.\bins\strings.exe` (should show help)
- Check file isn't corrupted: `Get-Item .\bins\strings.exe | Select-Object Length`
- Run as administrator if permission errors occur

### "Access Denied" when copying files
- Close any antivirus software temporarily
- Ensure UAC allows file operations
- Try copying to a temporary location first, then to bins/

---

## Next Steps

1. Install all three tools above
2. Run verification checks
3. Commit changes to git repository
4. Update MANIFEST.md with new tools
5. Test on Windows Server 2016+ instance

---

## References

- **hashdeep/md5deep:** https://sourceforge.net/projects/md5deep/
- **SysInternals Suite:** https://docs.microsoft.com/en-us/sysinternals/
- **strings:** https://docs.microsoft.com/en-us/sysinternals/downloads/strings
- **sigcheck:** https://docs.microsoft.com/en-us/sysinternals/downloads/sigcheck

