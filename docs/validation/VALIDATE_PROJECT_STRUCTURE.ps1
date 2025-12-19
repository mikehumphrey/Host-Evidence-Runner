<#
.SYNOPSIS
    Validates that the Host-Evidence-Runner (HER) project structure is properly organized.
    
.DESCRIPTION
    Checks that all required folders, scripts, and tools are in the correct
    locations per PROJECT_STRUCTURE.md. Output is saved to VALIDATE_PROJECT_STRUCTURE.log
    
.EXAMPLE
    .\VALIDATE_PROJECT_STRUCTURE.ps1
    
.NOTES
    Saves output to VALIDATE_PROJECT_STRUCTURE.log in the project root
#>

$ErrorActionPreference = 'Continue'
$scriptPath = $PSScriptRoot
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logFile = Join-Path $scriptPath "VALIDATE_PROJECT_STRUCTURE.log"

# Start fresh log
"═══════════════════════════════════════════════════════════════" | Set-Content $logFile
"Cado-Batch Project Structure Validation Log" | Add-Content $logFile
"═══════════════════════════════════════════════════════════════" | Add-Content $logFile
"Validation Started: $timestamp" | Add-Content $logFile
"Project Root: $scriptPath" | Add-Content $logFile
"" | Add-Content $logFile

# Track results
$passed = 0
$failed = 0
$warnings = 0

# Logging function - writes to both console and log file
function Write-LogEntry {
    param(
        [string]$Message
    )
    # Write to log file
    Add-Content -Path $logFile -Value $Message
    # Also write to console
    Write-Host $Message
}

# ============================================================================
# HEADER
# ============================================================================

Write-LogEntry "-------------------------------------------------------------"
Write-LogEntry "Cado-Batch Project Structure Validation"
Write-LogEntry "Checking organization per PROJECT_STRUCTURE.md"
Write-LogEntry "-------------------------------------------------------------"
Write-LogEntry ""

# ============================================================================
# 1. FOLDER STRUCTURE
# ============================================================================

Write-LogEntry "1. FOLDER STRUCTURE"
Write-LogEntry "-------------------------------------------------------------"

$folders = @(
    @{name="source"; desc="Collection scripts"},
    @{name="modules"; desc="PowerShell modules"},
    @{name="tools"; desc="Executables and utilities"},
    @{name="investigations"; desc="Investigation results"},
    @{name="templates"; desc="Output templates"},
    @{name="docs"; desc="Organized documentation"},
    @{name="archive"; desc="Historical/legacy documents"},
    @{name="logs"; desc="Collection logs (created at runtime)"}
)

foreach ($folder in $folders) {
    $folderPath = Join-Path $scriptPath $folder.name
    if (Test-Path $folderPath -PathType Container) {
        Write-LogEntry ("  [PASS] " + $folder.name + "/ - " + $folder.desc)
        $passed++
    } else {
        Write-LogEntry ("  [FAIL] " + $folder.name + "/ - " + $folder.desc + " [NOT FOUND]")
        $failed++
    }
}

# ============================================================================
# 2. SCRIPTS IN source/
# ============================================================================

Write-LogEntry ""
Write-LogEntry "2. CORE SCRIPTS"
Write-LogEntry "-------------------------------------------------------------"

# Root launcher scripts
$rootScripts = @(
    @{path="run-collector.ps1"; desc="Main launcher script"},
    @{path="RUN_COLLECT.bat"; desc="Batch launcher"},
    @{path="Build-Release.ps1"; desc="Release packaging script"}
)

foreach ($script in $rootScripts) {
    $scriptFile = Join-Path $scriptPath $script.path
    if (Test-Path $scriptFile -PathType Leaf) {
        $size = (Get-Item $scriptFile).Length / 1KB
        $sizeRounded = [math]::Round($size, 1)
        Write-LogEntry ("  [PASS] " + $script.path + " - " + $script.desc + " (" + $sizeRounded + " KB)")
        $passed++
    } else {
        Write-LogEntry ("  [FAIL] " + $script.path + " [NOT FOUND]")
        $failed++
    }
}

# Source folder scripts
$sourceScripts = @(
    @{path="collect.ps1"; desc="Main collection engine"},
    @{path="Analyze-Investigation.ps1"; desc="Analysis script"}
)

