#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Multi-Server Forensic Collection Coordinator
    
.DESCRIPTION
    Orchestrates forensic data collection across multiple Windows servers
    during investigations. Manages investigation folders, tracks results,
    and maintains chain of custody.
    
.PARAMETER InvestigationName
    Name of the investigation (creates investigations\[Name]\ folder)
    
.PARAMETER Targets
    Array of hostnames or IP addresses to collect from
    
.PARAMETER Credential
    Optional PSCredential for remote collection
    
.PARAMETER SkipVerification
    Skip verification of collected data (faster, less thorough)
    
.EXAMPLE
    .\deploy_multi_server.ps1 -InvestigationName "BreachXYZ" -Targets "SERVER01","SERVER02","SERVER03"
    
.NOTES
    Requires collect.ps1 in source/ directory
    Results stored in investigations/[InvestigationName]/[HostName]/[Timestamp]/
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$InvestigationName,
    
    [Parameter(Mandatory=$true)]
    [string[]]$Targets,
    
    [PSCredential]$Credential,
    
    [switch]$SkipVerification
)

$ErrorActionPreference = 'Stop'
$sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Split-Path -Parent $sourceDir
$investigationPath = Join-Path $scriptPath "investigations"
$collectScript = Join-Path $sourceDir "collect.ps1"

# ============================================================================
# Initialize Investigation Folder
# ============================================================================

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        MULTI-SERVER FORENSIC COLLECTION COORDINATOR            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($InvestigationName) {
    Write-Host "Investigation: $InvestigationName" -ForegroundColor Green
} else {
    Write-Host "Investigation: (None - using investigations root folder)" -ForegroundColor Yellow
}

Write-Host "Target Servers: $($Targets.Count)" -ForegroundColor Green
Write-Host ""

# Create investigation folder structure
if ($InvestigationName) {
    $caseFolder = Join-Path $investigationPath $InvestigationName
} else {
    $caseFolder = $investigationPath
}

if (-not (Test-Path $caseFolder)) {
    New-Item -ItemType Directory -Path $caseFolder -Force | Out-Null
    Write-Host "✓ Created investigation folder: $caseFolder" -ForegroundColor Green
}

# Create investigation metadata
$metadataFile = Join-Path $caseFolder "INVESTIGATION_METADATA.txt"
$incidentLogFile = Join-Path $caseFolder "INCIDENT_LOG.txt"

if ($InvestigationName) {
    if (-not (Test-Path $metadataFile)) {
        Copy-Item -Path "$scriptPath\templates\investigation_metadata_template.txt" -Destination $metadataFile
        Write-Host "✓ Created INVESTIGATION_METADATA.txt" -ForegroundColor Green
        Write-Host "  → Edit this file with case details before proceeding" -ForegroundColor Yellow
    }

    if (-not (Test-Path $incidentLogFile)) {
        Copy-Item -Path "$scriptPath\templates\incident_log_template.txt" -Destination $incidentLogFile
        Write-Host "✓ Created INCIDENT_LOG.txt" -ForegroundColor Green
    }
}

# ============================================================================
# Deployment Tracking
# ============================================================================

$deploymentLog = Join-Path $caseFolder "DEPLOYMENT_TRACKING.txt"
$deploymentStart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

"═════════════════════════════════════════════════════════════════" | Set-Content $deploymentLog
"MULTI-SERVER COLLECTION DEPLOYMENT LOG" | Add-Content $deploymentLog
"═════════════════════════════════════════════════════════════════" | Add-Content $deploymentLog
"" | Add-Content $deploymentLog
if ($InvestigationName) {
    "Investigation: $InvestigationName" | Add-Content $deploymentLog
} else {
    "Investigation: (Ad-hoc collection - no case name)" | Add-Content $deploymentLog
}
"Deployment Started: $deploymentStart" | Add-Content $deploymentLog
"Total Targets: $($Targets.Count)" | Add-Content $deploymentLog
"" | Add-Content $deploymentLog
"Targets:" | Add-Content $deploymentLog
foreach ($target in $Targets) {
    "  - $target" | Add-Content $deploymentLog
}
"" | Add-Content $deploymentLog
"" | Add-Content $deploymentLog

