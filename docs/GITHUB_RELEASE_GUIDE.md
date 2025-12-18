# GitHub Release Guide

## Quick Start - Manual Release

```powershell
# Build release package for GitHub
.\Build-GitHubRelease.ps1 -Version "1.0.1" -CreateTag -Sign
```

This creates:
- `releases/v1.0.1/` - Release package directory
- `releases/HER-v1.0.1.zip` - GitHub asset (upload this)
- `releases/v1.0.1/GITHUB_RELEASE_NOTES.txt` - Copy/paste this to GitHub
- Git tag `v1.0.1` (if -CreateTag specified)

---

## Option 1: Manual Release (Full Control)

### Step 1: Build Release Package
```powershell
.\Build-GitHubRelease.ps1 -Version "1.0.1" -CreateTag
```

### Step 2: Push Tag to GitHub
```powershell
git push origin v1.0.1
```

### Step 3: Create Release on GitHub
1. Go to: https://github.com/YOUR-ORG/Host-Evidence-Runner/releases/new
2. **Choose tag**: `v1.0.1`
3. **Release title**: `Host Evidence Runner v1.0.1`
4. **Description**: Copy content from `releases/v1.0.1/GITHUB_RELEASE_NOTES.txt`
5. **Upload asset**: `releases/HER-v1.0.1.zip`
6. **Check**: "Set as latest release"
7. **Click**: "Publish release"

### Step 4: Verify
- Download ZIP from release page
- Extract and test: `.\run-collector.ps1 -AnalystWorkstation "localhost"`

---

## Option 2: Automated Release (GitHub Actions)

**One-command release:**
```powershell
# Create and push tag - GitHub Actions does the rest
git tag -a v1.0.1 -m "Host Evidence Runner v1.0.1"
git push origin v1.0.1
```

GitHub Actions will automatically:
1. ✅ Build release package
2. ✅ Create ZIP file
3. ✅ Create GitHub release
4. ✅ Upload ZIP as asset
5. ✅ Publish release notes

**Workflow file**: `.github/workflows/release.yml`

---

## Version Numbering

