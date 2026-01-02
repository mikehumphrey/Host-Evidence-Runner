<#
.SYNOPSIS
    Publishes the latest HER release zip to specified targets.
.DESCRIPTION
    - Finds the latest HER-v*.zip in releases/ (or creates it from the latest build folder)
    - Copies to specified network shares
    - Copies to specified remote servers and extracts
    - Copies to local path and extracts
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$NetworkShares,

    [Parameter(Mandatory=$false)]
    [hashtable[]]$RemoteTargets, 
    # Expected format: 
    # @{ 
    #    ComputerName='Server'; 
    #    UncCopyPath='\\Server\c$\Temp'; 
    #    LocalZipPath='C:\Temp\HER-ReleaseID.zip'; 
    #    LocalExtractPath='C:\Temp\HER-Collector' 
    # }

    [Parameter(Mandatory=$false)]
    [hashtable]$LocalTarget,
    # Expected format: @{ TempPath='C:\Temp'; ExtractPath='C:\Temp\HER-$Version' }

    [Parameter(Mandatory=$false)]
    [string]$SourcePath
    # Optional: Path to a specific build folder (e.g. releases/v1.0.0) or zip file.
    # If omitted, defaults to the latest timestamped release from RELEASE_NOTES.md.
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath
$releasesRoot = Join-Path $root 'releases'

# --- Determine Release Source ---
if ($SourcePath) {
    # Mode A: Explicit Source (e.g. GitHub Release)
    if (-not (Test-Path $SourcePath)) { throw "SourcePath not found: $SourcePath" }
    
    if ((Get-Item $SourcePath).PSIsContainer) {
        # It's a folder (e.g. releases/v1.0.0)
        $buildFolder = $SourcePath
        $dirName = Split-Path $buildFolder -Leaf
        
        # Try to deduce metadata
        if ($dirName -match '^v(\d+\.\d+\.\d+)$') {
            $Version = $Matches[1]
            $ReleaseID = "v$Version"
            $zipName = "HER-v$Version.zip"
        } elseif ($dirName -match '^\d{8}_\d{6}$') {
            $ReleaseID = $dirName
            $Version = "Unknown" 
            $zipName = "HER-$ReleaseID.zip"
        } else {
            $ReleaseID = $dirName
            $Version = "Custom"
            $zipName = "HER-$dirName.zip"
        }
        
        $zipPath = Join-Path $releasesRoot $zipName
        
        # Create Zip if missing
        if (-not (Test-Path $zipPath)) {
            Write-Host "Zipping source: $buildFolder -> $zipPath" -ForegroundColor Yellow
            Compress-Archive -Path "$buildFolder\*" -DestinationPath $zipPath -Force
            Write-Host "  ✓ Created zip: $zipPath" -ForegroundColor Green
        } else {
            Write-Host "Using existing zip: $zipPath" -ForegroundColor Green
        }
    } else {
        # It's a file (Zip)
        $zipPath = $SourcePath
        $zipName = Split-Path $zipPath -Leaf
        # Simple deduction
        $ReleaseID = "External"
        $Version = "External"
        if ($zipName -match 'v(\d+\.\d+\.\d+)') { $Version = $Matches[1] }
    }
    
    Write-Host "Using explicit source: $SourcePath" -ForegroundColor Cyan

} else {
    # Mode B: Auto-detect latest timestamped release (Default/Legacy)
    
    # Get latest release info from RELEASE_NOTES.md
    $releaseNotesPath = Join-Path $root 'RELEASE_NOTES.md'
    if (-not (Test-Path $releaseNotesPath)) {
        Write-Error "RELEASE_NOTES.md not found!"
        exit 1
    }
    $releaseNotes = Get-Content $releaseNotesPath -Raw

    # Extract Release ID and Version
    if ($releaseNotes -match '(?m)^- \*\*Release ID\*\*:\s*(\d{8}_\d{6})') {
        $ReleaseID = $Matches[1]
    } else {
        Write-Error "Could not find Release ID in RELEASE_NOTES.md"
        exit 1
    }
    if ($releaseNotes -match '(?m)^- \*\*Version\*\*:\s*(\d+\.\d+\.\d+)') {
        $Version = $Matches[1]
    } else {
        $Version = 'Unknown'
    }

    # Locate the latest build folder
    $buildFolder = Join-Path $releasesRoot $ReleaseID
    if (-not (Test-Path $buildFolder)) {
        Write-Error "Build folder not found: $buildFolder"
        exit 1
    }

    # Zip the build folder if not already zipped
    $zipName = "HER-$ReleaseID.zip"
    $zipPath = Join-Path $releasesRoot $zipName
    if (-not (Test-Path $zipPath)) {
        Write-Host "Zipping latest build folder: $buildFolder -> $zipPath" -ForegroundColor Yellow
        Compress-Archive -Path "$buildFolder\*" -DestinationPath $zipPath -Force
        Write-Host "  ✓ Created zip: $zipPath" -ForegroundColor Green
    } else {
        Write-Host "Using existing zip: $zipPath" -ForegroundColor Green
    }
}

