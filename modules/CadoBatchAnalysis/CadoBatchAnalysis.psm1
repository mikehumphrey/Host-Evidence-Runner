#Requires -Version 5.1
<#
.SYNOPSIS
    This module contains functions for post-collection analysis of forensic data
    collected by the Cado-Batch toolset.
#>

function New-YaraRuleFromInput {
<#
.SYNOPSIS
    Dynamically generates a Yara rule from a given CSV input file.
.DESCRIPTION
    Reads a CSV file containing Filename and SHA256Hash columns and creates a 
    temporary Yara rule file (.yar) that can be used to scan for either attribute.
.PARAMETER InputFile
    The path to the CSV file containing the sensitive file information.
.PARAMETER TempRulePath
    The path where the temporary Yara rule will be saved.
#>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputFile,
        [Parameter(Mandatory=$true)]
        [string]$TempRulePath
    )

    try {
        $sensitiveFiles = Import-Csv -Path $InputFile
    }
    catch {
        Write-Error "Failed to read or parse the CSV file at '$InputFile'. Please ensure it is a valid CSV with 'FileName' and 'SHA256Hash' headers."
        throw
    }

    $ruleHeader = @"
rule Sensitive_File_Detection
{
    strings:
"@
    $ruleFooter = @"
    condition:
        any of them
}
"@

    $stringConditions = @()
    foreach ($file in $sensitiveFiles) {
        $stringConditions += "`t`t`$fname_{0} = `"{1}`" nocase" -f ($stringConditions.Count + 1), $file.FileName
    }

    # Combine the parts into a final rule
    $finalRule = $ruleHeader + "`n" + ($stringConditions -join "`n") + "`n" + $ruleFooter
    
    Set-Content -Path $TempRulePath -Value $finalRule
    Write-Verbose "Successfully generated temporary Yara rule at $TempRulePath"
}

function Invoke-YaraScan {
<#
.SYNOPSIS
    Performs a post-collection Yara scan on collected forensic artifacts.
.DESCRIPTION
    This function scans previously collected artifacts from a Cado-Batch investigation.
    It dynamically generates a Yara rule based on a user-provided list of sensitive
    files (filenames and hashes) and scans the collected data for any traces of them.
.PARAMETER InvestigationPath
    The full path to a specific investigation timestamp folder 
    (e.g., .\investigations\Case_123\SERVER01\20251212_143022).
.PARAMETER YaraInputFile
    The path to the CSV file containing the sensitive file information.
    Must have 'FileName' and 'SHA256Hash' columns.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InvestigationPath,
        [Parameter(Mandatory=$true)]
        [string]$YaraInputFile
    )
    
    $yaraExecutable = ".\tools\yara\yara64.exe"
    if (-not (Test-Path $yaraExecutable)) {
        Write-Error "Yara executable not found at '$yaraExecutable'. Please download it from https://github.com/VirusTotal/yara/releases and place it in the tools\yara folder."
        return
    }

    $collectedFilesPath = Join-Path $InvestigationPath "collected_files"
    if (-not (Test-Path $collectedFilesPath)) {
        Write-Error "The specified investigation path does not contain a 'collected_files' directory. Please provide a valid path to a timestamped collection folder."
        return
    }

    $tempRuleFile = Join-Path $env:TEMP "cado_temp_rule.yar"
    $scanOutputFile = Join-Path $InvestigationPath "Phase3_Yara_Scan_Results.txt"

    try {
        Write-Host "1. Generating dynamic Yara rule from input file..." -ForegroundColor Cyan
        New-YaraRuleFromInput -InputFile $YaraInputFile -TempRulePath $tempRuleFile

        Write-Host "2. Starting Yara scan on collected artifacts at '$collectedFilesPath'..." -ForegroundColor Cyan
        
        $arguments = @(
            "-r", # Recursive scan
            $tempRuleFile,
            $collectedFilesPath
        )
        
        # Execute Yara and capture output
        $process = Start-Process -FilePath $yaraExecutable -ArgumentList $arguments -Wait -NoNewWindow -PassThru -RedirectStandardOutput $scanOutputFile
        
        if ($process.ExitCode -eq 0) {
            Write-Host "✅ Scan complete. Results saved to '$scanOutputFile'." -ForegroundColor Green
        } else {
            Write-Warning "Yara scan completed with exit code $($process.ExitCode). Review the output file for details."
        }

    }
    finally {
        Write-Host "3. Cleaning up temporary files..." -ForegroundColor Cyan
        if (Test-Path $tempRuleFile) {
            Remove-Item $tempRuleFile -Force
        }
    }
}