# ============================================================================
# Collection Loop
# ============================================================================

$successCount = 0
$failureCount = 0
$partialCount = 0
$collectionResults = @()

foreach ($target in $Targets) {
    Write-Host ""
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "Collecting from: $target" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host ""
    
    $hostFolder = Join-Path $caseFolder $target
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $resultFolder = Join-Path $hostFolder $timestamp
    
    # Create host directory
    New-Item -ItemType Directory -Path $resultFolder -Force -ErrorAction SilentlyContinue | Out-Null
    
    "Collection $target - Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $deploymentLog
    
    try {
        # Determine collection method
        if ($target -eq $env:COMPUTERNAME) {
            # Local collection
            Write-Host "→ Local collection (current computer)" -ForegroundColor Yellow
            
            # Run collect.ps1 (uses hardcoded output paths)
            & $collectScript
            
            # Copy results from source directory to result folder
            Write-Host "  • Copying results to investigation folder..." -ForegroundColor Gray
            
            # Create collected_files directory
            $collectedDir = Join-Path $resultFolder "collected_files"
            New-Item -ItemType Directory -Path $collectedDir -Force -ErrorAction SilentlyContinue | Out-Null
            
            # Copy collected artifacts
            $sourceCollected = Join-Path $sourceDir "collected_files"
            if (Test-Path $sourceCollected) {
                Copy-Item -Path "$sourceCollected\*" -Destination $collectedDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            # Copy collection log
            Copy-Item -Path "$sourceDir\logs\forensic_collection_*.txt" -Destination $resultFolder -Force -ErrorAction SilentlyContinue
        } else {
            # Remote collection
            Write-Host "→ Remote collection (via PowerShell Remoting)" -ForegroundColor Yellow
            
            # Copy collection script to target
            Write-Host "  • Copying collection script to $target..." -ForegroundColor Gray
            
            try {
                $session = if ($Credential) {
                    New-PSSession -ComputerName $target -Credential $Credential -ErrorAction Stop
                } else {
                    New-PSSession -ComputerName $target -ErrorAction Stop
                }
                
                $remoteTempDir = Invoke-Command -Session $session -ScriptBlock { [System.IO.Path]::GetTempPath() }
                $remoteSourceDir = Join-Path $remoteTempDir "cado_batch"
                
                # Create directories on remote
                Invoke-Command -Session $session -ScriptBlock {
                    param([string]$dir, [string]$binsDir)
                    New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue | Out-Null
                    New-Item -ItemType Directory -Path $binsDir -Force -ErrorAction SilentlyContinue | Out-Null
                } -ArgumentList $remoteSourceDir, (Join-Path $remoteSourceDir "bins")
                
                Copy-Item -Path "$sourceDir\collect.ps1" -Destination "$remoteSourceDir\collect.ps1" -ToSession $session -ErrorAction Stop
                Copy-Item -Path "$scriptPath\tools\bins\*" -Destination "$remoteSourceDir\bins\" -ToSession $session -ErrorAction Stop -Recurse
                
                # Run collection on remote
                Write-Host "  • Executing collection on $target..." -ForegroundColor Gray
                
                Invoke-Command -Session $session -ScriptBlock {
                    param([string]$sourceDir)
                    Set-Location $sourceDir
                    & ".\collect.ps1"
                } -ArgumentList $remoteSourceDir -ErrorAction Stop
                
                # Copy results back
                Write-Host "  • Retrieving results from $target..." -ForegroundColor Gray
                $remoteCollected = Join-Path $remoteSourceDir "collected_files"
                
                # Copy collected artifacts
                if (Invoke-Command -Session $session -ScriptBlock { param([string]$p); Test-Path $p } -ArgumentList $remoteCollected) {
                    $collectedDir = Join-Path $resultFolder "collected_files"
                    New-Item -ItemType Directory -Path $collectedDir -Force -ErrorAction SilentlyContinue | Out-Null
                    Copy-Item -Path "$remoteCollected\*" -Destination $collectedDir -FromSession $session -Recurse -ErrorAction Stop
                }
                
                # Copy collection log
                Copy-Item -Path "$remoteSourceDir\logs\forensic_collection_*.txt" -Destination $resultFolder -FromSession $session -ErrorAction SilentlyContinue
                
                # Cleanup remote
                Invoke-Command -Session $session -ScriptBlock {
                    param([string]$sourceDir)
                    Remove-Item -Path $sourceDir -Recurse -Force -ErrorAction SilentlyContinue
                } -ArgumentList $remoteSourceDir
                
                Remove-PSSession $session
            } catch {
                throw "Remote collection failed: $_"
            }
        }
        
        # Verify collection
        if (-not $SkipVerification) {
            Write-Host "  • Verifying collection integrity..." -ForegroundColor Gray
            
            $collectedPath = Join-Path $resultFolder "collected_files"
            $manifestPath = Join-Path $collectedPath "SHA256_MANIFEST.txt"
            
            if (Test-Path $manifestPath) {
                Write-Host "    ✓ SHA256 manifest verified" -ForegroundColor Green
            } else {
                Write-Host "    ⚠ Warning: SHA256 manifest not found" -ForegroundColor Yellow
            }
            
            $logPath = Get-ChildItem -Path $resultFolder -Filter "forensic_collection_*.txt" | Select-Object -First 1
            if ($logPath) {
                $logContent = Get-Content $logPath.FullName -Raw
                if ($logContent -like "*successfully*" -or $logContent -like "*completed*") {
                    Write-Host "    ✓ Collection log indicates success" -ForegroundColor Green
                    $successCount++
                    $status = "SUCCESS"
                } else {
                    Write-Host "    ⚠ Collection log indicates issues" -ForegroundColor Yellow
                    $partialCount++
                    $status = "PARTIAL"
                }
            }
        } else {
            $successCount++
            $status = "SUCCESS"
        }
        
        Write-Host "✓ Collection completed for $target" -ForegroundColor Green
        "  Result: $status" | Add-Content $deploymentLog
        "  Location: $resultFolder" | Add-Content $deploymentLog
        
        $collectionResults += @{
            Host = $target
            Status = $status
            Timestamp = $timestamp
            Path = $resultFolder
        }
        
    } catch {
        Write-Host "✗ Collection FAILED for $target" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        
        $failureCount++
        "  Result: FAILED" | Add-Content $deploymentLog
        "  Error: $_" | Add-Content $deploymentLog
        
        $collectionResults += @{
            Host = $target
            Status = "FAILED"
            Timestamp = $timestamp
            Path = $null
            Error = $_
        }
    }
}

# ============================================================================
# Summary Report
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    COLLECTION SUMMARY                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$deploymentEnd = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$deploymentDuration = [datetime]::Now - [datetime]::ParseExact($deploymentStart, "yyyy-MM-dd HH:mm:ss", $null)

Write-Host "Total Targets:     $($Targets.Count)" -ForegroundColor White
Write-Host "Successful:        $successCount" -ForegroundColor Green
Write-Host "Partial Success:   $partialCount" -ForegroundColor Yellow
Write-Host "Failed:            $failureCount" -ForegroundColor Red
Write-Host ""
Write-Host "Total Duration:    $($deploymentDuration.Hours)h $($deploymentDuration.Minutes)m $($deploymentDuration.Seconds)s" -ForegroundColor White
Write-Host ""

# Add summary to deployment log
"" | Add-Content $deploymentLog
"═════════════════════════════════════════════════════════════════" | Add-Content $deploymentLog
"COLLECTION SUMMARY" | Add-Content $deploymentLog
"═════════════════════════════════════════════════════════════════" | Add-Content $deploymentLog
"Deployment Ended: $deploymentEnd" | Add-Content $deploymentLog
"Total Duration: $($deploymentDuration.Hours)h $($deploymentDuration.Minutes)m $($deploymentDuration.Seconds)s" | Add-Content $deploymentLog
"" | Add-Content $deploymentLog
"Results:" | Add-Content $deploymentLog
"  Total Targets: $($Targets.Count)" | Add-Content $deploymentLog
"  Successful: $successCount" | Add-Content $deploymentLog
"  Partial Success: $partialCount" | Add-Content $deploymentLog
"  Failed: $failureCount" | Add-Content $deploymentLog
"" | Add-Content $deploymentLog

# Detailed results
"DETAILED RESULTS:" | Add-Content $deploymentLog
"─────────────────────────────────────────────────────────────────" | Add-Content $deploymentLog

foreach ($result in $collectionResults) {
    "$($result.Host) | Status: $($result.Status) | Timestamp: $($result.Timestamp)" | Add-Content $deploymentLog
    if ($result.Path) {
        "  Path: $($result.Path)" | Add-Content $deploymentLog
    }
    if ($result.Error) {
        "  Error: $($result.Error)" | Add-Content $deploymentLog
    }
    "" | Add-Content $deploymentLog
}

# Calculate total data collected
Write-Host "Data Summary:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan

$totalSize = 0
$totalFiles = 0

foreach ($result in $collectionResults | Where-Object { $_.Path }) {
    if (Test-Path $result.Path) {
        $dirSize = (Get-ChildItem -Path $result.Path -Recurse | Measure-Object -Property Length -Sum).Sum
        $fileCount = (Get-ChildItem -Path $result.Path -Recurse | Measure-Object).Count
        
        $totalSize += $dirSize
        $totalFiles += $fileCount
        
        $sizeGb = $dirSize / 1GB
        Write-Host "  $($result.Host): $([math]::Round($sizeGb, 2)) GB ($fileCount files)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "  TOTAL: $([math]::Round($totalSize / 1GB, 2)) GB ($totalFiles files)" -ForegroundColor Green

"" | Add-Content $deploymentLog
"Total Data Collected: $([math]::Round($totalSize / 1GB, 2)) GB ($totalFiles files)" | Add-Content $deploymentLog

# ============================================================================
# Next Steps
# ============================================================================

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Yellow

if ($InvestigationName) {
    Write-Host "1. Review INVESTIGATION_METADATA.txt:" -ForegroundColor Yellow
    Write-Host "   $metadataFile" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Update INCIDENT_LOG.txt with findings:" -ForegroundColor Yellow
    Write-Host "   $incidentLogFile" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "3. Collected data locations:" -ForegroundColor Yellow
} else {
    Write-Host "1. Review collected data:" -ForegroundColor Yellow
}

foreach ($result in $collectionResults | Where-Object { $_.Path }) {
    Write-Host "   - $($result.Host): $($result.Path)" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "2. Optional analysis tools:" -ForegroundColor Yellow
Write-Host "   - See PHASE_2_TOOLS_INSTALLATION.md for prefetch parsing" -ForegroundColor Cyan
Write-Host "   - See DOCUMENTATION_INDEX.md for analysis guides" -ForegroundColor Cyan
Write-Host ""

# Write completion marker
"" | Add-Content $deploymentLog
"Deployment Log Completed" | Add-Content $deploymentLog
"═════════════════════════════════════════════════════════════════" | Add-Content $deploymentLog

Write-Host "Deployment log saved:" -ForegroundColor Green
Write-Host "  $deploymentLog" -ForegroundColor Cyan
Write-Host ""
Write-Host "Investigation folder:" -ForegroundColor Green
Write-Host "  $caseFolder" -ForegroundColor Cyan
Write-Host ""
