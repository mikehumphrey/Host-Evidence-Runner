#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$RootPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoZip,
    
    [Parameter(Mandatory=$false)]
    [string]$AnalystWorkstation
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Determine script path and root
if ($RootPath) {
    # Use provided root (from run-collector.ps1)
    $scriptRoot = Resolve-Path $RootPath
    $scriptPath = Join-Path $scriptRoot 'source'
} else {
    # Fallback: running directly from source folder
    $scriptPath = $PSScriptRoot
    $scriptRoot = Split-Path -Parent $scriptPath
}

# ============================================================================
# Initialize Logging
# ============================================================================

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$computerName = $env:COMPUTERNAME

# Create investigation folder structure: investigations/[HOSTNAME]/[TIMESTAMP]/
$investigationsRoot = Join-Path $scriptRoot "investigations"
$hostFolder = Join-Path $investigationsRoot $computerName
$outputRoot = Join-Path $hostFolder $timestamp

if (-not (Test-Path $outputRoot)) {
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
}

$logFile = Join-Path $outputRoot "forensic_collection_${computerName}_${timestamp}.txt"

# Function to write log entries
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $logFile -Value $logEntry
    
    # Also write to console
    switch ($Level) {
        'Error' { Write-Host $logEntry -ForegroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Info' { Write-Host $logEntry -ForegroundColor Green }
    }
}

# Start logging
try {
    Write-Log "============================================================================"
    Write-Log "Host Evidence Runner (HER) - Collection Started"
    Write-Log "Derived from the archived Cado-Batch project; independently maintained"
    Write-Log "============================================================================"
    Write-Log "Computer: $computerName"
    Write-Log "User: $env:USERNAME"
    Write-Log "Script Location: $scriptPath"
    Write-Log "Script Root: $scriptRoot"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Log "OS Version: $([System.Environment]::OSVersion)"
} catch {
    Write-Host "FATAL ERROR during initialization: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Safe path join to force string casting and avoid array-to-string binding issues
function SafeJoinPath {
    param(
        [Parameter(Mandatory)]$Parent,
        [Parameter(Mandatory)]$Child
    )
    # Handle arrays by taking first element
    if ($Parent -is [array]) {
        Write-Log "WARNING: Parent is an array with $($Parent.Count) elements, taking first" -Level Warning
        $Parent = $Parent[0]
    }
    if ($Child -is [array]) {
        Write-Log "WARNING: Child is an array with $($Child.Count) elements, taking first" -Level Warning
        $Child = $Child[0]
    }
    
    # Convert to string
    $parentStr = [string]$Parent
    $childStr = [string]$Child
    
    try {
        $result = Join-Path $parentStr $childStr
        return $result
    } catch {
        Write-Log "ERROR in SafeJoinPath: $_" -Level Error
        Write-Log "ERROR details: Parent=$parentStr, Child=$childStr" -Level Error
        throw
    }
}

# Resolve the bins directory once so tools can live either beside the script
# (source\bins) or at the release root (tools\bins), keeping a single copy.
function Resolve-BinPath {
    param([string[]]$Candidates)

    foreach ($c in $Candidates) {
        if (Test-Path $c) {
            return (Resolve-Path $c).Path
        }
    }

    throw "Required tools folder not found. Expected one of: $($Candidates -join ', ')"
}

try {
    Write-Verbose "Resolving tools directory..."
    $parentPath = Split-Path $scriptPath -Parent
    
    $bin1 = SafeJoinPath $scriptPath 'bins'
    $bin2 = SafeJoinPath $parentPath 'tools\bins'
    $bin3 = SafeJoinPath $parentPath 'bins'
    
    $binCandidates = @($bin1, $bin2, $bin3)
    
    Write-Verbose "Tools path candidates: $($binCandidates -join ', ')"
    
    $binPath = Resolve-BinPath -Candidates $binCandidates
} catch {
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host "FATAL ERROR: Tools Directory Not Found" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "The required forensic tools could not be located." -ForegroundColor Red
    Write-Host ""
    Write-Host "Expected locations:" -ForegroundColor Yellow
    Write-Host "  - $scriptPath\bins" -ForegroundColor White
    Write-Host "  - $parentPath\tools\bins" -ForegroundColor White
    Write-Host "  - $parentPath\bins" -ForegroundColor White
    Write-Host ""
    Write-Host "Current working directory: $(Get-Location)" -ForegroundColor White
    Write-Host "Script root: $scriptRoot" -ForegroundColor White
    Write-Host ""
    Write-Host "Please ensure the HER-Collector was extracted completely with all subfolders." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Error details: $_" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    exit 1
}

function Get-BinFile {
    param([Parameter(Mandatory)][string]$Name)
    try {
        # Check if a 64-bit version exists (e.g., hashdeep64.exe instead of hashdeep.exe)
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Name)
        $extension = [System.IO.Path]::GetExtension($Name)
        $name64 = "${baseName}64${extension}"
        $path64 = Join-Path ([string]$binPath) ([string]$name64)
        
        if (Test-Path $path64) {
            return $path64
        }
        
        # Fall back to 32-bit version
        $result = Join-Path ([string]$binPath) ([string]$Name)
        return $result
    } catch {
        Write-Log "ERROR in Get-BinFile: $_" -Level Error
        Write-Log "ERROR details: binPath=$binPath, Name=$Name" -Level Error
        throw
    }
}

Write-Log "Using tools from: $binPath"

# ============================================================================
# Initialize Collection Tracking
# ============================================================================

$script:collectionStats = @{
    TotalItems = 0
    SuccessfulItems = 0
    Warnings = 0
    Errors = 0
    CollectionDetails = @()
}

function Add-CollectionResult {
    param(
        [string]$ItemName,
        [ValidateSet('Success', 'Warning', 'Error')]
        [string]$Status,
        [string]$Message = ''
    )
    
    $script:collectionStats.TotalItems++
    
    switch ($Status) {
        'Success' { $script:collectionStats.SuccessfulItems++ }
        'Warning' { $script:collectionStats.Warnings++ }
        'Error' { $script:collectionStats.Errors++ }
    }
    
    $script:collectionStats.CollectionDetails += [PSCustomObject]@{
        Item = $ItemName
        Status = $Status
        Message = $Message
        Timestamp = Get-Date -Format "HH:mm:ss"
    }
}

# Function to detect hypervisor/virtualization
function Get-HypervisorInfo {
    Write-Log "Detecting hypervisor environment..."
    
    try {
        $systemInfo = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
        
        $hypervisor = "Physical Hardware"
        
        # Check for common hypervisors
        if ($systemInfo.Manufacturer -like "*VMware*") {
            $hypervisor = "VMware vSphere"
        } elseif ($systemInfo.Manufacturer -like "*Microsoft*" -and $systemInfo.Model -like "*Virtual*") {
            $hypervisor = "Microsoft Hyper-V"
        } elseif ($systemInfo.Manufacturer -like "*Xen*") {
            $hypervisor = "Citrix XenServer"
        } elseif ($systemInfo.Manufacturer -like "*KVM*") {
            $hypervisor = "KVM"
        } elseif ($systemInfo.Manufacturer -like "*QEMU*") {
            $hypervisor = "QEMU"
        }
        
        # Check for VirtualBox
        $vboxCheck = Get-WmiObject -Class Win32_PnPSignedDevice -ErrorAction SilentlyContinue | Where-Object {$_.Description -like "*VirtualBox*"}
        if ($vboxCheck) {
            $hypervisor = "Oracle VirtualBox"
        }
        
        Write-Log "Hypervisor detected: $hypervisor"
        Write-Log "System Manufacturer: $($systemInfo.Manufacturer)"
        Write-Log "System Model: $($systemInfo.Model)"
        
        return $hypervisor
    } catch {
        Write-Log "Could not determine hypervisor environment: $_" -Level Warning
        return "Unknown"
    }
}

# Function to detect server roles
function Get-InstalledServerRoles {
    Write-Log "Detecting installed server roles..."
    
    try {
        $roles = @()
        
        # Check for various roles using Get-WindowsFeature (Server 2012+)
        if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
            $features = Get-WindowsFeature | Where-Object { $_.Installed }
            
            if ($features | Where-Object {$_.Name -like "*AD-Domain-Services*"}) {
                $roles += "Active Directory Domain Services"
            }
            if ($features | Where-Object {$_.Name -like "*DNS*" -and $_.Installed}) {
                $roles += "DNS Server"
            }
            if ($features | Where-Object {$_.Name -like "*FS-DFS*"}) {
                $roles += "DFS"
            }
            if ($features | Where-Object {$_.Name -like "*ADCS*"}) {
                $roles += "Certificate Authority"
            }
            if ($features | Where-Object {$_.Name -like "*FS-File-Services*"}) {
                $roles += "File Services"
            }
        }
        
        # Fallback: Check services if Get-WindowsFeature unavailable
        if ($roles.Count -eq 0) {
            $services = Get-Service -ErrorAction SilentlyContinue
            
            if ($services | Where-Object {$_.Name -eq "NTDS"}) {
                $roles += "Active Directory Domain Services"
            }
            if ($services | Where-Object {$_.Name -eq "DNS"}) {
                $roles += "DNS Server"
            }
            if ($services | Where-Object {$_.Name -eq "DFSR"}) {
                $roles += "DFS"
            }
        }
        
        if ($roles.Count -eq 0) {
            $roles += "Standard Server (No Specialized Roles Detected)"
        }
        
        foreach ($role in $roles) {
            Write-Log "  - Detected role: $role"
        }
        
        return $roles
    } catch {
        Write-Log "Error detecting server roles: $_" -Level Warning
        return @("Unknown")
    }
}