function Invoke-EventLogParsing {
<#
.SYNOPSIS
    Parses Windows Event Logs (.evtx files) from collected artifacts using EvtxECmd.
.DESCRIPTION
    This function uses Eric Zimmerman's EvtxECmd tool to parse all .evtx files
    in the collected artifacts directory and generate CSV/JSON output for analysis.
.PARAMETER InvestigationPath
    The full path to a specific investigation timestamp folder.
.PARAMETER OutputFormat
    The output format for parsed logs. Options: 'csv', 'json', 'both'. Default is 'csv'.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InvestigationPath,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('csv', 'json', 'both')]
        [string]$OutputFormat = 'csv'
    )
    
    # Try to find EvtxECmd in available .NET versions (prefer newer versions first)
    $evtxCmdPath = $null
    $netVersions = @("net9", "net8", "net6")
    foreach ($netVer in $netVersions) {
        $testPath = ".\tools\optional\ZimmermanTools\$netVer\EvtxeCmd\EvtxECmd.exe"
        if (Test-Path $testPath) {
            $evtxCmdPath = $testPath
            Write-Host "   Using EvtxECmd from $netVer folder" -ForegroundColor Gray
            break
        }
    }
    
    if (-not $evtxCmdPath) {
        Write-Error "EvtxECmd.exe not found in any .NET version folder. Options:`n" +
                    "1. Download .NET 6/8 version: Run Get-ZimmermanTools.ps1 -NetVersion 6`n" +
                    "2. Install .NET 9 runtime: https://dotnet.microsoft.com/download/dotnet/9.0`n" +
                    "3. Ensure Zimmerman Tools are installed in tools\optional\ZimmermanTools"
        return
    }

    $collectedFilesPath = Join-Path $InvestigationPath "collected_files"
    if (-not (Test-Path $collectedFilesPath)) {
        Write-Error "The specified investigation path does not contain a 'collected_files' directory."
        return
    }

    # Find all .evtx files
    $evtxFiles = Get-ChildItem -Path $collectedFilesPath -Filter "*.evtx" -Recurse -ErrorAction SilentlyContinue
    if ($evtxFiles.Count -eq 0) {
        Write-Warning "No .evtx files found in '$collectedFilesPath'."
        return
    }

    $outputDir = Join-Path $InvestigationPath "Phase3_EventLog_Analysis"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Write-Host "1. Found $($evtxFiles.Count) event log files to parse..." -ForegroundColor Cyan
    Write-Host "2. Parsing event logs with EvtxECmd (this may take several minutes)..." -ForegroundColor Cyan
    
    try {
        $arguments = @(
            "-d", $collectedFilesPath,  # Directory containing evtx files
            "--csv", $outputDir          # Output directory for CSV
        )
        
        if ($OutputFormat -eq 'json' -or $OutputFormat -eq 'both') {
            $arguments += @("--json", $outputDir)
        }

        # Execute EvtxECmd
        $process = Start-Process -FilePath $evtxCmdPath -ArgumentList $arguments -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "✅ Event log parsing complete. Results saved to '$outputDir'." -ForegroundColor Green
            
            # Display summary of output files
            $outputFiles = Get-ChildItem -Path $outputDir -File | Measure-Object -Property Length -Sum
            Write-Host "   Generated $($outputFiles.Count) output file(s), total size: $([math]::Round($outputFiles.Sum / 1MB, 2)) MB" -ForegroundColor Gray
        } else {
            Write-Warning "EvtxECmd completed with exit code $($process.ExitCode). Check output for details."
        }
    }
    catch {
        Write-Error "Failed to parse event logs: $_"
        throw
    }
}