foreach ($script in $sourceScripts) {
    $scriptFile = Join-Path $scriptPath "source\$($script.path)"
    if (Test-Path $scriptFile -PathType Leaf) {
        $size = (Get-Item $scriptFile).Length / 1KB
        $sizeRounded = [math]::Round($size, 1)
        Write-LogEntry ("  [PASS] source/" + $script.path + " - " + $script.desc + " (" + $sizeRounded + " KB)")
        $passed++
    } else {
        Write-LogEntry ("  [FAIL] source/" + $script.path + " [NOT FOUND]")
        $failed++
    }
}

# ============================================================================
# 3. PHASE 1 TOOLS IN tools/bins/
# ============================================================================

Write-LogEntry ""
Write-LogEntry "3. REQUIRED TOOLS (tools/bins/)"
Write-LogEntry "-------------------------------------------------------------"

$tools = @(
    "hashdeep64.exe",
    "strings64.exe",
    "sigcheck64.exe",
    "RawCopy.exe"
)

$toolsPath = Join-Path $scriptPath "tools\bins"

foreach ($tool in $tools) {
    $toolFile = Join-Path $toolsPath $tool
    if (Test-Path $toolFile -PathType Leaf) {
        $actualSize = (Get-Item $toolFile).Length / 1KB
        $actualSizeRounded = [math]::Round($actualSize)
        Write-LogEntry ("  [PASS] " + $tool + " (" + $actualSizeRounded + " KB)")
        $passed++
    } else {
        Write-LogEntry ("  [FAIL] " + $tool + " [NOT FOUND]")
        $failed++
    }
}

# ============================================================================
# 4. TEMPLATES
# ============================================================================

Write-LogEntry ""
Write-LogEntry "4. TEMPLATES"
Write-LogEntry "-------------------------------------------------------------"

$templates = @(
    "investigation_metadata_template.txt",
    "incident_log_template.txt"
)

$templatesPath = Join-Path $scriptPath "templates"

foreach ($template in $templates) {
    $templateFile = Join-Path $templatesPath $template
    if (Test-Path $templateFile -PathType Leaf) {
        $size = (Get-Item $templateFile).Length / 1KB
        $sizeRounded = [math]::Round($size, 1)
        Write-LogEntry ("  [PASS] " + $template + " (" + $sizeRounded + " KB)")
        $passed++
    } else {
        Write-LogEntry ("  [FAIL] " + $template + " [NOT FOUND]")
        $failed++
    }
}

# ============================================================================
# 5. KEY DOCUMENTATION
# ============================================================================

Write-LogEntry ""
Write-LogEntry "5. KEY DOCUMENTATION FILES"
Write-LogEntry "-------------------------------------------------------------"

# Root documentation
$rootDocs = @(
    "README.md",
    "00_START_HERE.md",
    "LICENSE",
    "NOTICE"
)

foreach ($doc in $rootDocs) {
    $docFile = Join-Path $scriptPath $doc
    if (Test-Path $docFile -PathType Leaf) {
        Write-LogEntry ("  [PASS] " + $doc)
        $passed++
    } else {
        Write-LogEntry ("  [WARN] " + $doc + " [NOT FOUND]")
        $warnings++
    }
}

# Organized documentation folders
$docFolders = @(
    @{path="docs\analyst"; desc="Analyst documentation"},
    @{path="docs\sysadmin"; desc="Sysadmin guides"},
    @{path="docs\reference"; desc="Quick references"},
    @{path="docs\DOCUMENTATION_INDEX.md"; desc="Documentation hub"}
)

foreach ($docFolder in $docFolders) {
    $docPath = Join-Path $scriptPath $docFolder.path
    if (Test-Path $docPath) {
        Write-LogEntry ("  [PASS] " + $docFolder.path + " - " + $docFolder.desc)
        $passed++
    } else {
        Write-LogEntry ("  [WARN] " + $docFolder.path + " [NOT FOUND]")
        $warnings++
    }
}

# ============================================================================
# 6. OPTIONAL TOOLS
# ============================================================================

Write-LogEntry ""
Write-LogEntry "6. OPTIONAL ANALYSIS TOOLS"
Write-LogEntry "-------------------------------------------------------------"

