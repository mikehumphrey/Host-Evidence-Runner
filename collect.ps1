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

        # Browser History (Edge, Chrome, Firefox)
        $browserPaths = @{
            "Edge"     = "$user.FullName\AppData\Local\Microsoft\Edge\User Data\Default\History";
            "Chrome"   = "$user.FullName\AppData\Local\Google\Chrome\User Data\Default\History";
            "Firefox"  = "$user.FullName\AppData\Roaming\Mozilla\Firefox\Profiles\*.default*\places.sqlite";
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
    }
    Write-Host "Successfully collected user-specific artifacts."

    Write-Verbose "Listing root directory of C: drive"
    Get-ChildItem -Path "$env:SystemDrive\" | Out-File -FilePath ".\$outputDir\C_Dir.txt"
    Write-Host "Successfully listed C:\ root directory."

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