# Function to handle operations that might exceed MAX_PATH
function Invoke-SafeFileOperation {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$OperationType = 'Copy'
    )
    
    try {
        # Check path lengths
        if ($DestinationPath.Length -gt 248) {
            Write-Verbose "Destination path exceeds 248 chars, using robocopy: $DestinationPath"
            if (Test-Path $SourcePath) {
                New-Item -ItemType Directory -Path $DestinationPath -Force -ErrorAction SilentlyContinue | Out-Null
                robocopy (Split-Path $SourcePath) $DestinationPath (Split-Path $SourcePath -Leaf) /R:1 /W:1 2>&1 | Out-Null
            }
        } else {
            # Path is safe, use Copy-Item
            if (Test-Path $SourcePath) {
                Copy-Item -Path $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
            }
        }
    } catch {
        Write-Verbose "Safe file operation failed: $_"
    }
}

try {
    Write-Verbose "Moving to the correct working directory: $scriptPath"
    Set-Location -Path $scriptPath
    Write-Log "Working directory: $scriptPath"
    
    # Detect hypervisor and roles
    $hypervisor = Get-HypervisorInfo
    $serverRoles = Get-InstalledServerRoles

    $outputDir = Join-Path $outputRoot "collected_files"
    if (-not (Test-Path -Path $outputDir)) {
        Write-Verbose "Creating output directory: $outputDir"
        Write-Log "Creating output directory: $outputDir"
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Write-Verbose "Collecting MFT and LogFile from C: drive"
    Write-Log "Collecting MFT and LogFile from C: drive"
    
    # RawCopy outputs to current directory by default - simpler than specifying OutputPath with spaces
    $rawCopyExe = Get-BinFile 'RawCopy.exe'
    $currentDir = Get-Location
    
    # Collect MFT
    Start-Process -FilePath $rawCopyExe -ArgumentList '/FileNamePath:C:0' -Wait -NoNewWindow -WorkingDirectory $currentDir
    if (Test-Path (Join-Path $currentDir '$MFT')) {
        Move-Item -Path (Join-Path $currentDir '$MFT') -Destination "$outputDir\MFT_C.bin" -Force
    }
    
    # Collect LogFile
    Start-Process -FilePath $rawCopyExe -ArgumentList "/FileNamePath:c:\$LogFile" -Wait -NoNewWindow -WorkingDirectory $currentDir
    if (Test-Path (Join-Path $currentDir '$LogFile')) {
        Move-Item -Path (Join-Path $currentDir '$LogFile') -Destination "$outputDir\LogFile_C.bin" -Force
    }
    Write-Host "Successfully collected MFT and LogFile."
    Write-Log "Successfully collected MFT and LogFile."
    Add-CollectionResult -ItemName "MFT and LogFile" -Status Success

    Write-Verbose "Collecting EVTX files..."
    Write-Log "Collecting EVTX files..."
    Copy-Item -Path "$env:SystemRoot\System32\winevt\logs\*.evtx" -Destination "$outputDir\" -Recurse -Force
    Write-Host "Successfully collected EVTX files."
    Write-Log "Successfully collected EVTX files."
    Add-CollectionResult -ItemName "Event Logs (EVTX)" -Status Success

    Write-Verbose "Collecting System Registry hives..."
    Write-Log "Collecting System Registry hives..."
    robocopy "$env:SystemRoot\System32\Config" "$outputDir\Registry" /E /R:1 /W:1 | Out-Null
    Write-Host "Successfully collected System Registry hives."
    Write-Log "Successfully collected System Registry hives."
    Add-CollectionResult -ItemName "System Registry Hives" -Status Success

    # Flatten deep registry paths to avoid MAX_PATH issues during hashing
    Write-Verbose "Flattening deep registry paths for hash compatibility..."
    Write-Log "Flattening deep registry paths to avoid MAX_PATH limitations"
    
    $flattenedDir = Join-Path $outputDir "Registry\Flattened_LongPaths"
    New-Item -ItemType Directory -Path $flattenedDir -Force -ErrorAction SilentlyContinue | Out-Null
    
    try {
        # Find files in Registry directory with paths > 200 characters (conservative threshold)
        $registryDir = Join-Path $outputDir "Registry"
        $longPathFiles = Get-ChildItem -Path $registryDir -Recurse -File -ErrorAction SilentlyContinue | 
            Where-Object { $_.FullName.Length -gt 200 }
        
        if ($longPathFiles) {
            $flattenCount = 0
            foreach ($file in $longPathFiles) {
                try {
                    # Create a flattened filename with path context
                    # Example: systemprofile_AppData_Local_Microsoft_Windows_CloudAPCache_filename.ext
                    $relativePath = $file.FullName.Substring($registryDir.Length + 1)
                    $flatName = $relativePath -replace '\\', '_' -replace '/', '_'
                    
                    # Truncate if still too long (keep extension)
                    if ($flatName.Length -gt 180) {
                        $extension = [System.IO.Path]::GetExtension($flatName)
                        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($flatName)
                        $hash = ($baseName | Get-FileHash -Algorithm MD5 -ErrorAction SilentlyContinue).Hash
                        if ($hash) {
                            $flatName = $hash + $extension
                        } else {
                            $flatName = $baseName.Substring(0, [Math]::Min(175, $baseName.Length)) + $extension
                        }
                    }
                    
                    $destPath = Join-Path $flattenedDir $flatName
                    Copy-Item -Path $file.FullName -Destination $destPath -Force -ErrorAction Stop
                    $flattenCount++
                } catch {
                    Write-Log "  Could not flatten: $($file.FullName)" -Level Warning
                }
            }
            
            Write-Log "Flattened $flattenCount files from deep registry paths"
            Write-Host "Flattened $flattenCount registry files with long paths." -ForegroundColor Cyan
        } else {
            Write-Verbose "  No excessively long paths detected in Registry collection"
        }
    } catch {
        Write-Log "Warning: Could not complete registry path flattening: $_" -Level Warning
    }

    Write-Verbose "Collecting additional system artifacts..."
    
    # Collect Prefetch files
    $prefetchDir = Join-Path $env:SystemRoot "Prefetch"
    if (Test-Path $prefetchDir) {
        Write-Verbose "Collecting prefetch files from $prefetchDir"
        try {
            $prefetchDestination = Join-Path $outputDir "Prefetch"
            if (-not (Test-Path $prefetchDestination)) {
                New-Item -ItemType Directory -Path $prefetchDestination -Force | Out-Null
            }
            $prefetchFiles = Get-ChildItem -Path $prefetchDir -Filter "*.pf" -ErrorAction Stop
            $prefetchFiles | ForEach-Object {
                try {
                    Copy-Item -Path $_.FullName -Destination $prefetchDestination -Force -ErrorAction Stop
                } catch {
                    Write-Verbose "Could not copy $($_.Name): $_"
                }
            }
            Write-Host "Successfully collected prefetch files."
            Write-Log "Successfully collected prefetch files ($($prefetchFiles.Count) files)"
            Add-CollectionResult -ItemName "Prefetch Files" -Status Success
        } catch {
            Write-Log "Warning: Could not collect all prefetch files: $_" -Level Warning
            Write-Host "Warning: Prefetch collection partially failed - continuing..." -ForegroundColor Yellow
            Add-CollectionResult -ItemName "Prefetch Files" -Status Warning -Message "Partial failure: $_"
        }
    }

    # Collect Scheduled Tasks (XML format)
    Write-Verbose "Collecting Windows Scheduled Tasks..."
    $tasksPath = Join-Path $env:SystemRoot "System32\Tasks"
    if (Test-Path $tasksPath) {
        robocopy $tasksPath "$outputDir\ScheduledTasks" /E /R:1 /W:1 | Out-Null
        Write-Host "Successfully collected scheduled tasks."
    }

    # Collect Windows Search Index
    Write-Verbose "Collecting Windows Search Index (Windows.db)..."
    $searchPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Search\Data\Applications\Windows\Windows.db"
    if (Test-Path $searchPath) {
        try {
            Copy-Item -Path $searchPath -Destination "$outputDir\" -Force -ErrorAction Stop
            Write-Host "Successfully collected Windows Search Index."
            Write-Log "Successfully collected Windows Search Index"
        } catch {
            Write-Log "Warning: Could not collect Windows Search Index (file may be locked): $_" -Level Warning
            Write-Host "Warning: Windows Search Index collection failed - continuing..." -ForegroundColor Yellow
        }
    }

    # Collect HOSTS file
    Write-Verbose "Collecting HOSTS file..."
    $hostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
    if (Test-Path $hostsPath) {
        try {
            Copy-Item -Path $hostsPath -Destination "$outputDir\" -Force -ErrorAction Stop
            Write-Host "Successfully collected HOSTS file."
            Write-Log "Successfully collected HOSTS file"
        } catch {
            Write-Log "Warning: Could not collect HOSTS file: $_" -Level Warning
            Write-Host "Warning: HOSTS file collection failed - continuing..." -ForegroundColor Yellow
        }
    }

    # Collect Recycle Bin info ($Recycle.Bin)
    Write-Verbose "Collecting Recycle Bin metadata..."
    $recycleDir = Join-Path $env:SystemDrive '$Recycle.Bin'
    if (Test-Path $recycleDir) {
        robocopy $recycleDir "$outputDir\RecycleBin" /E /R:1 /W:1 | Out-Null
        Write-Host "Successfully collected Recycle Bin data."
    }

    # Collect Windows Temp directory
    Write-Verbose "Collecting Windows Temp directory..."
    $winTempPath = Join-Path $env:SystemRoot "Temp"
    if (Test-Path $winTempPath) {
        robocopy $winTempPath "$outputDir\Windows_Temp" /E /R:1 /W:1 | Out-Null
        Write-Host "Successfully collected Windows Temp files."
    }

    # Collect Amcache.hve
    $amcachePath = Join-Path $env:SystemRoot "appcompat\Programs\Amcache.hve"
    if (Test-Path $amcachePath) {
        Write-Verbose "Collecting Amcache.hve"
        try {
            Copy-Item -Path $amcachePath -Destination "$outputDir\" -Force -ErrorAction Stop
            Write-Host "Successfully collected Amcache.hve."
            Write-Log "Successfully collected Amcache.hve"
            Add-CollectionResult -ItemName "Amcache.hve" -Status Success
        } catch {
            Write-Log "Note: Amcache.hve is locked - will attempt collection with RawCopy during user activity phase" -Level Info
            Write-Verbose "Amcache.hve is locked - will use RawCopy later"
            # Don't add a warning result here - RawCopy will handle it later
        }
    }

    # Collect SRUM database
    $srumPath = Join-Path $env:SystemRoot "System32\sru\SRUDB.dat"
    if (Test-Path $srumPath) {
        Write-Verbose "Collecting SRUM database (SRUDB.dat)"
        try {
            robocopy (Split-Path $srumPath) "$outputDir" (Split-Path $srumPath -Leaf) /R:1 /W:1 | Out-Null
            Write-Host "Successfully collected SRUM database."
            Write-Log "Successfully collected SRUM database"
        } catch {
            Write-Log "Warning: Could not collect SRUM database (file may be locked): $_" -Level Warning
            Write-Host "Warning: SRUM database collection failed (file locked) - continuing..." -ForegroundColor Yellow
        }
    }

    # Collect USN Journal
    Write-Verbose "Collecting USN Journal (\$UsnJrnl)"
    $rawCopyExe = Get-BinFile 'RawCopy.exe'
    $currentDir = Get-Location
    
    Start-Process -FilePath $rawCopyExe -ArgumentList "/FileNamePath:C:\$Extend\$UsnJrnl" -Wait -NoNewWindow -WorkingDirectory $currentDir
    if (Test-Path (Join-Path $currentDir '$UsnJrnl')) {
        Move-Item -Path (Join-Path $currentDir '$UsnJrnl') -Destination "$outputDir\UsnJrnl_C.bin" -Force
        Write-Host "Successfully collected USN Journal."
    } else {
        Write-Warning "Could not find the collected USN Journal. RawCopy may have failed."
    }

    # ============================================================================
    # Domain Controller & Server Role Specific Artifacts
    # ============================================================================
    
    Write-Verbose "Collecting Domain Controller and server role-specific artifacts..."
    Write-Log "Collecting server role-specific artifacts based on detected features"
    
    # Active Directory Database (NTDS.dit) - Critical for DC investigations
    if ($serverRoles -like "*Active Directory*") {
        Write-Verbose "  - Collecting Active Directory artifacts..."
        Write-Log "Active Directory Domain Services detected - collecting AD artifacts"
        
        try {
            # Collect NTDS.dit using RawCopy (database is locked)
            $ntdsPath = "C:\Windows\NTDS\ntds.dit"
            if (Test-Path $ntdsPath) {
                Write-Log "  - Attempting to copy NTDS.dit (Active Directory database)"
                $rawCopyPath = Get-BinFile 'RawCopy.exe'
                $ntdsOutputPath = Join-Path $outputDir 'ActiveDirectory'
                if (-not (Test-Path $ntdsOutputPath)) {
                    New-Item -ItemType Directory -Path $ntdsOutputPath -Force | Out-Null
                }
                
                # Copy to temp, then move (avoids path issues)
                $currentDir = Get-Location
                Start-Process -FilePath $rawCopyPath -ArgumentList "/FileNamePath:$ntdsPath" -Wait -NoNewWindow -WorkingDirectory $currentDir
                if (Test-Path (Join-Path $currentDir 'ntds.dit')) {
                    Move-Item -Path (Join-Path $currentDir 'ntds.dit') -Destination $ntdsOutputPath -Force
                }
                Write-Host "Successfully collected Active Directory database (NTDS.dit)." -ForegroundColor Green
                Add-CollectionResult -ItemName "Active Directory Database (NTDS.dit)" -Status Success
            }
            
            # Collect AD log files
            $ntdsLogPath = "C:\Windows\NTDS"
            if (Test-Path $ntdsLogPath) {
                robocopy $ntdsLogPath "$outputDir\ActiveDirectory\Logs" *.log /R:1 /W:1 | Out-Null
                Write-Log "  - Collected AD transaction logs"
            }
            
            # Collect SYSVOL (Group Policy and logon scripts)
            $sysvolPath = "C:\Windows\SYSVOL\sysvol"
            if (Test-Path $sysvolPath) {
                Write-Log "  - Collecting SYSVOL (Group Policy objects)"
                robocopy $sysvolPath "$outputDir\SYSVOL" /E /R:1 /W:1 /XD "Staging Areas" | Out-Null
                Write-Host "Successfully collected SYSVOL (Group Policies)." -ForegroundColor Green
            }
            
        } catch {
            Write-Log "Warning: Could not collect some AD artifacts: $_" -Level Warning
            Add-CollectionResult -ItemName "Active Directory Artifacts" -Status Warning -Message "Partial collection: $_"
        }
    }
    
    # DNS Server logs and zones
    if ($serverRoles -like "*DNS*") {
        Write-Verbose "  - Collecting DNS Server artifacts..."
        Write-Log "DNS Server detected - collecting DNS logs and zone files"
        
        try {
            # DNS debug log
            $dnsLogPath = "C:\Windows\System32\dns\dns.log"
            if (Test-Path $dnsLogPath) {
                Copy-Item -Path $dnsLogPath -Destination "$outputDir\DNS\" -Force -ErrorAction SilentlyContinue
                Write-Log "  - Collected DNS debug log"
            }
            
            # DNS zone files
            $dnsZonePath = "C:\Windows\System32\dns"
            if (Test-Path $dnsZonePath) {
                robocopy $dnsZonePath "$outputDir\DNS\Zones" *.dns /R:1 /W:1 | Out-Null
                Write-Log "  - Collected DNS zone files"
                Write-Host "Successfully collected DNS logs and zones." -ForegroundColor Green
                Add-CollectionResult -ItemName "DNS Server Data" -Status Success
            }
        } catch {
            Write-Log "Warning: Could not collect DNS artifacts: $_" -Level Warning
        }
    }
    
    # DHCP Server leases and logs
    if ($serverRoles -like "*DHCP*") {
        Write-Verbose "  - Collecting DHCP Server artifacts..."
        Write-Log "DHCP Server detected - collecting DHCP database and logs"
        
        try {
            $dhcpPath = "C:\Windows\System32\dhcp"
            if (Test-Path $dhcpPath) {
                robocopy $dhcpPath "$outputDir\DHCP" *.mdb *.log *.txt /R:1 /W:1 | Out-Null
                Write-Host "Successfully collected DHCP leases and logs." -ForegroundColor Green
                Write-Log "  - Collected DHCP database and logs"
                Add-CollectionResult -ItemName "DHCP Server Data" -Status Success
            }
        } catch {
            Write-Log "Warning: Could not collect DHCP artifacts: $_" -Level Warning
        }
    }
    
    # IIS Web Server logs and configuration
    if ($serverRoles -like "*IIS*" -or $serverRoles -like "*Web*") {
        Write-Verbose "  - Collecting IIS Web Server artifacts..."
        Write-Log "IIS Web Server detected - collecting web logs and configuration"
        
        try {
            # IIS logs
            $iisLogPath = "C:\inetpub\logs\LogFiles"
            if (Test-Path $iisLogPath) {
                robocopy $iisLogPath "$outputDir\IIS\Logs" /E /R:1 /W:1 /MAXAGE:90 | Out-Null
                Write-Log "  - Collected IIS web logs (last 90 days)"
            }
            
            # IIS configuration
            $iisConfigPath = "C:\Windows\System32\inetsrv\config"
            if (Test-Path $iisConfigPath) {
                robocopy $iisConfigPath "$outputDir\IIS\Config" /E /R:1 /W:1 | Out-Null
                Write-Log "  - Collected IIS configuration files"
            }
            
            Write-Host "Successfully collected IIS logs and configuration." -ForegroundColor Green
            Add-CollectionResult -ItemName "IIS Web Server Data" -Status Success
        } catch {
            Write-Log "Warning: Could not collect IIS artifacts: $_" -Level Warning
        }
    }
    
    # Hyper-V Virtual Machine configuration
    if ($serverRoles -like "*Hyper-V*") {
        Write-Verbose "  - Collecting Hyper-V configuration..."
        Write-Log "Hyper-V detected - collecting VM configuration files"
        
        try {
            # VM configuration files
            $hvConfigPath = "C:\ProgramData\Microsoft\Windows\Hyper-V"
            if (Test-Path $hvConfigPath) {
                robocopy $hvConfigPath "$outputDir\HyperV\Config" /E /R:1 /W:1 /XF *.vhdx *.vhd *.avhdx | Out-Null
                Write-Log "  - Collected Hyper-V VM configurations"
            }
            
            # Hyper-V event logs (already collected in EVTX, but note it)
            Write-Log "  - Hyper-V logs included in EVTX collection"
            Write-Host "Successfully collected Hyper-V configuration." -ForegroundColor Green
            Add-CollectionResult -ItemName "Hyper-V Configuration" -Status Success
        } catch {
            Write-Log "Warning: Could not collect Hyper-V artifacts: $_" -Level Warning
        }
    }
    
    # DFS Replication database
    if ($serverRoles -like "*DFS*") {
        Write-Verbose "  - Collecting DFS Replication artifacts..."
        Write-Log "DFS detected - collecting replication database"
        
        try {
            $dfsPath = "C:\System Volume Information\DFSR"
            if (Test-Path $dfsPath) {
                robocopy $dfsPath "$outputDir\DFS" /E /R:1 /W:1 /XF *.edb | Out-Null
                Write-Log "  - Collected DFS replication metadata"
                Write-Host "Successfully collected DFS artifacts." -ForegroundColor Green
                Add-CollectionResult -ItemName "DFS Replication Data" -Status Success
            }
        } catch {
            Write-Log "Warning: Could not collect DFS artifacts: $_" -Level Warning
        }
    }
    
    # Print Server logs
    if ($serverRoles -like "*Print*") {
        Write-Verbose "  - Collecting Print Server artifacts..."
        Write-Log "Print Server detected - collecting print logs"
        
        try {
            # Print queue and spool files metadata (not the actual spool files - too large)
            $printLogPath = "C:\Windows\System32\spool\PRINTERS"
            if (Test-Path $printLogPath) {
                Get-ChildItem -Path $printLogPath -Recurse -File -ErrorAction SilentlyContinue | 
                    Select-Object Name, FullName, Length, CreationTime, LastWriteTime | 
                    Export-Csv -Path "$outputDir\PrintServer_SpoolFiles.csv" -NoTypeInformation
                Write-Log "  - Collected print spool metadata"
                Write-Host "Successfully collected Print Server metadata." -ForegroundColor Green
                Add-CollectionResult -ItemName "Print Server Metadata" -Status Success
            }
        } catch {
            Write-Log "Warning: Could not collect Print Server artifacts: $_" -Level Warning
        }
    }

    Write-Verbose "Collecting user-specific artifacts for all profiles..."
    $userProfiles = Get-ChildItem -Path "$env:SystemDrive\Users" -Directory | Where-Object { $_.Name -notin @("Default", "Public", "All Users") }
    foreach ($user in $userProfiles) {
        $userName = $user.Name
        $userOutputDir = SafeJoinPath $outputDir "Users\$userName"
        New-Item -ItemType Directory -Path $userOutputDir -Force

        Write-Verbose "Collecting artifacts for user: $userName"

        # NTUSER.DAT
        $ntuserPath = Join-Path $user.FullName "NTUSER.DAT"
        if (Test-Path $ntuserPath) {
            robocopy $user.FullName $userOutputDir "NTUSER.DAT" /R:1 /W:1 | Out-Null
            Write-Verbose "  - Collected NTUSER.DAT"
        }

        # USRCLASS.DAT (contains COM+ object information)
        $usrclassPath = Join-Path $user.FullName "AppData\Local\Microsoft\Windows\UsrClass.dat"
        if (Test-Path $usrclassPath) {
            robocopy (Split-Path $usrclassPath) $userOutputDir (Split-Path $usrclassPath -Leaf) /R:1 /W:1 | Out-Null
            Write-Verbose "  - Collected UsrClass.dat"
        }

        # Browser History (Edge, Chrome, Firefox)
        $browserPaths = @{
            "Edge"     = "$($user.FullName)\AppData\Local\Microsoft\Edge\User Data\Default\History";
            "Chrome"   = "$($user.FullName)\AppData\Local\Google\Chrome\User Data\Default\History";
            "Firefox"  = "$($user.FullName)\AppData\Roaming\Mozilla\Firefox\Profiles\*.default*\places.sqlite";
        }
        foreach ($browser in $browserPaths.GetEnumerator()) {
            $historyPath = $null
            if ($browser.Key -eq "Firefox") {
                $historyPath = Get-ChildItem -Path $browser.Value -ErrorAction SilentlyContinue | Select-Object -First 1
            } else {
                $historyPath = $browser.Value
            }

            if ($historyPath -and (Test-Path $historyPath)) {
                $dest = Join-Path $userOutputDir "$($browser.Key)_History"
                robocopy (Split-Path $historyPath) $dest (Split-Path $historyPath -Leaf) /R:1 /W:1 | Out-Null
                Write-Verbose "  - Collected $($browser.Key) history"
            }
        }

        # LNK files and Jump Lists (use robocopy to handle long paths better)
        $recentPath = Join-Path $user.FullName "AppData\Roaming\Microsoft\Windows\Recent"
        if (Test-Path $recentPath) {
            try {
                $recentDest = Join-Path $userOutputDir "Recent"
                robocopy $recentPath $recentDest /E /R:1 /W:1 2>&1 | Out-Null
                Write-Verbose "  - Collected Recent Items (LNK files and Jump Lists)"
            } catch {
                Write-Verbose "  - Could not collect Recent Items: $_"
            }
        }

        # PowerShell History (PSReadline)
        Write-Verbose "  - Collecting PowerShell history..."
        $psHistoryPath = Join-Path $user.FullName "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
        if (Test-Path $psHistoryPath) {
            robocopy (Split-Path $psHistoryPath) $userOutputDir (Split-Path $psHistoryPath -Leaf) /R:1 /W:1 | Out-Null
            Write-Verbose "    - Collected PowerShell history"
        }

        # User Temp directory
        Write-Verbose "  - Collecting user Temp directory..."
        $userTempPath = Join-Path $user.FullName "AppData\Local\Temp"
        if (Test-Path $userTempPath) {
            robocopy $userTempPath "$userOutputDir\LocalTemp" /E /R:1 /W:1 | Out-Null
            Write-Verbose "    - Collected user Temp files"
        }

        # OneDrive sync metadata (if present)
        Write-Verbose "  - Collecting OneDrive metadata..."
        $oneDrivePath = Join-Path $user.FullName "AppData\Local\Microsoft\OneDrive\logs"
        if (Test-Path $oneDrivePath) {
            robocopy $oneDrivePath "$userOutputDir\OneDrive_Logs" /E /R:1 /W:1 | Out-Null
            Write-Verbose "    - Collected OneDrive logs"
        }

        # Windows Search index for user
        Write-Verbose "  - Collecting user Windows Search data..."
        $userSearchPath = Join-Path $user.FullName "AppData\Local\Microsoft\Windows Search"
        if (Test-Path $userSearchPath) {
            robocopy $userSearchPath "$userOutputDir\WindowsSearch" /E /R:1 /W:1 | Out-Null
            Write-Verbose "    - Collected Windows Search data"
        }
    }
    Write-Host "Successfully collected user-specific artifacts."
    Add-CollectionResult -ItemName "User-Specific Artifacts ($($userProfiles.Count) profiles)" -Status Success

    Write-Verbose "Listing root directory of C: drive"
    Get-ChildItem -Path "$env:SystemDrive\" | Out-File -FilePath "$outputDir\C_Dir.txt"
    Write-Host "Successfully listed C:\ root directory."

    Write-Verbose "Collecting network and connection artifacts..."
    
    # RDP Connection History (from registry - will be exported separately)
    Write-Verbose "  - Collecting RDP connection history..."
    $rdpRegPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Terminal Server Client\Default"
    if (Test-Path $rdpRegPath) {
        $rdpServers = Get-Item -Path $rdpRegPath | Select-Object -ExpandProperty Property
        if ($rdpServers) {
            $rdpServers | ForEach-Object {
                Add-Content -Path "$outputDir\RDP_ConnectionHistory.txt" -Value "$_"
            }
            Write-Verbose "    - Collected RDP connection history"
        }
    }

    # Network configuration (ipconfig, etc.)
    Write-Verbose "  - Collecting network configuration..."
    ipconfig /all | Out-File -FilePath "$outputDir\Network_IPConfig.txt"
    Get-NetAdapter | Out-File -FilePath "$outputDir\Network_Adapters.txt"
    Get-NetRoute | Out-File -FilePath "$outputDir\Network_Routes.txt"
    Write-Verbose "    - Collected network configuration"

    # WiFi Profiles
    Write-Verbose "  - Collecting WiFi profiles..."
    try {
        $wifiProfiles = netsh wlan show profile | Select-String "All User Profile" | ForEach-Object { $_.Line.Split(":")[1].Trim() }
        if ($wifiProfiles) {
            $wifiProfiles | Out-File -FilePath "$outputDir\WiFi_Profiles.txt"
            Write-Verbose "    - Collected WiFi profiles"
        }
    } catch {
        Write-Verbose "    - Could not collect WiFi profiles"
    }

    # USB Device History (from Registry)
    Write-Verbose "  - Collecting USB device history..."
    $usbRegPath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USBSTOR"
    if (Test-Path $usbRegPath) {
        Get-Item -Path $usbRegPath | Get-ChildItem | ForEach-Object {
            Get-ItemProperty -Path $_.PSPath | Select-Object PSChildName, FriendlyName | Out-File -FilePath "$outputDir\USB_DeviceHistory.txt" -Append
        }
        Write-Verbose "    - Collected USB device history"
    }

    Write-Host "Successfully collected network and connection artifacts."

    # ============================================================================
    # Chain of Custody: Hash Manifests and Code Signing
    # ============================================================================
    
    Write-Verbose "Generating integrity verification data..."
    Write-Log "Creating hash manifests and verifying code signatures for chain of custody"
    
    # Generate SHA256 Manifest using hashdeep
    Write-Verbose "Generating SHA256 hash manifest..."
    Write-Log "Generating SHA256 hash manifest for chain of custody"
    
    $hashdeepPath = Get-BinFile 'hashdeep.exe'
    if (Test-Path $hashdeepPath) {
        try {
            Write-Verbose "  - Running hashdeep.exe on collected files"
            # Run hashdeep and capture output, continuing even if some files fail due to long paths
            $hashdeepOutput = & $hashdeepPath -r -c sha256 "$outputDir" 2>&1
            
            # Filter out long path errors but keep valid hash data
            $validOutput = $hashdeepOutput | Where-Object { 
                $_ -notmatch "No such file or directory" -and 
                $_ -notmatch "Invalid argument" 
            }
            
            # Write the valid hashes to the manifest
            $validOutput | Out-File -FilePath "$outputDir\SHA256_MANIFEST.txt" -ErrorAction Stop
            
            # Check if we had path length issues
            $pathErrors = $hashdeepOutput | Where-Object { $_ -match "No such file or directory" }
            
            if ($pathErrors) {
                $errorCount = ($pathErrors | Measure-Object).Count
                Write-Log "Warning: SHA256 manifest generated with $errorCount file(s) skipped due to path length limitations" -Level Warning
                Write-Host "Successfully generated SHA256 manifest ($errorCount files skipped due to long paths)." -ForegroundColor Yellow
                Add-CollectionResult -ItemName "SHA256 Hash Manifest" -Status Warning -Message "$errorCount files skipped (path too long)"
                
                # Log the problematic paths for reference
                $pathErrors | Select-Object -First 5 | ForEach-Object {
                    Write-Log "  Skipped: $_" -Level Warning
                }
                if ($errorCount -gt 5) {
                    Write-Log "  ... and $($errorCount - 5) more files" -Level Warning
                }
            } else {
                Write-Host "Successfully generated SHA256 manifest."
                Write-Log "SHA256 manifest created: $outputDir\SHA256_MANIFEST.txt"
                Add-CollectionResult -ItemName "SHA256 Hash Manifest" -Status Success
            }
        } catch {
            Write-Log "Warning: Could not generate SHA256 manifest: $_" -Level Warning
            Write-Host "Warning: SHA256 manifest generation failed (continuing collection)"
            Add-CollectionResult -ItemName "SHA256 Hash Manifest" -Status Warning -Message "Generation failed: $_"
        }
    } else {
        Write-Log "Note: hashdeep.exe not found in bins/ - SHA256 manifest skipped" -Level Warning
        Write-Verbose "hashdeep.exe not available - skipping hash verification"
    }
    
    # Verify executable signatures using sigcheck
    Write-Verbose "Verifying executable signatures..."
    Write-Log "Verifying executable signatures in collected artifacts"
    
    $sigcheckPath = Get-BinFile 'sigcheck.exe'
    if (Test-Path $sigcheckPath) {
        try {
            Write-Verbose "  - Running sigcheck.exe on collected executables"
            
            # Find all .exe files in collected artifacts
            $exeFiles = Get-ChildItem -Path "$outputDir" -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue
            if ($exeFiles) {
                & $sigcheckPath -nobanner -accepteula $exeFiles.FullName | Out-File -FilePath "$outputDir\ExecutableSignatures.txt" -ErrorAction Stop
                Write-Host "Successfully verified executable signatures."
                Write-Log "Executable signatures verified: $outputDir\ExecutableSignatures.txt"
                Add-CollectionResult -ItemName "Executable Signature Verification" -Status Success
            } else {
                Write-Verbose "  - No .exe files found in collected artifacts"
                Write-Log "No executables found in collected artifacts - signature verification skipped"
                Add-CollectionResult -ItemName "Executable Signature Verification" -Status Warning -Message "No .exe files found"
            }
        } catch {
            Write-Log "Warning: Could not verify executable signatures: $_" -Level Warning
            Write-Host "Warning: Executable signature verification failed (continuing collection)"
            Add-CollectionResult -ItemName "Executable Signature Verification" -Status Warning -Message "Verification failed: $_"
        }
    } else {
        Write-Log "Note: sigcheck.exe not found in bins/ - signature verification skipped" -Level Warning
        Write-Verbose "sigcheck.exe not available - skipping signature verification"
    }
    
    # Extract strings from registry hives for analysis
    Write-Verbose "Extracting readable strings from critical files..."
    Write-Log "Extracting strings from registry hives for analysis"
    
    $stringsPath = Get-BinFile 'strings.exe'
    if (Test-Path $stringsPath) {
        try {
            Write-Verbose "  - Running strings.exe on registry hives"
            
            $registryDir = SafeJoinPath $outputDir "Registry"
            if (Test-Path $registryDir) {
                # Extract strings from NTUSER.DAT files
                $ntuserFiles = Get-ChildItem -Path $registryDir -Filter "NTUSER.DAT" -Recurse -ErrorAction SilentlyContinue
                foreach ($file in $ntuserFiles) {
                    $outputFile = "$($file.FullName)_Strings.txt"
                    & $stringsPath -nobanner $file.FullName | Out-File -FilePath $outputFile -ErrorAction SilentlyContinue
                    Write-Verbose "    - Extracted strings from $($file.Name)"
                }
                
                Write-Host "Successfully extracted strings from registry hives."
                Write-Log "String extraction completed from registry hives"
            } else {
                Write-Verbose "  - Registry directory not found"
            }
        } catch {
            Write-Log "Warning: Could not extract strings: $_" -Level Warning
            Write-Host "Warning: String extraction failed (continuing collection)"
        }
    } else {
        Write-Log "Note: strings.exe not found in bins/ - string extraction skipped" -Level Warning
        Write-Verbose "strings.exe not available - skipping string extraction"
    }
    
    Write-Log "Chain of custody verification completed"

    # ============================================================================
    # User Activity Analysis: Browser History and Application Usage
    # ============================================================================
    
    Write-Log "Extracting user activity artifacts: browser history, application execution, and resource usage"
    
    # Browser History Extraction
    function Export-ChromeHistory {
        param([string]$OutputPath)
        
        Write-Log "Extracting Chrome browsing history (URLs, downloads, searches)..."
        $chromeProfiles = @()
        $chromeHistoryData = @()
        
        try {
            $localAppData = $env:LOCALAPPDATA
            $chromeUserDataPath = Join-Path $localAppData "Google\Chrome\User Data"
            
            if (Test-Path $chromeUserDataPath) {
                # Find all Chrome profiles
                $profiles = Get-ChildItem -Path $chromeUserDataPath -Directory -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -like "Profile*" -or $_.Name -eq "Default" }
                
                foreach ($profile in $profiles) {
                    $historyDb = Join-Path $profile.FullName "History"
                    
                    if (Test-Path $historyDb) {
                        try {
                            # Read Chrome History SQLite database (copy first to avoid lock)
                            $tempHistory = Join-Path $env:TEMP "ChromeHistory_temp.db"
                            Copy-Item -Path $historyDb -Destination $tempHistory -Force -ErrorAction SilentlyContinue
                            
                            $profileName = $profile.Name
                            Write-Log "  - Found Chrome profile: $profileName"
                            
                            # Create human-readable export
                            $outputFile = SafeJoinPath $OutputPath "Chrome_History_${profileName}.txt"
                            "Chrome History Export - Profile: $profileName" | Set-Content $outputFile
                            "Export Date: $(Get-Date)" | Add-Content $outputFile
                            "Database Location: $historyDb" | Add-Content $outputFile
                            "" | Add-Content $outputFile
                            
                            # Also copy raw History database for analysis
                            $rawOutputFile = SafeJoinPath $OutputPath "Chrome_History_${profileName}.db"
                            Copy-Item -Path $historyDb -Destination $rawOutputFile -Force -ErrorAction SilentlyContinue
                            
                            Write-Verbose "  - Exported Chrome history for $profileName"
                        } catch {
                            Write-Log "  - Could not read Chrome History from $($profile.Name): $_" -Level Warning
                        }
                    }
                }
                
                if ($profiles.Count -gt 0) {
                    Write-Log "Chrome history extraction completed ($($profiles.Count) profiles found)"
                } else {
                    Write-Log "No Chrome profiles found" -Level Warning
                }
            } else {
                Write-Log "Chrome User Data directory not found" -Level Warning
            }
        } catch {
            Write-Log "Error extracting Chrome history: $_" -Level Warning
        }
    }
    
    # Firefox History Extraction
    function Export-FirefoxHistory {
        param([string]$OutputPath)
        
        Write-Log "Extracting Firefox browsing history (URLs, downloads, searches)..."
        
        try {
            $appData = $env:APPDATA
            $firefoxProfilePath = Join-Path $appData "Mozilla\Firefox\Profiles"
            
            if (Test-Path $firefoxProfilePath) {
                $profiles = Get-ChildItem -Path $firefoxProfilePath -Directory -ErrorAction SilentlyContinue
                
                foreach ($profile in $profiles) {
                    try {
                        $placesDb = Join-Path $profile.FullName "places.sqlite"
                        
                        if (Test-Path $placesDb) {
                            # Copy Firefox database for analysis
                            $outputFile = SafeJoinPath $OutputPath "Firefox_History_$($profile.BaseName).db"
                            Copy-Item -Path $placesDb -Destination $outputFile -Force -ErrorAction SilentlyContinue
                            
                            Write-Log "  - Extracted Firefox history from profile: $($profile.Name)"
                        }
                    } catch {
                        Write-Log "  - Could not read Firefox History from $($profile.Name): $_" -Level Warning
                    }
                }
            } else {
                Write-Log "Firefox profiles directory not found" -Level Warning
            }
        } catch {
            Write-Log "Error extracting Firefox history: $_" -Level Warning
        }
    }
    
    # Program Execution Timeline from Prefetch
    function Export-PrefetchAnalysis {
        param([string]$OutputPath)
        
        Write-Log "Analyzing prefetch files (program execution counts and timestamps)..."
        
        try {
            $prefetchPath = "C:\Windows\Prefetch"
            
            if (Test-Path $prefetchPath) {
                $prefetchFiles = Get-ChildItem -Path $prefetchPath -Filter "*.pf" -ErrorAction SilentlyContinue
                
                if ($prefetchFiles.Count -gt 0) {
                    $prefetchReport = SafeJoinPath $OutputPath "Prefetch_Analysis.txt"
                    
                    "PREFETCH FILE ANALYSIS" | Set-Content $prefetchReport
                    "Generated: $(Get-Date)" | Add-Content $prefetchReport
                    "Total Prefetch Files: $($prefetchFiles.Count)" | Add-Content $prefetchReport
                    "" | Add-Content $prefetchReport
                    
                    # List each prefetch file with metadata
                    foreach ($pf in $prefetchFiles) {
                        $name = $pf.BaseName -replace '-[0-9A-F]{8}$'  # Remove hash suffix
                        $modified = $pf.LastWriteTime
                        $size = $pf.Length
                        
                        "$name | Modified: $modified | Size: $size bytes" | Add-Content $prefetchReport
                    }
                    
                    # Also copy all prefetch files for external parsing
                    Write-Log "  - Copying prefetch files for external analysis"
                    $prefetchOutputDir = SafeJoinPath $OutputPath "Prefetch_Files"
                    New-Item -ItemType Directory -Path $prefetchOutputDir -Force -ErrorAction SilentlyContinue | Out-Null
                    Copy-Item -Path "$prefetchPath\*.pf" -Destination $prefetchOutputDir -Force -ErrorAction SilentlyContinue
                    
                    Write-Log "Prefetch analysis completed ($($prefetchFiles.Count) files found)"
                } else {
                    Write-Log "No prefetch files found" -Level Warning
                }
            } else {
                Write-Log "Prefetch directory not found" -Level Warning
            }
        } catch {
            Write-Log "Error analyzing prefetch files: $_" -Level Warning
        }
    }
    
    # System Resource Usage Monitor (SRUM) - Application Resource Consumption
    function Export-SRUMData {
        param([string]$OutputPath)
        
        Write-Log "Extracting SRUM data (CPU, network, and disk usage per application)..."
        
        try {
            $srumDbPath = "C:\Windows\System32\sru\SRUDB.dat"
            
            if (Test-Path $srumDbPath) {
                try {
                    # SRUM database is locked, try to copy with RawCopy if available
                    $rawCopyPath = Get-BinFile 'RawCopy.exe'
                    
                    if (Test-Path $rawCopyPath) {
                        Write-Log "  - Attempting to copy SRUM database with RawCopy.exe"
                        $currentDir = Get-Location
                        Start-Process -FilePath $rawCopyPath -ArgumentList "/FileNamePath:$srumDbPath" -Wait -NoNewWindow -WorkingDirectory $currentDir
                        if (Test-Path (Join-Path $currentDir 'SRUDB.dat')) {
                            Move-Item -Path (Join-Path $currentDir 'SRUDB.dat') -Destination (SafeJoinPath $OutputPath 'SRUM_Database.dat') -Force
                        }
                        Write-Log "  - SRUM database copied successfully"
                    } else {
                        # Try direct copy (may fail if locked)
                        $outputSRUM = SafeJoinPath $OutputPath "SRUM_Database.dat"
                        Copy-Item -Path $srumDbPath -Destination $outputSRUM -Force -ErrorAction SilentlyContinue
                        Write-Log "  - SRUM database copied (may be partial if locked)"
                    }
                } catch {
                    Write-Log "  - Could not copy SRUM database (locked by system): $_" -Level Warning
                }
            } else {
                Write-Log "SRUM database not found at expected location" -Level Warning
            }
        } catch {
            Write-Log "Error extracting SRUM data: $_" -Level Warning
        }
    }
    
    # Application Compatibility Cache (Amcache) - Execution History
    function Export-AmcacheData {
        param([string]$OutputPath)
        
        Write-Log "Extracting Amcache (program SHA1 hashes and first execution times)..."
        
        try {
            $amcachePath = "C:\Windows\appcompat\Programs\Amcache.hve"
            
            if (Test-Path $amcachePath) {
                try {
                    # Amcache is also locked, use RawCopy if available
                    $rawCopyPath = Get-BinFile 'RawCopy.exe'
                    
                    if (Test-Path $rawCopyPath) {
                        Write-Log "  - Attempting to copy Amcache with RawCopy.exe"
                        $currentDir = Get-Location
                        Start-Process -FilePath $rawCopyPath -ArgumentList "/FileNamePath:$amcachePath" -Wait -NoNewWindow -WorkingDirectory $currentDir
                        if (Test-Path (Join-Path $currentDir 'Amcache.hve')) {
                            Move-Item -Path (Join-Path $currentDir 'Amcache.hve') -Destination (SafeJoinPath $OutputPath 'Amcache.hve') -Force
                        }
                        Write-Log "  - Amcache copied successfully"
                    } else {
                        # Try direct copy
                        $outputAmcache = SafeJoinPath $OutputPath "Amcache.hve"
                        Copy-Item -Path $amcachePath -Destination $outputAmcache -Force -ErrorAction SilentlyContinue
                        Write-Log "  - Amcache copied (may be partial if locked)"
                    }
                } catch {
                    Write-Log "  - Could not copy Amcache (locked by system): $_" -Level Warning
                }
            } else {
                Write-Log "Amcache not found at expected location" -Level Warning
            }
        } catch {
            Write-Log "Error extracting Amcache: $_" -Level Warning
        }
    }
    
    # Scheduled Task Analysis - Persistence Mechanisms
    function Export-SuspiciousScheduledTasks {
        param([string]$OutputPath)
        
        Write-Log "Analyzing scheduled tasks (detecting suspicious commands and patterns)..."
        
        try {
            $tasksPath = "C:\Windows\System32\Tasks"
            
            if (Test-Path $tasksPath) {
                $suspiciousReport = SafeJoinPath $OutputPath "Suspicious_Scheduled_Tasks.txt"
                $taskCount = 0
                $suspiciousCount = 0
                
                "SUSPICIOUS SCHEDULED TASK ANALYSIS" | Set-Content $suspiciousReport
                "Generated: $(Get-Date)" | Add-Content $suspiciousReport
                "" | Add-Content $suspiciousReport
                "" | Add-Content $suspiciousReport
                
                # Keywords that indicate potentially malicious scheduled tasks
                $suspiciousPatterns = @(
                    "powershell",
                    "cmd.exe",
                    "cscript",
                    "wscript",
                    "mshta",
                    "regsvr32",
                    "rundll32",
                    "certutil",
                    "bitsadmin",
                    "curl",
                    "wget",
                    "c:\\temp",
                    "c:\\windows\\temp",
                    "c:\\windows\\system32\config\systemprofile"
                )
                
                $taskXmlFiles = Get-ChildItem -Path $tasksPath -Filter "*.xml" -Recurse -ErrorAction SilentlyContinue
                
                foreach ($taskFile in $taskXmlFiles) {
                    $taskCount++
                    
                    try {
                        $taskContent = Get-Content -Path $taskFile.FullName -Raw -ErrorAction SilentlyContinue
                        
                        # Check for suspicious patterns
                        $isSuspicious = $false
                        foreach ($pattern in $suspiciousPatterns) {
                            if ($taskContent -match [regex]::Escape($pattern)) {
                                $isSuspicious = $true
                                break
                            }
                        }
                        
                        if ($isSuspicious) {
                            $suspiciousCount++
                            "" | Add-Content $suspiciousReport
                            "SUSPICIOUS TASK FOUND:" | Add-Content $suspiciousReport
                            "Name: $($taskFile.Name)" | Add-Content $suspiciousReport
                            "Path: $($taskFile.FullName)" | Add-Content $suspiciousReport
                            "Modified: $($taskFile.LastWriteTime)" | Add-Content $suspiciousReport
                            "" | Add-Content $suspiciousReport
                        }
                    } catch {
                        # Continue on parse errors
                    }
                }
                
                "" | Add-Content $suspiciousReport
                "SUMMARY" | Add-Content $suspiciousReport
                "Total Tasks Analyzed: $taskCount" | Add-Content $suspiciousReport
                "Suspicious Tasks Found: $suspiciousCount" | Add-Content $suspiciousReport
                
                Write-Log "Scheduled task analysis completed ($suspiciousCount suspicious tasks found out of $taskCount)"
            } else {
                Write-Log "Scheduled tasks directory not found" -Level Warning
            }
        } catch {
            Write-Log "Error analyzing scheduled tasks: $_" -Level Warning
        }
    }
    
    # Extended Browser Artifacts - Cache and Cookies
    function Export-BrowserArtifacts {
        param([string]$OutputPath)
        
        Write-Log "Collecting Edge and Internet Explorer cache artifacts..."
        
        try {
            $localAppData = $env:LOCALAPPDATA
            $browsers = @(
                @{ Name = "Edge"; Path = "$localAppData\Microsoft\Edge\User Data" },
                @{ Name = "InternetExplorer"; Path = "$localAppData\Microsoft\Windows\INetCache" }
            )
            
            foreach ($browser in $browsers) {
                if (Test-Path $browser.Path) {
                    try {
                        $browserOutputDir = SafeJoinPath $OutputPath "BrowserArtifacts_$($browser.Name)"
                        New-Item -ItemType Directory -Path $browserOutputDir -Force -ErrorAction SilentlyContinue | Out-Null
                        
                        # Copy browser cache, cookies, and related files
                        robocopy $browser.Path $browserOutputDir /S /R:1 /W:1 /NP /LOG:NUL /NDCOPY:DA | Out-Null
                        
                        Write-Log "  - Collected $($browser.Name) artifacts"
                    } catch {
                        Write-Log "  - Could not collect $($browser.Name) artifacts: $_" -Level Warning
                    }
                }
            }
        } catch {
            Write-Log "Error collecting browser artifacts: $_" -Level Warning
        }
    }
    
    # Execute user activity and application usage analysis
    try {
        # Create analysis output directory
        $analysisOutputDir = SafeJoinPath $outputDir "UserActivity_Analysis"
        New-Item -ItemType Directory -Path $analysisOutputDir -Force -ErrorAction SilentlyContinue | Out-Null
        
        # Extract all user activity artifacts
        Export-ChromeHistory -OutputPath $analysisOutputDir
        Export-FirefoxHistory -OutputPath $analysisOutputDir
        Export-PrefetchAnalysis -OutputPath $analysisOutputDir
        Export-SRUMData -OutputPath $analysisOutputDir
        Export-AmcacheData -OutputPath $analysisOutputDir
        Export-SuspiciousScheduledTasks -OutputPath $analysisOutputDir
        Export-BrowserArtifacts -OutputPath $analysisOutputDir
        
        Write-Log "User activity and application analysis completed successfully"
    } catch {
        Write-Log "User activity analysis encountered errors (collection may be partial): $_" -Level Warning
    }

} catch {
    # Check if this is a MAX_PATH error - if so, continue and warn instead of failing
    if ($_.Exception.Message -like "*too long*" -or $_.Exception.Message -like "*MAX_PATH*" -or $_.Exception.Message -like "*260*") {
        Write-Log "Warning: Path length exceeded MAX_PATH limit - skipping this artifact and continuing collection" -Level Warning
        Write-Log "Error details: $_" -Level Warning
        # Don't exit - continue collection
    } else {
        # Real error - log and exit
        Write-Log "============================================================================" -Level Error
        Write-Log "CRITICAL ERROR OCCURRED" -Level Error
        Write-Log "============================================================================" -Level Error
        Write-Log "Error Message: $_" -Level Error
        Write-Log "Error Details: $($_.Exception.Message)" -Level Error
        Write-Log "Script Line: $($_.InvocationInfo.Line)" -Level Error
        Write-Log "============================================================================" -Level Error
        
        Write-Host ""
        Write-Host "============================================================================" -ForegroundColor Red
        Write-Host "COLLECTION FAILED WITH ERROR" -ForegroundColor Red
        Write-Host "============================================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "What to do:" -ForegroundColor Yellow
        Write-Host "1. Read the log file: logs\forensic_collection_$computerName*.txt"
        Write-Host "2. Note the error message above"
        Write-Host "3. Send the log file to the analyst who provided this tool"
        Write-Host ""
        Write-Host "If collection was partially successful:" -ForegroundColor Yellow
        Write-Host "- A 'collected_files' folder may still contain some data"
        Write-Host "- Return what was collected along with the log file"
        Write-Host ""
        Write-Host "============================================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Press any key to close this window..."
        Read-Host
        
        exit 1
    }
}

