#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptPath = $PSScriptRoot

# ============================================================================
# Initialize Logging
# ============================================================================

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$computerName = $env:COMPUTERNAME
$logFile = Join-Path $scriptPath "logs\forensic_collection_${computerName}_${timestamp}.txt"

# Ensure logs directory exists
$logsDir = Join-Path $scriptPath "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

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
Write-Log "Forensic Collection Tool - Collection Started"
Write-Log "============================================================================"
Write-Log "Computer: $computerName"
Write-Log "User: $env:USERNAME"
Write-Log "Script Location: $scriptPath"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Log "OS Version: $([System.Environment]::OSVersion)"

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

    $outputDir = "collected_files"
    if (-not (Test-Path -Path $outputDir)) {
        Write-Verbose "Creating output directory: $outputDir"
        Write-Log "Creating output directory: $outputDir"
        New-Item -ItemType Directory -Name $outputDir | Out-Null
    }

    Write-Verbose "Collecting MFT and LogFile from C: drive"
    Write-Log "Collecting MFT and LogFile from C: drive"
    # Assuming RawCopy.exe is in a 'bins' subdirectory relative to the script
    Start-Process -FilePath ".\bins\RawCopy.exe" -ArgumentList "/FileNamePath:C:0" -Wait -NoNewWindow
    Start-Process -FilePath ".\bins\RawCopy.exe" -ArgumentList "/FileNamePath:c:\$LogFile" -Wait -NoNewWindow

    Move-Item -Path ".\bins\$MFT" -Destination ".\$outputDir\MFT_C.bin" -Force -ErrorAction SilentlyContinue
    Move-Item -Path ".\bins\$LogFile" -Destination ".\$outputDir\LogFile_C.bin" -Force -ErrorAction SilentlyContinue
    Write-Host "Successfully collected MFT and LogFile."
    Write-Log "Successfully collected MFT and LogFile."

    Write-Verbose "Collecting EVTX files..."
    Write-Log "Collecting EVTX files..."
    Copy-Item -Path "$env:SystemRoot\System32\winevt\logs\*.evtx" -Destination ".\$outputDir\" -Recurse -Force
    Write-Host "Successfully collected EVTX files."
    Write-Log "Successfully collected EVTX files."

    Write-Verbose "Collecting System Registry hives..."
    Write-Log "Collecting System Registry hives..."
    robocopy "$env:SystemRoot\System32\Config" ".\$outputDir\Registry" /E /R:1 /W:1 | Out-Null
    Write-Host "Successfully collected System Registry hives."
    Write-Log "Successfully collected System Registry hives."

    Write-Verbose "Collecting additional system artifacts..."
    
    # Collect Prefetch files
    $prefetchDir = Join-Path $env:SystemRoot "Prefetch"
    if (Test-Path $prefetchDir) {
        Write-Verbose "Collecting prefetch files from $prefetchDir"
        Copy-Item -Path "$prefetchDir\*.pf" -Destination ".\$outputDir\Prefetch\" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Successfully collected prefetch files."
    }

    # Collect Scheduled Tasks (XML format)
    Write-Verbose "Collecting Windows Scheduled Tasks..."
    $tasksPath = Join-Path $env:SystemRoot "System32\Tasks"
    if (Test-Path $tasksPath) {
        robocopy $tasksPath ".\$outputDir\ScheduledTasks" /E /R:1 /W:1 | Out-Null
        Write-Host "Successfully collected scheduled tasks."
    }

    # Collect Windows Search Index
    Write-Verbose "Collecting Windows Search Index (Windows.db)..."
    $searchPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Search\Data\Applications\Windows\Windows.db"
    if (Test-Path $searchPath) {
        Copy-Item -Path $searchPath -Destination ".\$outputDir\" -Force -ErrorAction SilentlyContinue
        Write-Host "Successfully collected Windows Search Index."
    }

    # Collect HOSTS file
    Write-Verbose "Collecting HOSTS file..."
    $hostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
    if (Test-Path $hostsPath) {
        Copy-Item -Path $hostsPath -Destination ".\$outputDir\" -Force
        Write-Host "Successfully collected HOSTS file."
    }

    # Collect Recycle Bin info ($Recycle.Bin)
    Write-Verbose "Collecting Recycle Bin metadata..."
    $recycleDir = Join-Path $env:SystemDrive '$Recycle.Bin'
    if (Test-Path $recycleDir) {
        robocopy $recycleDir ".\$outputDir\RecycleBin" /E /R:1 /W:1 | Out-Null
        Write-Host "Successfully collected Recycle Bin data."
    }

    # Collect Windows Temp directory
    Write-Verbose "Collecting Windows Temp directory..."
    $winTempPath = Join-Path $env:SystemRoot "Temp"
    if (Test-Path $winTempPath) {
        robocopy $winTempPath ".\$outputDir\Windows_Temp" /E /R:1 /W:1 | Out-Null
        Write-Host "Successfully collected Windows Temp files."
    }

    # Collect Amcache.hve
    $amcachePath = Join-Path $env:SystemRoot "appcompat\Programs\Amcache.hve"
    if (Test-Path $amcachePath) {
        Write-Verbose "Collecting Amcache.hve"
        Copy-Item -Path $amcachePath -Destination ".\$outputDir\" -Force
        Write-Host "Successfully collected Amcache.hve."
    }

    # Collect SRUM database
    $srumPath = Join-Path $env:SystemRoot "System32\sru\SRUDB.dat"
    if (Test-Path $srumPath) {
        Write-Verbose "Collecting SRUM database (SRUDB.dat)"
        robocopy (Split-Path $srumPath) ".\$outputDir" (Split-Path $srumPath -Leaf) /R:1 /W:1 | Out-Null
        Write-Host "Successfully collected SRUM database."
    }

    # Collect USN Journal
    Write-Verbose "Collecting USN Journal (\$UsnJrnl)"
    Start-Process -FilePath ".\bins\RawCopy.exe" -ArgumentList "/FileNamePath:C:\$Extend\$UsnJrnl" -Wait -NoNewWindow
    if (Test-Path ".\bins\$UsnJrnl") {
        Move-Item -Path ".\bins\$UsnJrnl" -Destination ".\$outputDir\UsnJrnl_C.bin" -Force
        Write-Host "Successfully collected USN Journal."
    } else {
        Write-Warning "Could not find the collected USN Journal. RawCopy may have failed."
    }

    Write-Verbose "Collecting user-specific artifacts for all profiles..."
    $userProfiles = Get-ChildItem -Path "$env:SystemDrive\Users" -Directory | Where-Object { $_.Name -notin @("Default", "Public", "All Users") }
    foreach ($user in $userProfiles) {
        $userName = $user.Name
        $userOutputDir = Join-Path $outputDir "Users\$userName"
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

    Write-Verbose "Listing root directory of C: drive"
    Get-ChildItem -Path "$env:SystemDrive\" | Out-File -FilePath ".\$outputDir\C_Dir.txt"
    Write-Host "Successfully listed C:\ root directory."

    Write-Verbose "Collecting network and connection artifacts..."
    
    # RDP Connection History (from registry - will be exported separately)
    Write-Verbose "  - Collecting RDP connection history..."
    $rdpRegPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Terminal Server Client\Default"
    if (Test-Path $rdpRegPath) {
        $rdpServers = Get-Item -Path $rdpRegPath | Select-Object -ExpandProperty Property
        if ($rdpServers) {
            $rdpServers | ForEach-Object {
                Add-Content -Path ".\$outputDir\RDP_ConnectionHistory.txt" -Value "$_"
            }
            Write-Verbose "    - Collected RDP connection history"
        }
    }

    # Network configuration (ipconfig, etc.)
    Write-Verbose "  - Collecting network configuration..."
    ipconfig /all | Out-File -FilePath ".\$outputDir\Network_IPConfig.txt"
    Get-NetAdapter | Out-File -FilePath ".\$outputDir\Network_Adapters.txt"
    Get-NetRoute | Out-File -FilePath ".\$outputDir\Network_Routes.txt"
    Write-Verbose "    - Collected network configuration"

    # WiFi Profiles
    Write-Verbose "  - Collecting WiFi profiles..."
    try {
        $wifiProfiles = netsh wlan show profile | Select-String "All User Profile" | ForEach-Object { $_.Line.Split(":")[1].Trim() }
        if ($wifiProfiles) {
            $wifiProfiles | Out-File -FilePath ".\$outputDir\WiFi_Profiles.txt"
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
            Get-ItemProperty -Path $_.PSPath | Select-Object PSChildName, FriendlyName | Out-File -FilePath ".\$outputDir\USB_DeviceHistory.txt" -Append
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
    
    $hashdeepPath = Join-Path $scriptPath "bins\hashdeep.exe"
    if (Test-Path $hashdeepPath) {
        try {
            Write-Verbose "  - Running hashdeep.exe on collected files"
            & $hashdeepPath -r -c sha256 ".\$outputDir" | Out-File -FilePath ".\$outputDir\SHA256_MANIFEST.txt" -ErrorAction Stop
            Write-Host "Successfully generated SHA256 manifest."
            Write-Log "SHA256 manifest created: $outputDir\SHA256_MANIFEST.txt"
        } catch {
            Write-Log "Warning: Could not generate SHA256 manifest: $_" -Level Warning
            Write-Host "Warning: SHA256 manifest generation failed (continuing collection)"
        }
    } else {
        Write-Log "Note: hashdeep.exe not found in bins/ - SHA256 manifest skipped (Phase 1 tool not installed)" -Level Warning
        Write-Verbose "hashdeep.exe not available - skipping hash verification"
    }
    
    # Verify executable signatures using sigcheck
    Write-Verbose "Verifying executable signatures..."
    Write-Log "Verifying executable signatures in collected artifacts"
    
    $sigcheckPath = Join-Path $scriptPath "bins\sigcheck.exe"
    if (Test-Path $sigcheckPath) {
        try {
            Write-Verbose "  - Running sigcheck.exe on collected executables"
            
            # Find all .exe files in collected artifacts
            $exeFiles = Get-ChildItem -Path ".\$outputDir" -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue
            if ($exeFiles) {
                & $sigcheckPath -nobanner -accepteula $exeFiles.FullName | Out-File -FilePath ".\$outputDir\ExecutableSignatures.txt" -ErrorAction Stop
                Write-Host "Successfully verified executable signatures."
                Write-Log "Executable signatures verified: $outputDir\ExecutableSignatures.txt"
            } else {
                Write-Verbose "  - No .exe files found in collected artifacts"
                Write-Log "No executables found in collected artifacts - signature verification skipped"
            }
        } catch {
            Write-Log "Warning: Could not verify executable signatures: $_" -Level Warning
            Write-Host "Warning: Executable signature verification failed (continuing collection)"
        }
    } else {
        Write-Log "Note: sigcheck.exe not found in bins/ - signature verification skipped (Phase 1 tool not installed)" -Level Warning
        Write-Verbose "sigcheck.exe not available - skipping signature verification"
    }
    
    # Extract strings from registry hives for analysis
    Write-Verbose "Extracting readable strings from critical files..."
    Write-Log "Extracting strings from registry hives for analysis"
    
    $stringsPath = Join-Path $scriptPath "bins\strings.exe"
    if (Test-Path $stringsPath) {
        try {
            Write-Verbose "  - Running strings.exe on registry hives"
            
            $registryDir = Join-Path $outputDir "Registry"
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
    # Compression and Finalization
    # ============================================================================
    
    $zipFile = "collected_files.zip"
    if (Test-Path $zipFile) {
        Remove-Item $zipFile
    }
    Write-Verbose "Compressing collected files into $zipFile"
    Write-Log "Compressing collected files for transport"
    Compress-Archive -Path ".\$outputDir\*" -DestinationPath $zipFile -ErrorAction Stop
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
# Successful Completion
# ============================================================================

Write-Log "============================================================================"
Write-Log "Collection Process Completed Successfully"
Write-Log "============================================================================"
Write-Log "Output Location: $outputDir"
Write-Log "Log File: $logFile"

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "COLLECTION COMPLETE!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Collected data location: $outputDir" -ForegroundColor Green
Write-Host "Log file: $logFile" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Disconnect USB from server"
Write-Host "2. Copy '$outputDir' folder to return to analyst"
Write-Host "3. Also copy log file to provide to analyst"
Write-Host "4. Contact analyst to confirm receipt"
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