$optionalPath = Join-Path $scriptPath "tools\optional"

if (Test-Path $optionalPath -PathType Container) {
    Write-LogEntry "  [PASS] tools/optional/ directory exists"
    $passed++
    
    # Check for Zimmerman Tools
    $zimToolsPath = Join-Path $optionalPath "ZimmermanTools"
    if (Test-Path $zimToolsPath) {
        Write-LogEntry "  [PASS] ZimmermanTools - Installed"
        $passed++
        
        # Check for specific tools
        $zimTools = @("Timeline Explorer", "MFTECmd", "PECmd", "EvtxECmd")
        foreach ($tool in $zimTools) {
            $toolPath = Get-ChildItem -Path $zimToolsPath -Recurse -Filter "$tool.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($toolPath) {
                Write-LogEntry "    [PASS] $tool found"
                $passed++
            } else {
                Write-LogEntry "    [INFO] $tool - Not installed (optional)"
            }
        }
    } else {
        Write-LogEntry "  [INFO] ZimmermanTools - Not installed (optional)"
    }
    
    # Check for YARA rules
    $yaraPath = Join-Path $scriptPath "tools\yara"
    if (Test-Path $yaraPath) {
        Write-LogEntry "  [PASS] tools/yara/ - YARA rules directory exists"
        $passed++
    } else {
        Write-LogEntry "  [INFO] tools/yara/ - Not found (optional)"
    }
} else {
    Write-LogEntry "  [WARN] tools/optional/ directory not found"
    $warnings++
}

# ============================================================================
# 7. SUMMARY
# ============================================================================

Write-LogEntry ""
Write-LogEntry "VALIDATION SUMMARY"
Write-LogEntry "-------------------------------------------------------------"

$total = $passed + $failed + $warnings

Write-LogEntry ("  Passed:   " + $passed + " checks")
Write-LogEntry ("  Failed:   " + $failed + " checks")
Write-LogEntry ("  Warnings: " + $warnings + " checks")
Write-LogEntry "  ---------------------------------"
Write-LogEntry ("  Total:    " + $total + " checks")
Write-LogEntry ""

# ============================================================================
# DEPLOYMENT READINESS
# ============================================================================

if ($failed -eq 0) {
    Write-LogEntry "[PASS] PROJECT STRUCTURE IS READY FOR DEPLOYMENT"
    Write-LogEntry ""
    Write-LogEntry "  Next Steps:"
    Write-LogEntry "  -----------------------------------------------------------"
    Write-LogEntry "  1. Quick Start: Read 00_START_HERE.md"
    Write-LogEntry "  2. Test collection: .\run-collector.ps1"
    Write-LogEntry "     - With transfer: .\run-collector.ps1 -AnalystWorkstation 'WORKSTATION'"
    Write-LogEntry "  3. Build release package: .\Build-Release.ps1 -Zip"
    Write-LogEntry "  4. Analyze results: .\source\Analyze-Investigation.ps1 -InvestigationPath 'path'"
    Write-LogEntry ""
    Write-LogEntry "  Optional Tools:"
    Write-LogEntry "     - Zimmerman Tools: https://ericzimmerman.github.io/"
    Write-LogEntry "     - Download all tools with 'Get-ZimmermanTools.ps1'"
    Write-LogEntry ""
    Write-LogEntry "  Documentation:"
    Write-LogEntry "     -> 00_START_HERE.md (project overview)"
    Write-LogEntry "     -> docs/DOCUMENTATION_INDEX.md (all documentation)"
    Write-LogEntry "     -> docs/sysadmin/ (deployment guides)"
    Write-LogEntry "     -> docs/analyst/ (analysis guides)"
    Write-LogEntry ""
} else {
    Write-LogEntry "[FAIL] PROJECT STRUCTURE NEEDS ATTENTION"
    Write-LogEntry ("  " + $failed + " critical issue(s) found - review failures above")
    Write-LogEntry ""
}

Write-LogEntry "Validation Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-LogEntry "Log file location: $logFile"

Write-Host ""
Write-Host "[PASS] Validation complete! Log saved to: VALIDATE_PROJECT_STRUCTURE.log"
Write-Host ""
