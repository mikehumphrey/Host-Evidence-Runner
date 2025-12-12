#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptPath = $PSScriptRoot

try {
    Write-Verbose "Moving to the correct working directory: $scriptPath"
    Set-Location -Path $scriptPath

    $outputDir = "collected_files"
    if (-not (Test-Path -Path $outputDir)) {
        Write-Verbose "Creating output directory: $outputDir"
        New-Item -ItemType Directory -Name $outputDir
    }

    Write-Verbose "Collecting MFT and LogFile from C: drive"
    # Assuming RawCopy.exe is in a 'bins' subdirectory relative to the script
    Start-Process -FilePath ".\bins\RawCopy.exe" -ArgumentList "/FileNamePath:C:0" -Wait -NoNewWindow
    Start-Process -FilePath ".\bins\RawCopy.exe" -ArgumentList "/FileNamePath:c:\$LogFile" -Wait -NoNewWindow

    Move-Item -Path ".\bins\$MFT" -Destination ".\$outputDir\MFT_C.bin" -Force
    Move-Item -Path ".\bins\$LogFile" -Destination ".\$outputDir\LogFile_C.bin" -Force
    Write-Host "Successfully collected MFT and LogFile."

    Write-Verbose "Collecting EVTX files..."
    Copy-Item -Path "$env:SystemRoot\System32\winevt\logs\*.evtx" -Destination ".\$outputDir\" -Recurse -Force
    Write-Host "Successfully collected EVTX files."

    Write-Verbose "Collecting System Registry hives..."
    robocopy "$env:SystemRoot\System32\Config" ".\$outputDir\Registry" /E /R:1 /W:1 | Out-Null
    Write-Host "Successfully collected System Registry hives."

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

    $zipFile = "collected_files.zip"
    if (Test-Path $zipFile) {
        Remove-Item $zipFile
    }
    Write-Verbose "Compressing collected files into $zipFile"
    Compress-Archive -Path ".\$outputDir\*" -DestinationPath $zipFile
    Write-Host "Successfully compressed files to $zipFile."

} catch {
    Write-Error "An error occurred: $_"
    exit 1
}

Write-Host "Collection script finished."