function Search-EventLogData {
<#
.SYNOPSIS
    Searches parsed event log CSV for suspicious patterns, commands, or IOCs.
.DESCRIPTION
    Filters the parsed event log CSV file for specific keywords, Event IDs,
    suspicious commands, file paths, or other indicators of compromise.
.PARAMETER InvestigationPath
    The full path to a specific investigation timestamp folder.
.PARAMETER Keywords
    Array of keywords to search for (case-insensitive). Searches across all fields.
.PARAMETER EventIDs
    Array of specific Event IDs to filter (e.g., 4624, 4688, 7045).
.PARAMETER SuspiciousPatterns
    Switch to enable pre-defined suspicious pattern detection (PowerShell obfuscation,
    encoded commands, persistence mechanisms, etc.).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InvestigationPath,
        
        [Parameter(Mandatory=$false)]
        [string[]]$Keywords,
        
        [Parameter(Mandatory=$false)]
        [int[]]$EventIDs,
        
        [Parameter(Mandatory=$false)]
        [switch]$SuspiciousPatterns
    )
    
    $eventLogCsv = Join-Path $InvestigationPath "Phase3_EventLog_Analysis"
    $csvFile = Get-ChildItem -Path $eventLogCsv -Filter "*.csv" -File | Select-Object -First 1
    
    if (-not $csvFile) {
        Write-Error "No parsed event log CSV found. Run Invoke-EventLogParsing first."
        return
    }
    
    Write-Host "1. Loading event log data from '$($csvFile.Name)'..." -ForegroundColor Cyan
    Write-Host "   File size: $([math]::Round($csvFile.Length / 1MB, 2)) MB" -ForegroundColor Gray
    
    try {
        # Import CSV (this may take time for large files)
        $events = Import-Csv -Path $csvFile.FullName
        Write-Host "   Loaded $($events.Count) event records" -ForegroundColor Gray
        
        $filteredEvents = $events
        
        # Filter by Event IDs if specified
        if ($EventIDs) {
            Write-Host "2. Filtering by Event IDs: $($EventIDs -join ', ')..." -ForegroundColor Cyan
            $filteredEvents = $filteredEvents | Where-Object { 
                $eventId = $null
                [int]::TryParse($_.EventId, [ref]$eventId) | Out-Null
                $EventIDs -contains $eventId
            }
            Write-Host "   Found $($filteredEvents.Count) matching events" -ForegroundColor Gray
        }
        
        # Filter by Keywords if specified
        if ($Keywords) {
            Write-Host "3. Searching for keywords: $($Keywords -join ', ')..." -ForegroundColor Cyan
            $filteredEvents = $filteredEvents | Where-Object {
                $record = $_ | ConvertTo-Json -Compress
                $match = $false
                foreach ($keyword in $Keywords) {
                    if ($record -like "*$keyword*") {
                        $match = $true
                        break
                    }
                }
                $match
            }
            Write-Host "   Found $($filteredEvents.Count) matching events" -ForegroundColor Gray
        }
        
        # Apply suspicious pattern detection
        if ($SuspiciousPatterns) {
            Write-Host "4. Applying suspicious pattern detection..." -ForegroundColor Cyan
            $suspiciousPatterns = @(
                "*powershell*-enc*",           # Encoded PowerShell
                "*powershell*-e *",            # Encoded PowerShell (short form)
                "*downloadstring*",            # Web downloads
                "*iex(*",                      # Invoke-Expression
                "*invoke-expression*",
                "*bypass*",                    # Execution policy bypass
                "*hidden*",                    # Hidden windows
                "*wscript*",                   # Script execution
                "*cscript*",
                "*regsvr32*",                  # LOLBin abuse
                "*rundll32*",
                "*mshta*",
                "*certutil*-decode*",          # File download/decode
                "*bitsadmin*",
                "*schtasks*",                  # Scheduled tasks
                "*at.exe*",
                "*reg add*run*",               # Registry persistence
                "*new-service*",               # Service creation
                "*mimikatz*",                  # Credential dumping
                "*procdump*",
                "*lsass*"
            )
            
            $filteredEvents = $filteredEvents | Where-Object {
                $record = $_ | ConvertTo-Json -Compress
                $match = $false
                foreach ($pattern in $suspiciousPatterns) {
                    if ($record -like $pattern) {
                        $match = $true
                        break
                    }
                }
                $match
            }
            Write-Host "   Found $($filteredEvents.Count) suspicious events" -ForegroundColor Yellow
        }
        
        # Save filtered results
        if ($filteredEvents.Count -gt 0) {
            $outputFile = Join-Path $InvestigationPath "Phase3_Filtered_EventLog_Results.csv"
            $filteredEvents | Export-Csv -Path $outputFile -NoTypeInformation
            Write-Host "✅ Filtered results saved to '$outputFile'" -ForegroundColor Green
            Write-Host "   Total filtered events: $($filteredEvents.Count)" -ForegroundColor Gray
            
            # Display sample of most interesting fields
            Write-Host "`n📊 Sample of filtered results:" -ForegroundColor Yellow
            $filteredEvents | Select-Object -First 10 TimeCreated, EventId, Computer, ExecutableInfo, PayloadData1 | Format-Table -AutoSize
        } else {
            Write-Warning "No events matched the specified filters."
        }
        
    }
    catch {
        Write-Error "Failed to search event logs: $_"
        throw
    }
}