# ============================================================================
# Successful Completion - Generate Summary Report
# ============================================================================

$collectionEndTime = Get-Date
$startTime = [datetime]::ParseExact($timestamp, 'yyyyMMdd_HHmmss', $null)
$duration = $collectionEndTime - $startTime

Write-Log "============================================================================"
Write-Log "Collection Process Completed Successfully"
Write-Log "============================================================================"
Write-Log "Output Location: $outputDir"
Write-Log "Log File: $logFile"
Write-Log ""
Write-Log "Collection Summary:"
Write-Log "  Total Items Attempted: $($script:collectionStats.TotalItems)"
Write-Log "  Successful: $($script:collectionStats.SuccessfulItems)"
Write-Log "  Warnings: $($script:collectionStats.Warnings)"
Write-Log "  Errors: $($script:collectionStats.Errors)"
Write-Log "  Duration: $($duration.ToString('hh\:mm\:ss'))"

# ============================================================================
# Optional Compression
# ============================================================================

$zipFile = ""
if (-not $NoZip) {
    Write-Verbose "Compressing collected files..."
    Write-Log "Compressing collected files for transport (this may take several minutes for large collections)"
    
    try {
        $zipFile = Join-Path $outputRoot "collected_files.zip"
        if (Test-Path $zipFile) {
            Remove-Item $zipFile -Force
        }
        
        # Sanitize file timestamps to avoid ZIP format limitations (must be between 1980-2107)
        $minDate = [DateTime]::Parse("1980-01-01")
        $maxDate = [DateTime]::Parse("2107-12-31")
        Get-ChildItem -Path $outputDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                if ($_.LastWriteTime -lt $minDate) {
                    $_.LastWriteTime = $minDate
                } elseif ($_.LastWriteTime -gt $maxDate) {
                    $_.LastWriteTime = $maxDate
                }
            } catch {
                # Ignore timestamp sanitization errors
            }
        }
        
        # Try Compress-Archive first (PowerShell 5.0+)
        if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
            Write-Verbose "Using Compress-Archive (PowerShell 5.0+)"
            Compress-Archive -Path "$outputDir\*" -DestinationPath $zipFile -ErrorAction Stop
        } else {
            # Fallback: Use Windows shell compression (older PowerShell versions)
            Write-Verbose "Using Windows shell compression (Compress-Archive not available)"
            Write-Log "Note: Using shell compression (Compress-Archive not available in this PowerShell version)"
            
            # Create shell COM object for compression
            $shell = New-Object -com shell.application
            $zip = $shell.NameSpace($zipFile)
            
            if ($zip -eq $null) {
                # Create empty zip file first
                "" | Set-Content $zipFile
                $shell = New-Object -com shell.application
                $zip = $shell.NameSpace($zipFile)
            }
            
            # Add files to zip
            $items = Get-ChildItem -Path $outputDir
            foreach ($item in $items) {
                $zip.CopyHere($item.FullName)
                # Wait for copy to complete (shell compression is asynchronous)
                Start-Sleep -Milliseconds 100
            }
        }
        
        Write-Host "Successfully compressed files to $zipFile" -ForegroundColor Green
        Write-Log "Files compressed to: $zipFile"
    } catch {
        Write-Log "Warning: Could not compress collected files: $_" -Level Warning
        Write-Host "Warning: Compression failed - collected files remain uncompressed" -ForegroundColor Yellow
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $zipFile = "(Compression failed - files remain uncompressed)"
    }
} else {
    Write-Verbose "Skipping compression (NoZip parameter specified)"
    Write-Log "Compression skipped per user request (-NoZip parameter)"
    $zipFile = "(Compression skipped)"
}

