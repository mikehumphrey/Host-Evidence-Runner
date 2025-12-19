# Directory Structure Guide

This document explains the organization of the Host-Evidence-Runner (HER) project repository.

## Root Directory Files

### Essential Runtime Files
- **`run-collector.ps1`** - PowerShell launcher for the collector (preferred method)
- **`RUN_COLLECT.bat`** - Batch file launcher (bypasses execution policy restrictions)
- **`Build-Release.ps1`** - Script to build release packages
- **`README.md`** - Main project documentation
- **`RELEASE_NOTES.md`** - Current release notes and changelog
- **`LICENSE`** - Apache 2.0 license
- **`NOTICE`** - Third-party attribution notices

### Configuration Files
- **`.gitignore`** - Git exclusion rules
- **`00_START_HERE.md`** - Quick start guide for new users

## Directory Structure

```
Host-Evidence-Runner/
├── source/                    # Core collection scripts
│   └── collect.ps1           # Main forensic collection script
│
├── tools/                     # Forensic tools and utilities
│   ├── bins/                 # Required forensic tools (RawCopy, hashdeep, etc.)
│   └── optional/             # Optional analysis tools (not in releases)
│
├── templates/                 # Investigation templates and metadata
│
├── docs/                      # Documentation
│   ├── sysadmin/            # Sysadmin deployment guides
│   │   ├── QUICK_START.txt
│   │   ├── SYSADMIN_DEPLOYMENT_GUIDE.md
│   │   └── ANALYST_WORKSTATION_GUIDE.md
│   │
│   ├── analyst/             # Analyst investigation guides
│   │
│   ├── reference/           # Technical reference documentation
│   │
│   ├── historical/          # Archived development documentation
│   │   ├── BUG_FIX_REPORT.md
│   │   ├── CONTEXT.md
│   │   ├── DEPLOYMENT_READY.md
│   │   ├── FIXES_20251217.md
│   │   ├── SECURITY_AUDIT.md
│   │   ├── PRE_PUSH_CHECKLIST.md
│   │   └── RELEASE_v1.0.1.md
│   │
│   └── validation/          # Test and validation reports
│       ├── VALIDATION_REPORT.md
│       ├── VALIDATION_REPORT_AnalystWorkstation.md
│       ├── VALIDATION_SUMMARY.md
│       ├── VALIDATE_PROJECT_STRUCTURE.log
│       └── VALIDATE_PROJECT_STRUCTURE.ps1
│
├── tests/                     # Test scripts
│   ├── Test-AnalystWorkstation.ps1
│   └── test-collector.ps1
│
├── investigations/            # Collection output (not in git)
│   └── [hostname]/
│       └── [timestamp]/
│
├── releases/                  # Built release packages
│   └── [timestamp]/
│       └── HER-Collector.zip
│
├── modules/                   # Future modular analysis components
│
├── archive/                   # Deprecated/legacy scripts
│
└── logs/                      # Build and test logs

```

## Documentation Organization

### Active Documentation (Included in Releases)
- **`README.md`** - Main user documentation
- **`RELEASE_NOTES.md`** - Current version notes
- **`docs/sysadmin/ANALYST_WORKSTATION_GUIDE.md`** - Transfer feature guide
- **`LICENSE`** and **`NOTICE`** - Legal/attribution

### Development Documentation (Repository Only)
- **`docs/historical/`** - Past development notes, security audits, bug fix reports
- **`docs/validation/`** - Test results and validation reports
- **`tests/`** - Test scripts for feature validation

### Reference Documentation
- **`docs/sysadmin/`** - Deployment and usage guides for system administrators
- **`docs/analyst/`** - Investigation workflow guides for forensic analysts
- **`docs/reference/`** - Technical specifications and API documentation

## What Gets Included in Releases?

The `Build-Release.ps1` script packages only essential files for end users:

**✅ Included:**
- Runtime scripts (`run-collector.ps1`, `RUN_COLLECT.bat`)
- Core collection script (`source/collect.ps1`)
- Required tools (`tools/bins/`)
- Investigation templates (`templates/`)
- User documentation (`README.md`, `RELEASE_NOTES.md`)
- Analyst Workstation Guide (`docs/ANALYST_WORKSTATION_GUIDE.md`)
- Legal files (`LICENSE`, `NOTICE`)

**❌ Excluded:**
- Development documentation (`docs/historical/`, `docs/validation/`)
- Test scripts (`tests/`)
- Optional tools (`tools/optional/`)
- Build scripts (`Build-Release.ps1`)
- Git metadata (`.git/`, `.gitignore`)
- Investigation outputs (`investigations/`)
- Modules (`modules/` - future use)

## File Maintenance Guidelines

### When Adding New Documentation

- **User-facing guides** → `docs/sysadmin/` or `docs/analyst/`
- **Technical reference** → `docs/reference/`
- **Development notes** → `docs/historical/` (if historical) or root (if active)
- **Test reports** → `docs/validation/`

### When Adding Test Scripts

- Place in `tests/` directory
- Name with `Test-` prefix for PowerShell tests
- Document in test script header what it validates

### When Creating Release Notes

- Active release notes → `RELEASE_NOTES.md` (root)
- Historical releases → `docs/historical/RELEASE_vX.X.X.md`

## Quick Reference

| Task | Location |
|------|----------|
| Run collection | `.\run-collector.ps1` or `RUN_COLLECT.bat` |
| Build release | `.\Build-Release.ps1 -Zip` |
| Read docs | `README.md` or `docs/` |
| Test features | `tests/Test-*.ps1` |
| View validation | `docs/validation/` |
| Check history | `docs/historical/` |

## Cleanup History

**December 17, 2024** - Major reorganization:
- Moved 7 historical documents to `docs/historical/`
- Moved 5 validation reports to `docs/validation/`
- Moved 2 test scripts to `tests/`
- Moved analyst workstation guide to `docs/sysadmin/`
- Updated `Build-Release.ps1` to include analyst guide in releases
- Reduced root directory clutter from 30+ files to 13 essential files