function Search-MFTForPaths {
<#
.SYNOPSIS
    Searches the Master File Table (MFT) for specific file paths or names.
.DESCRIPTION
    Uses MFTECmd from Zimmerman Tools to parse the MFT and search for file/folder references.
.PARAMETER InvestigationPath
    The full path to a specific investigation timestamp folder.
.PARAMETER SearchPaths
    Array of paths or filenames to search for in the MFT.
.PARAMETER SearchPathsFile
    File containing paths/filenames to search (one per line).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InvestigationPath,
        
        [Parameter(Mandatory=$false)]
        [string[]]$SearchPaths,
        
        [Parameter(Mandatory=$false)]
        [string]$SearchPathsFile
    )
    
    # Find MFTECmd
    $mftCmdPath = $null
    $netVersions = @("net9", "net8", "net6")
    foreach ($netVer in $netVersions) {
        $testPath = ".\tools\optional\ZimmermanTools\$netVer\MFTECmd.exe"
        if (Test-Path $testPath) {
            $mftCmdPath = $testPath
            Write-Host "   Using MFTECmd from $netVer folder" -ForegroundColor Gray
            break
        }
    }
    
    if (-not $mftCmdPath) {
        Write-Error "MFTECmd.exe not found. Ensure Zimmerman Tools are installed."
        return
    }
    
    $collectedFilesPath = Join-Path $InvestigationPath "collected_files"
    
    # Check for MFT file - it may be in MFT_C.bin directory as $MFT file
    $mftFile = Join-Path $collectedFilesPath "MFT_C.bin\`$MFT"
    if (-not (Test-Path $mftFile)) {
        $mftFile = Join-Path $collectedFilesPath "MFT_C.bin"
        if (-not (Test-Path $mftFile)) {
            Write-Error "MFT file not found in collected_files\MFT_C.bin"
            return
        }
    }
    
    Write-Host "   Using MFT file: $mftFile" -ForegroundColor Gray
    
    # Load search paths
    $pathsToSearch = @()
    if ($SearchPathsFile -and (Test-Path $SearchPathsFile)) {
        $pathsToSearch = Get-Content $SearchPathsFile | Where-Object { $_.Trim() -ne "" }
        Write-Host "   Loaded $($pathsToSearch.Count) paths from file" -ForegroundColor Gray
    }
    if ($SearchPaths) {
        $pathsToSearch += $SearchPaths
    }
    
    if ($pathsToSearch.Count -eq 0) {
        Write-Warning "No search paths specified."
        return
    }
    
    $outputDir = Join-Path $InvestigationPath "Phase3_MFT_Analysis"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    Write-Host "1. Parsing MFT with MFTECmd..." -ForegroundColor Cyan
    
    try {
        # Parse MFT to CSV
        $mftCsvOutput = Join-Path $outputDir "MFT_Full.csv"
        $arguments = @(
            "-f", $mftFile,
            "--csv", $outputDir,
            "--csvf", "MFT_Full.csv"
        )
        
        $process = Start-Process -FilePath $mftCmdPath -ArgumentList $arguments -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -ne 0) {
            Write-Warning "MFTECmd completed with exit code $($process.ExitCode)."
        }
        
        if (-not (Test-Path $mftCsvOutput)) {
            Write-Error "MFT parsing failed - no output file created."
            return
        }
        
        Write-Host "2. Searching MFT records for matching paths..." -ForegroundColor Cyan
        
        # Import and search MFT CSV
        $mftRecords = Import-Csv -Path $mftCsvOutput
        Write-Host "   Loaded $($mftRecords.Count) MFT records" -ForegroundColor Gray
        
        $matchedRecords = $mftRecords | Where-Object {
            $record = $_ | ConvertTo-Json -Compress
            $match = $false
            foreach ($path in $pathsToSearch) {
                if ($record -like "*$path*") {
                    $match = $true
                    break
                }
            }
            $match
        }
        
        if ($matchedRecords.Count -gt 0) {
            $outputFile = Join-Path $InvestigationPath "Phase3_MFT_PathMatches.csv"
            $matchedRecords | Export-Csv -Path $outputFile -NoTypeInformation
            
            Write-Host "✅ Found $($matchedRecords.Count) MFT records matching search paths" -ForegroundColor Green
            Write-Host "   Results saved to '$outputFile'" -ForegroundColor Gray
            
            # Display sample
            Write-Host "`n📊 Sample of matched files:" -ForegroundColor Yellow
            $matchedRecords | Select-Object -First 10 EntryNumber, FileName, ParentPath, Created0x10, Modified0x10 | Format-Table -AutoSize
        } else {
            Write-Warning "No MFT records matched the specified paths."
        }
        
    }
    catch {
        Write-Error "Failed to search MFT: $_"
        throw
    }
}