Use [Semantic Versioning](https://semver.org/):
- **Major.Minor.Patch** (e.g., 1.0.1)
- **Major** (1.x.x): Breaking changes
- **Minor** (x.1.x): New features (backward compatible)
- **Patch** (x.x.1): Bug fixes

### Examples:
- `1.0.0` - Initial stable release
- `1.0.1` - Bug fix release
- `1.1.0` - New features added
- `2.0.0` - Major rewrite or breaking changes

---

## Build Script Parameters

### Build-GitHubRelease.ps1

```powershell
# Full options
.\Build-GitHubRelease.ps1 `
    -Version "1.0.1" `     # Version number (or auto-detect)
    -CreateTag `           # Create git tag
    -Sign `                # Sign PowerShell scripts
    -SkipZip               # Don't create ZIP (testing)
```

**Parameters:**
- **-Version**: Semantic version (e.g., "1.0.1"). If omitted, reads from RELEASE_NOTES.md
- **-CreateTag**: Creates git tag `v1.0.1` locally
- **-Sign**: Signs scripts with code signing certificate (if available)
- **-SkipZip**: Skip ZIP creation (for testing builds)

---

## Pre-Release Checklist

### 1. Update Version Documentation
- [ ] Update version in `RELEASE_NOTES.md` header
- [ ] Update version in `README.md` (if shown)
- [ ] Review and finalize release notes

### 2. Test Locally
```powershell
# Build without tagging
.\Build-GitHubRelease.ps1 -Version "1.0.1" -SkipZip

# Extract and test
cd releases\v1.0.1
.\run-collector.ps1 -AnalystWorkstation "localhost" -Verbose
```

### 3. Commit Changes
```powershell
git add RELEASE_NOTES.md README.md
git commit -m "Release v1.0.1"
git push origin main
```

### 4. Create Release
```powershell
# Manual process
.\Build-GitHubRelease.ps1 -Version "1.0.1" -CreateTag -Sign
git push origin v1.0.1
# Then manually create GitHub release

# OR Automated process
git tag -a v1.0.1 -m "Host Evidence Runner v1.0.1"
git push origin v1.0.1
# GitHub Actions creates release automatically
```

---

## What Gets Packaged

### Included in Release ZIP:
- ✅ `run-collector.ps1` - Main launcher
- ✅ `RUN_COLLECT.bat` - Batch launcher
- ✅ `source/collect.ps1` - Collection engine
- ✅ `tools/bins/` - Forensic tools (RawCopy, hashdeep, etc.)
- ✅ `templates/` - Investigation templates
- ✅ `docs/` - Sysadmin guides
- ✅ `README.md` - Main documentation
- ✅ `RELEASE_NOTES.md` - Release notes
- ✅ `LICENSE` and `NOTICE` - Legal files

### Excluded from Release:
- ❌ `investigations/` - Investigation outputs
- ❌ `modules/` - Analysis modules (not ready)
- ❌ `tools/optional/` - Zimmerman tools (user downloads separately)
- ❌ `.git/` - Git metadata
- ❌ `docs/historical/` - Historical documentation
- ❌ `tests/` - Test scripts
- ❌ Build scripts

---

## Troubleshooting

### "Could not extract version from RELEASE_NOTES.md"
**Fix:** Ensure RELEASE_NOTES.md has this format:
```markdown
## Latest Release: 20251217_091555
**Version:** 1.0.1
```

### "Tag already exists"
**Fix:**
```powershell
# Delete local tag
git tag -d v1.0.1

# Delete remote tag
git push origin :refs/tags/v1.0.1

# Recreate tag
.\Build-GitHubRelease.ps1 -Version "1.0.1" -CreateTag
git push origin v1.0.1
```

### GitHub Actions workflow not triggering
**Check:**
1. Tag pushed to GitHub: `git push origin v1.0.1`
2. Tag format correct: `v1.0.1` (must start with 'v')
3. Workflow file exists: `.github/workflows/release.yml`
4. Repository permissions: Settings > Actions > General > Workflow permissions = "Read and write"

---

## Advanced: Hotfix Release

For urgent bug fixes between planned releases:

```powershell
# 1. Create hotfix branch
git checkout -b hotfix/1.0.2

# 2. Make fixes
# ... edit files ...

# 3. Commit
git commit -am "Fix critical bug XYZ"

# 4. Build and test
.\Build-GitHubRelease.ps1 -Version "1.0.2" -SkipZip
# Test the release...

# 5. Merge to main
git checkout main
git merge hotfix/1.0.2

# 6. Create release
git tag -a v1.0.2 -m "Hotfix: Critical bug XYZ"
git push origin main v1.0.2

# 7. Verify GitHub Actions or create manually
```

---

## Release Checklist Template

Copy this for each release:

```markdown
## Release v1.0.1 Checklist

### Pre-Release
- [ ] All tests pass
- [ ] RELEASE_NOTES.md updated with version
- [ ] Version documented (README.md if applicable)
- [ ] Local test build: `.\Build-GitHubRelease.ps1 -Version "1.0.1" -SkipZip`
- [ ] Local test collection successful
- [ ] Changes committed to main branch

### Release
- [ ] Run: `.\Build-GitHubRelease.ps1 -Version "1.0.1" -CreateTag -Sign`
- [ ] Push tag: `git push origin v1.0.1`
- [ ] Verify GitHub Actions completed (or create manual release)
- [ ] Download ZIP from GitHub release page
- [ ] Test downloaded ZIP on clean system

### Post-Release
- [ ] Announce release (if applicable)
- [ ] Update documentation site (if applicable)
- [ ] Close related issues on GitHub
- [ ] Update project board/roadmap
```

---

## File Locations After Build

```
releases/
├── v1.0.1/                          # Release package directory
│   ├── run-collector.ps1
│   ├── RUN_COLLECT.bat
│   ├── source/
│   ├── tools/
│   ├── templates/
│   ├── docs/
│   ├── README.md
│   ├── RELEASE_NOTES.md
│   ├── LICENSE
│   ├── NOTICE
│   ├── GITHUB_RELEASE_NOTES.txt    # Copy this to GitHub release description
│   └── CREATE_GITHUB_RELEASE.txt   # Quick reference
│
└── HER-v1.0.1.zip                   # Upload this to GitHub as asset
```

---

## GitHub Release Example

**Title:**
```
Host Evidence Runner v1.0.1
```

**Tag:**
```
v1.0.1
```

**Description:** (from GITHUB_RELEASE_NOTES.txt)
```markdown
# Host Evidence Runner (HER) v1.0.1

**A comprehensive forensic evidence collection and analysis toolkit for Windows incident response.**

## 📦 Download
Download the release package: **HER-v1.0.1.zip** (attached below)

## 🚀 Quick Start
1. Extract the ZIP to USB drive or C:\Temp
2. Unblock files: `Get-ChildItem -Recurse | Unblock-File`
3. Run as Administrator: `.\run-collector.ps1 -AnalystWorkstation "localhost"`

[... rest of release notes ...]
```

**Assets:**
- `HER-v1.0.1.zip` (uploaded)

---

## Support

For issues with the release process:
1. Check this guide first
2. Review build output logs
3. Verify RELEASE_NOTES.md format
4. Check GitHub Actions logs (if using automation)

For issues with the tool itself:
- Open a GitHub issue
- Include version number
- Include relevant log files
