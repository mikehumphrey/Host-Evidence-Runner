#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$RootPath
)

$ErrorActionPreference = 'Stop'

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
Write-Log "============================================================================"
Write-Log "Host Evidence Runner (HER) - Collection Started"
Write-Log "Derived from the archived Cado-Batch project; independently maintained"
Write-Log "============================================================================"
Write-Log "Computer: $computerName"
Write-Log "User: $env:USERNAME"
Write-Log "Script Location: $scriptPath"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Log "OS Version: $([System.Environment]::OSVersion)"

# Safe path join to force string casting and avoid array-to-string binding issues
function SafeJoinPath {
    param(
        [Parameter(Mandatory)]$Parent,
        [Parameter(Mandatory)]$Child
    )
    Write-Verbose "DEBUG SafeJoinPath: Parent raw type=$($Parent.GetType().FullName)"
    Write-Verbose "DEBUG SafeJoinPath: Child raw type=$($Child.GetType().FullName)"
    
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
    
    Write-Verbose "DEBUG SafeJoinPath: Parent='$parentStr', Child='$childStr'"
    try {
        $result = Join-Path $parentStr $childStr
        Write-Verbose "DEBUG SafeJoinPath: result='$result'"
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

Write-Log "DEBUG: scriptPath type: $($scriptPath.GetType().FullName), value: $scriptPath"
$parentPath = Split-Path $scriptPath -Parent
Write-Log "DEBUG: parentPath type: $($parentPath.GetType().FullName), value: $parentPath"

Write-Log "DEBUG: About to call SafeJoinPath with scriptPath and 'bins'"
$bin1 = SafeJoinPath $scriptPath 'bins'
Write-Log "DEBUG: bin1 = $bin1"

Write-Log "DEBUG: About to call SafeJoinPath with parentPath and 'tools\\bins'"
$bin2 = SafeJoinPath $parentPath 'tools\bins'
Write-Log "DEBUG: bin2 = $bin2"

Write-Log "DEBUG: About to call SafeJoinPath with parentPath and 'bins'"
$bin3 = SafeJoinPath $parentPath 'bins'
Write-Log "DEBUG: bin3 = $bin3"

$binCandidates = @($bin1, $bin2, $bin3)

Write-Log "DEBUG: binCandidates count: $($binCandidates.Count)"
for ($i = 0; $i -lt $binCandidates.Count; $i++) {
    Write-Log "DEBUG: binCandidates[$i] type: $($binCandidates[$i].GetType().FullName), value: $($binCandidates[$i])"
}

$binPath = Resolve-BinPath -Candidates $binCandidates

function Get-BinFile {
    param([Parameter(Mandatory)][string]$Name)
    Write-Verbose "DEBUG Get-BinFile: binPath type=$($binPath.GetType().FullName), Name type=$($Name.GetType().FullName)"
    Write-Verbose "DEBUG Get-BinFile: binPath='$binPath', Name='$Name'"
    try {
        # Check if a 64-bit version exists (e.g., hashdeep64.exe instead of hashdeep.exe)
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Name)
        $extension = [System.IO.Path]::GetExtension($Name)
        $name64 = "${baseName}64${extension}"
        $path64 = Join-Path ([string]$binPath) ([string]$name64)
        
        if (Test-Path $path64) {
            Write-Verbose "DEBUG Get-BinFile: Using 64-bit version: $path64"
            return $path64
        }
        
        # Fall back to 32-bit version
        $result = Join-Path ([string]$binPath) ([string]$Name)
        Write-Verbose "DEBUG Get-BinFile: result='$result'"
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
    Start-Process -FilePath (Get-BinFile 'RawCopy.exe') -ArgumentList "/FileNamePath:C:0" -Wait -NoNewWindow
    Start-Process -FilePath (Get-BinFile 'RawCopy.exe') -ArgumentList "/FileNamePath:c:\$LogFile" -Wait -NoNewWindow

    Move-Item -Path (Get-BinFile '$MFT') -Destination "$outputDir\MFT_C.bin" -Force -ErrorAction SilentlyContinue
    Move-Item -Path (Get-BinFile '$LogFile') -Destination "$outputDir\LogFile_C.bin" -Force -ErrorAction SilentlyContinue
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

    Write-Verbose "Collecting additional system artifacts..."
    
    # Collect Prefetch files
    $prefetchDir = Join-Path $env:SystemRoot "Prefetch"
    if (Test-Path $prefetchDir) {
        Write-Verbose "Collecting prefetch files from $prefetchDir"
        try {
            Copy-Item -Path "$prefetchDir\*.pf" -Destination "$outputDir\Prefetch\" -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully collected prefetch files."
            Write-Log "Successfully collected prefetch files"
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
            Write-Log "Warning: Could not collect Amcache.hve (file may be locked): $_" -Level Warning
            Write-Host "Warning: Amcache.hve collection failed (file locked) - continuing..." -ForegroundColor Yellow
            Add-CollectionResult -ItemName "Amcache.hve" -Status Warning -Message "File locked: $_"
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
    Start-Process -FilePath (Get-BinFile 'RawCopy.exe') -ArgumentList "/FileNamePath:C:\$Extend\$UsnJrnl" -Wait -NoNewWindow
    if (Test-Path (Get-BinFile '$UsnJrnl')) {
        Move-Item -Path (Get-BinFile '$UsnJrnl') -Destination "$outputDir\UsnJrnl_C.bin" -Force
        Write-Host "Successfully collected USN Journal."
    } else {
        Write-Warning "Could not find the collected USN Journal. RawCopy may have failed."
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

        # LNK files and Jump Lists
        $recentPath = Join-Path $user.FullName "AppData\Roaming\Microsoft\Windows\Recent"
        if (Test-Path $recentPath) {
            Copy-Item -Path "$recentPath\*" -Destination "$userOutputDir\RecentItems" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Verbose "  - Collected Recent Items (LNK files and Jump Lists)"
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
    # PHASE 1: Hash Verification and Signature Analysis
    # ============================================================================
    
    Write-Verbose "Starting Phase 1 tool integration..."
    Write-Log "Starting Phase 1: Hash verification and signature analysis"
    
    # Generate SHA256 Manifest using hashdeep
    Write-Verbose "Generating SHA256 hash manifest..."
    Write-Log "Generating SHA256 hash manifest for chain of custody"
    
    $hashdeepPath = Get-BinFile 'hashdeep.exe'
    if (Test-Path $hashdeepPath) {
        try {
            Write-Verbose "  - Running hashdeep.exe on collected files"
            & $hashdeepPath -r -c sha256 "$outputDir" | Out-File -FilePath "$outputDir\SHA256_MANIFEST.txt" -ErrorAction Stop
            Write-Host "Successfully generated SHA256 manifest."
            Write-Log "SHA256 manifest created: $outputDir\SHA256_MANIFEST.txt"
            Add-CollectionResult -ItemName "SHA256 Hash Manifest" -Status Success
        } catch {
            Write-Log "Warning: Could not generate SHA256 manifest: $_" -Level Warning
            Write-Host "Warning: SHA256 manifest generation failed (continuing collection)"
            Add-CollectionResult -ItemName "SHA256 Hash Manifest" -Status Warning -Message "Generation failed: $_"
        }
    } else {
        Write-Log "Note: hashdeep.exe not found in bins/ - SHA256 manifest skipped (Phase 1 tool not installed)" -Level Warning
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
        Write-Log "Note: sigcheck.exe not found in bins/ - signature verification skipped (Phase 1 tool not installed)" -Level Warning
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
        Write-Log "Note: strings.exe not found in bins/ - string extraction skipped (Phase 1 tool not installed)" -Level Warning
        Write-Verbose "strings.exe not available - skipping string extraction"
    }
    
    Write-Log "Phase 1 tools integration completed"

    # ============================================================================
    # PHASE 2: Advanced Artifact Parsing and Enhanced Collection
    # ============================================================================
    
    Write-Log "Starting Phase 2: Advanced artifact parsing and enhanced browser collection"
    
    # Function to parse Chrome history
    function Export-ChromeHistory {
        param([string]$OutputPath)
        
        Write-Log "Extracting Chrome browsing history..."
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
    
    # Function to parse Firefox history
    function Export-FirefoxHistory {
        param([string]$OutputPath)
        
        Write-Log "Extracting Firefox browsing history..."
        
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
    
    # Function to parse prefetch files to readable format
    function Export-PrefetchAnalysis {
        param([string]$OutputPath)
        
        Write-Log "Analyzing prefetch files for program execution timeline..."
        
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
    
    # Function to extract SRUM database
    function Export-SRUMData {
        param([string]$OutputPath)
        
        Write-Log "Extracting System Resource Usage Monitor (SRUM) data..."
        
        try {
            $srumDbPath = "C:\Windows\System32\sru\SRUDB.dat"
            
            if (Test-Path $srumDbPath) {
                try {
                    # SRUM database is locked, try to copy with RawCopy if available
                    $rawCopyPath = Get-BinFile 'RawCopy.exe'
                    
                    if (Test-Path $rawCopyPath) {
                        Write-Log "  - Attempting to copy SRUM database with RawCopy.exe"
                        $outputSRUM = SafeJoinPath $OutputPath "SRUM_Database.dat"
                        & $rawCopyPath /FileNamePath:$srumDbPath /OutputPath:$OutputPath | Out-Null
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
    
    # Function to extract Amcache for program execution history
    function Export-AmcacheData {
        param([string]$OutputPath)
        
        Write-Log "Extracting Application Compatibility Cache (Amcache) data..."
        
        try {
            $amcachePath = "C:\Windows\appcompat\Programs\Amcache.hve"
            
            if (Test-Path $amcachePath) {
                try {
                    # Amcache is also locked, use RawCopy if available
                    $rawCopyPath = Get-BinFile 'RawCopy.exe'
                    
                    if (Test-Path $rawCopyPath) {
                        Write-Log "  - Attempting to copy Amcache with RawCopy.exe"
                        & $rawCopyPath /FileNamePath:$amcachePath /OutputPath:$OutputPath | Out-Null
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
    
    # Function to detect suspicious scheduled tasks
    function Export-SuspiciousScheduledTasks {
        param([string]$OutputPath)
        
        Write-Log "Analyzing scheduled tasks for suspicious activity..."
        
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
    
    # Function to collect additional browser artifacts
    function Export-BrowserArtifacts {
        param([string]$OutputPath)
        
        Write-Log "Collecting additional browser artifacts..."
        
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
    
    # Execute Phase 2 collections
    try {
        # Create Phase 2 output directory
        $phase2OutputDir = SafeJoinPath $outputDir "Phase2_Advanced_Analysis"
        New-Item -ItemType Directory -Path $phase2OutputDir -Force -ErrorAction SilentlyContinue | Out-Null
        
        # Execute each Phase 2 function
        Export-ChromeHistory -OutputPath $phase2OutputDir
        Export-FirefoxHistory -OutputPath $phase2OutputDir
        Export-PrefetchAnalysis -OutputPath $phase2OutputDir
        Export-SRUMData -OutputPath $phase2OutputDir
        Export-AmcacheData -OutputPath $phase2OutputDir
        Export-SuspiciousScheduledTasks -OutputPath $phase2OutputDir
        Export-BrowserArtifacts -OutputPath $phase2OutputDir
        
        Write-Log "Phase 2 advanced analysis completed successfully"
    } catch {
        Write-Log "Phase 2 encountered errors (collection may be partial): $_" -Level Warning
    }

    # ============================================================================
    # Compression and Finalization
    # ============================================================================
    
    $zipFile = Join-Path $outputRoot "collected_files.zip"
    if (Test-Path $zipFile) {
        Remove-Item $zipFile
    }
    Write-Verbose "Compressing collected files into $zipFile"
    Write-Log "Compressing collected files for transport"
    Compress-Archive -Path "$outputDir\*" -DestinationPath $zipFile -ErrorAction Stop
    Write-Host "Successfully compressed files to $zipFile."
    Write-Log "Files compressed to: $zipFile"

} catch {
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

# ============================================================================
# Successful Completion - Generate Summary Report
# ============================================================================

$endTime = Get-Date
$duration = $endTime - (Get-Date $timestamp)

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
Compressed Archive: $zipFile
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
Write-Host "  Compressed Archive: $zipFile" -ForegroundColor White
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