function Generate-InvestigationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InvestigationPath
    )

    $reportDir = $InvestigationPath
    $mftMatchesPath = Join-Path $InvestigationPath "Phase3_MFT_PathMatches.csv"
    $eventFilteredPath = Join-Path $InvestigationPath "Phase3_Filtered_EventLog_Results.csv"
    $eventParsedDir = Join-Path $InvestigationPath "Phase3_EventLog_Analysis"

    $summary = [ordered]@{}

    if (Test-Path $mftMatchesPath) {
        $mft = Import-Csv -Path $mftMatchesPath
        $summary.MFTMatchCount = $mft.Count
        $summary.MFTDistinctFiles = ($mft | Select-Object -Expand FileName | Sort-Object -Unique).Count
        $summary.MFTPaths = ($mft | Select-Object -Expand ParentPath | Sort-Object -Unique)
        $summary.MFTFirstCreated = ($mft | Where-Object { $_.Created0x10 } | Select-Object -Expand Created0x10 | Sort-Object | Select-Object -First 1)
        $summary.MFTLastModified = ($mft | Where-Object { $_.LastModified0x10 } | Select-Object -Expand LastModified0x10 | Sort-Object -Descending | Select-Object -First 1)
    }

    if (Test-Path $eventFilteredPath) {
        $ev = Import-Csv -Path $eventFilteredPath
        $summary.EventMatches = $ev.Count
        $summary.EventFirst = ($ev | Select-Object -Expand TimeCreated | Sort-Object | Select-Object -First 1)
        $summary.EventLast = ($ev | Select-Object -Expand TimeCreated | Sort-Object -Descending | Select-Object -First 1)
    }

    $mdPath = Join-Path $reportDir "Investigation_Summary.md"
    $lines = @()
    $lines += "# Investigation Summary"
    $lines += ""
    $lines += "- Case Path: `$InvestigationPath = $InvestigationPath"
    if ($summary.MFTMatchCount) {
        $lines += "- MFT Matches: $($summary.MFTMatchCount) across $($summary.MFTDistinctFiles) files"
        if ($summary.MFTFirstCreated) { $lines += "- First Created (MFT): $($summary.MFTFirstCreated)" }
        if ($summary.MFTLastModified) { $lines += "- Last Modified (MFT): $($summary.MFTLastModified)" }
        $topFiles = ($mft | Group-Object FileName | Sort-Object Count -Descending | Select-Object -First 10)
        if ($topFiles) {
            $lines += ""
            $lines += "**Top Files by MFT records**"
            foreach ($t in $topFiles) { $lines += "- $($t.Name): $($t.Count) records" }
        }
    }
    if ($summary.EventMatches -ne $null) {
        $lines += ""
        $lines += "- Event Log Matches: $($summary.EventMatches)"
        if ($summary.EventFirst) { $lines += "- First Event: $($summary.EventFirst)" }
        if ($summary.EventLast) { $lines += "- Last Event: $($summary.EventLast)" }
    }

    $lines | Set-Content -Path $mdPath -Encoding UTF8
    Write-Host "   Wrote report: $mdPath" -ForegroundColor Green
}

Export-ModuleMember -Function Invoke-YaraScan, Invoke-EventLogParsing, Search-EventLogData, Search-MFTForPaths, Generate-InvestigationReport