# ============================================================================
# Transfer to Analyst Workstation
# ============================================================================

if ($AnalystWorkstation) {
    Write-Log "============================================================================"
    Write-Log "Transferring collected files to analyst workstation"
    Write-Log "============================================================================"
    
    try {
        # Normalize analyst workstation (remove backslashes if provided, trim whitespace)
        $targetHost = $AnalystWorkstation.Trim() -replace '\\\\', '' -replace '\\', ''
        
        # Validate target host is not empty after normalization
        if (-not $targetHost) {
            throw "AnalystWorkstation parameter is empty or invalid"
        }
        
        # Handle localhost specially - use local path without UNC
        if ($targetHost -eq 'localhost' -or $targetHost -eq '127.0.0.1' -or $targetHost -eq $env:COMPUTERNAME) {
            $destinationPath = "C:\Temp\Investigations\$computerName\$timestamp"
            $isLocalhost = $true
            Write-Log "Using localhost transfer mode (local filesystem copy)"
        } else {
            $destinationPath = "\\$targetHost\c`$\Temp\Investigations\$computerName\$timestamp"
            $isLocalhost = $false
            Write-Log "Using remote transfer mode (UNC path to $targetHost)"
        }
        
        Write-Log "Target destination: $destinationPath"
        Write-Host ""
        Write-Host "Transferring files to analyst workstation..." -ForegroundColor Cyan
        Write-Host "  Source: $outputRoot" -ForegroundColor White
        Write-Host "  Destination: $destinationPath" -ForegroundColor White
        
        # Determine what to transfer based on zip file status
        $transferZipOnly = $false
        $zipFilePath = Join-Path $outputRoot "collected_files.zip"
        if ($zipFile -and $zipFile -ne "(Compression skipped)" -and $zipFile -ne "(Compression failed - files remain uncompressed)" -and (Test-Path $zipFilePath)) {
            $transferZipOnly = $true
            Write-Host "  Transfer mode: ZIP file only (compression successful)" -ForegroundColor Green
            Write-Log "Transferring compressed ZIP file only"
        } else {
            Write-Host "  Transfer mode: Full directory (no zip available)" -ForegroundColor Yellow
            Write-Log "Transferring full directory (zip not available)"
        }
        Write-Host ""
        
        # Test network connectivity if not localhost
        if (-not $isLocalhost) {
            Write-Log "Testing connectivity to $targetHost..."
            $pingResult = Test-Connection -ComputerName $targetHost -Count 1 -Quiet -ErrorAction SilentlyContinue
            
            if (-not $pingResult) {
                Write-Log "Warning: Cannot ping $targetHost - attempting transfer anyway" -Level Warning
                Write-Host "Warning: Cannot ping $targetHost - attempting transfer anyway..." -ForegroundColor Yellow
            } else {
                Write-Log "Successfully connected to $targetHost"
            }
        } else {
            Write-Log "Localhost detected - skipping network connectivity test"
        }
        
        # Create destination directory structure
        # For localhost, ensure C:\Temp exists first
        if ($isLocalhost) {
            $tempRoot = "C:\Temp"
            if (-not (Test-Path $tempRoot)) {
                Write-Log "Creating C:\Temp directory..."
                New-Item -ItemType Directory -Path $tempRoot -Force -ErrorAction Stop | Out-Null
            }
        }
        
        $destParent = Split-Path $destinationPath -Parent
        if (-not (Test-Path $destParent)) {
            Write-Log "Creating destination directory structure: $destParent"
            New-Item -ItemType Directory -Path $destParent -Force -ErrorAction Stop | Out-Null
        } else {
            Write-Log "Destination parent directory already exists: $destParent"
        }
        
        # Build robocopy log path
        $robocopyLog = Join-Path $destinationPath "ROBOCopyLog.txt"
        
        # Execute robocopy - copy zip only or full directory
        Write-Log "Starting robocopy transfer..."
        
        # Build robocopy command as a string for better argument handling
        # (PowerShell array expansion doesn't handle switches with colons well)
        
        if ($transferZipOnly) {
            # Copy only the zip file, log file, and summary
            $robocopyCmd = "robocopy `"$outputRoot`" `"$destinationPath`" collected_files.zip `"forensic_collection_${computerName}_${timestamp}.txt`" COLLECTION_SUMMARY.txt /DCOPY:T /COPY:DAT /R:3 /W:5 /LOG+:`"$robocopyLog`" /TEE /NP"
        } else {
            # Copy entire directory
            $robocopyCmd = "robocopy `"$outputRoot`" `"$destinationPath`" /E /DCOPY:T /COPY:DAT /R:3 /W:5 /LOG+:`"$robocopyLog`" /TEE /NP"
        }
        
        Write-Log "Robocopy command: $robocopyCmd"
        
        # Execute robocopy using Invoke-Expression for proper argument parsing
        $robocopyResult = Invoke-Expression $robocopyCmd 2>&1
        $robocopyExitCode = $LASTEXITCODE
        
        # Robocopy exit codes: 0-7 are success, 8+ are errors
        # 0 = No files copied, 1 = Files copied successfully, 2 = Extra files/dirs detected, etc.
        if ($robocopyExitCode -lt 8) {
            Write-Host ""
            if ($transferZipOnly) {
                Write-Host "Successfully transferred ZIP archive to analyst workstation!" -ForegroundColor Green
                Write-Log "Robocopy completed successfully - ZIP file transferred (exit code: $robocopyExitCode)"
            } else {
                Write-Host "Successfully transferred full collection to analyst workstation!" -ForegroundColor Green
                Write-Log "Robocopy completed successfully - full directory transferred (exit code: $robocopyExitCode)"
            }
            Write-Log "Files transferred to: $destinationPath"
            Write-Log "Transfer log: $robocopyLog"
            
            # Store destination for summary report
            if ($transferZipOnly) {
                $script:analystDestination = "$destinationPath (ZIP archive only)"
            } else {
                $script:analystDestination = "$destinationPath (full collection)"
            }
        } else {
            Write-Host ""
            Write-Host "Warning: Robocopy completed with errors (exit code: $robocopyExitCode)" -ForegroundColor Yellow
            Write-Host "Some files may not have been transferred. Check the log file." -ForegroundColor Yellow
            Write-Log "Warning: Robocopy exit code $robocopyExitCode indicates errors" -Level Warning
            Write-Log "Transfer log: $robocopyLog"
            
            $script:analystDestination = "$destinationPath (transfer had errors - see log)"
        }
        
    } catch {
        Write-Log "Error during file transfer: $_" -Level Error
        Write-Host ""
        Write-Host "Error: Failed to transfer files to analyst workstation" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host "  Files remain in local collection folder" -ForegroundColor Yellow
        Write-Host ""
        
        $script:analystDestination = "(Transfer failed: $_)"
    }
} else {
    $script:analystDestination = $null
}

# Generate detailed summary
$summaryFile = Join-Path $outputRoot "COLLECTION_SUMMARY.txt"
@"
============================================================================
HOST EVIDENCE RUNNER (HER) - COLLECTION SUMMARY
============================================================================

Collection Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer Name: $computerName
User Account: $env:USERNAME
Duration: $($duration.ToString('hh\:mm\:ss'))

============================================================================
COLLECTION STATISTICS
============================================================================

Total Items Attempted: $($script:collectionStats.TotalItems)
Successful Collections: $($script:collectionStats.SuccessfulItems)
Warnings: $($script:collectionStats.Warnings)
Errors: $($script:collectionStats.Errors)

Success Rate: $([math]::Round(($script:collectionStats.SuccessfulItems / $script:collectionStats.TotalItems) * 100, 1))%

============================================================================
COLLECTION DETAILS
============================================================================

"@ | Set-Content $summaryFile

foreach ($detail in $script:collectionStats.CollectionDetails) {
    $statusSymbol = switch ($detail.Status) {
        'Success' { '[✓]' }
        'Warning' { '[!]' }
        'Error' { '[✗]' }
    }
    
    $line = "$statusSymbol [$($detail.Timestamp)] $($detail.Item)"
    if ($detail.Message) {
        $line += " - $($detail.Message)"
    }
    Add-Content -Path $summaryFile -Value $line
}

@"

============================================================================
OUTPUT LOCATIONS
============================================================================

Collected Files: $outputDir
"@ | Add-Content $summaryFile

if ($zipFile -and $zipFile -ne "(Compression skipped)" -and $zipFile -ne "(Compression failed - files remain uncompressed)") {
    "Compressed Archive: $zipFile" | Add-Content $summaryFile
} else {
    "Compressed Archive: $zipFile" | Add-Content $summaryFile
}

if ($script:analystDestination) {
    "Analyst Workstation Copy: $($script:analystDestination)" | Add-Content $summaryFile
}

@"
Log File: $logFile
This Summary: $summaryFile

============================================================================
SYSTEM INFORMATION
============================================================================

Hypervisor: $hypervisor
Server Roles: $($serverRoles -join ', ')
PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $([System.Environment]::OSVersion)

============================================================================
NEXT STEPS
============================================================================

1. Disconnect USB from server
2. Copy the entire output folder to secure location
3. Provide collected data and log file to analyst
4. Contact analyst to confirm receipt
5. Securely delete local copies after confirmation

============================================================================
"@ | Add-Content $summaryFile

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "COLLECTION COMPLETE!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Collection Statistics:" -ForegroundColor Cyan
Write-Host "  Total Items: $($script:collectionStats.TotalItems)" -ForegroundColor White
Write-Host "  Successful: $($script:collectionStats.SuccessfulItems)" -ForegroundColor Green
Write-Host "  Warnings: $($script:collectionStats.Warnings)" -ForegroundColor Yellow
Write-Host "  Errors: $($script:collectionStats.Errors)" -ForegroundColor $(if ($script:collectionStats.Errors -gt 0) { 'Red' } else { 'White' })
Write-Host "  Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
Write-Host ""

if ($script:collectionStats.Warnings -gt 0 -or $script:collectionStats.Errors -gt 0) {
    Write-Host "⚠ Some items had issues - see summary report for details" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Output Locations:" -ForegroundColor Cyan
Write-Host "  Collected Files: $outputDir" -ForegroundColor White
if ($zipFile -and $zipFile -ne "(Compression skipped)" -and $zipFile -ne "(Compression failed - files remain uncompressed)") {
    Write-Host "  Compressed Archive: $zipFile" -ForegroundColor White
} elseif ($zipFile) {
    Write-Host "  Compressed Archive: $zipFile" -ForegroundColor Yellow
}
if ($script:analystDestination) {
    if ($script:analystDestination -like "*(Transfer failed*" -or $script:analystDestination -like "*had errors*") {
        Write-Host "  Analyst Workstation: $($script:analystDestination)" -ForegroundColor Yellow
    } else {
        Write-Host "  Analyst Workstation: $($script:analystDestination)" -ForegroundColor Green
    }
}
Write-Host "  Summary Report: $summaryFile" -ForegroundColor White
Write-Host "  Log File: $logFile" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the summary report above for any warnings or errors"
Write-Host "2. Disconnect USB from server"
Write-Host "3. Copy entire output folder to secure location"
Write-Host "4. Provide to analyst with summary report"
Write-Host "5. Securely delete local copies after confirmation"
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