Write-Host "Publishing HER release: $zipName (Version: $Version, Release ID: $ReleaseID)" -ForegroundColor Cyan

# 1. Copy to network shares
if ($NetworkShares) {
    foreach ($target in $NetworkShares) {
        try {
            Write-Host "Copying to $target..." -ForegroundColor Yellow
            Copy-Item -Path $zipPath -Destination $target -Force
            Write-Host "  ✓ Copied to $target" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to copy to ${target}: $_"
        }
    }
}

# 2. Copy to remote servers and extract
if ($RemoteTargets) {
    foreach ($target in $RemoteTargets) {
        $computer = $target.ComputerName
        $uncCopyPath = $target.UncCopyPath
        
        # Resolve dynamic paths if they contain variables like $ReleaseID
        $localZipPath = $target.LocalZipPath.Replace('$ReleaseID', $ReleaseID)
        $localExtractPath = $target.LocalExtractPath
        
        try {
            Write-Host "Copying to $uncCopyPath ($computer)..." -ForegroundColor Yellow
            Copy-Item -Path $zipPath -Destination $uncCopyPath -Force
            Write-Host "  ✓ Copied to $uncCopyPath" -ForegroundColor Green
            
            # Extract remotely using PowerShell remoting
            Write-Host "Extracting to $localExtractPath..." -ForegroundColor Yellow
            $session = New-PSSession -ComputerName $computer
            
            Invoke-Command -Session $session -ScriptBlock {
                param($zip, $dest)
                if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
                Expand-Archive -Path $zip -DestinationPath $dest -Force
            } -ArgumentList $localZipPath, $localExtractPath
            
            Remove-PSSession $session
            Write-Host "  ✓ Extracted to $localExtractPath" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to copy/extract on remote server ($computer): $_"
        }
    }
}

# 3. Copy to local C:\Temp and extract
if ($LocalTarget) {
    $localTemp = $LocalTarget.TempPath
    $localExtract = $LocalTarget.ExtractPath
    # Replace 'HER-$Version' placeholder if present
    $localExtract = $localExtract.Replace('$Version', $Version)
    
    try {
        Write-Host "Copying to $localTemp..." -ForegroundColor Yellow
        Copy-Item -Path $zipPath -Destination $localTemp -Force
        Write-Host "  ✓ Copied to $localTemp" -ForegroundColor Green
        
        if (Test-Path $localExtract) { Remove-Item $localExtract -Recurse -Force }
        Write-Host "Extracting to $localExtract..." -ForegroundColor Yellow
        Expand-Archive -Path (Join-Path $localTemp (Split-Path $zipPath -Leaf)) -DestinationPath $localExtract -Force
        Write-Host "  ✓ Extracted to $localExtract" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to copy/extract locally: $_"
    }
}

Write-Host "Publish Release complete." -ForegroundColor Cyan
