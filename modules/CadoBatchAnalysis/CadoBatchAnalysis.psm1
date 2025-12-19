#Requires -Version 5.1
<#
.SYNOPSIS
    This module contains functions for post-collection analysis of forensic data
    collected by the Host-Evidence-Runner (HER) toolset.
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
    This function scans previously collected artifacts from a Host-Evidence-Runner investigation.
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
    Optimized for large files using streaming instead of loading entire file into memory.
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
    
    $fileSizeMB = [math]::Round($csvFile.Length / 1MB, 2)
    Write-Host "1. Processing event log data from '$($csvFile.Name)'..." -ForegroundColor Cyan
    Write-Host "   File size: $fileSizeMB MB" -ForegroundColor Gray
    
    # Check file size and warn if very large
    if ($fileSizeMB -gt 1000) {
        Write-Warning "Large CSV file detected ($fileSizeMB MB). Processing may take 10-30 minutes."
        Write-Host "   Using streaming mode to conserve memory..." -ForegroundColor Yellow
    } elseif ($fileSizeMB -gt 500) {
        Write-Warning "CSV file is large ($fileSizeMB MB). Processing may take 5-15 minutes."
    }
    
    try {
        # Use streaming approach for large files (>500MB) to avoid memory issues
        $useStreaming = $fileSizeMB -gt 500
        
        if ($useStreaming) {
            Write-Host "   Using streaming mode for large file..." -ForegroundColor Gray
            
            # Stream-based processing (doesn't load entire file into memory)
            $filteredEvents = [System.Collections.ArrayList]::new()
            $lineCount = 0
            $matchCount = 0
            $headerLine = $null
            $headers = @()
            
            # Read file line by line
            $reader = [System.IO.StreamReader]::new($csvFile.FullName)
            
            try {
                # Read header
                $headerLine = $reader.ReadLine()
                $headers = $headerLine -split ','
                $eventIdIndex = [array]::IndexOf($headers, 'EventId')
                
                # Progress tracking
                $startTime = Get-Date
                $lastProgress = $startTime
                
                while (($line = $reader.ReadLine()) -ne $null) {
                    $lineCount++
                    
                    # Show progress every 100K lines
                    if ($lineCount % 100000 -eq 0) {
                        $elapsed = (Get-Date) - $startTime
                        $rate = $lineCount / $elapsed.TotalSeconds
                        Write-Host "   Processed $([math]::Round($lineCount / 1000000, 1))M lines ($([math]::Round($rate, 0)) lines/sec)..." -ForegroundColor Gray
                    }
                    
                    $matchesFilter = $true
                    
                    # Filter by Event IDs (fast check before parsing full line)
                    if ($EventIDs -and $eventIdIndex -ge 0) {
                        $fields = $line -split ','
                        if ($fields.Count -gt $eventIdIndex) {
                            $eventId = $null
                            [int]::TryParse($fields[$eventIdIndex].Trim('"'), [ref]$eventId) | Out-Null
                            if ($eventId -and $EventIDs -notcontains $eventId) {
                                $matchesFilter = $false
                            }
                        }
                    }
                    
                    # Filter by Keywords (case-insensitive substring search)
                    if ($matchesFilter -and $Keywords) {
                        $match = $false
                        foreach ($keyword in $Keywords) {
                            if ($line -like "*$keyword*") {
                                $match = $true
                                break
                            }
                        }
                        if (-not $match) {
                            $matchesFilter = $false
                        }
                    }
                    
                    # Filter by Suspicious Patterns
                    if ($matchesFilter -and $SuspiciousPatterns) {
                        $suspiciousPatterns = @(
                            "*powershell*-enc*", "*powershell*-e *", "*downloadstring*",
                            "*iex(*", "*invoke-expression*", "*bypass*", "*hidden*",
                            "*wscript*", "*cscript*", "*regsvr32*", "*rundll32*", "*mshta*",
                            "*certutil*-decode*", "*bitsadmin*", "*schtasks*", "*at.exe*",
                            "*reg add*run*", "*new-service*", "*mimikatz*", "*procdump*", "*lsass*"
                        )
                        
                        $match = $false
                        foreach ($pattern in $suspiciousPatterns) {
                            if ($line -like $pattern) {
                                $match = $true
                                break
                            }
                        }
                        if (-not $match) {
                            $matchesFilter = $false
                        }
                    }
                    
                    # Add matching line to results
                    if ($matchesFilter) {
                        $matchCount++
                        # Store as CSV line (will be parsed at the end)
                        [void]$filteredEvents.Add($line)
                    }
                }
                
                Write-Host "   Scanned $lineCount total event records" -ForegroundColor Gray
                Write-Host "   Found $matchCount matching events" -ForegroundColor Green
                
            } finally {
                $reader.Close()
            }
            
            # Convert matched lines back to objects for output
            if ($matchCount -gt 0) {
                Write-Host "   Converting matched results to objects..." -ForegroundColor Gray
                # Recreate CSV with header and matched lines
                $tempCsv = Join-Path ([System.IO.Path]::GetTempPath()) "filtered_events_$(Get-Date -Format 'yyyyMMddHHmmss').csv"
                $headerLine | Set-Content $tempCsv
                $filteredEvents | Add-Content $tempCsv
                
                # Import the filtered CSV (now much smaller)
                $filteredEvents = Import-Csv -Path $tempCsv
                Remove-Item $tempCsv -Force -ErrorAction SilentlyContinue
            } else {
                $filteredEvents = @()
            }
            
        } else {
            # Small file - use traditional Import-Csv (faster for files <500MB)
            Write-Host "   Loading all event records into memory..." -ForegroundColor Gray
            $events = Import-Csv -Path $csvFile.FullName
            Write-Host "   Loaded $($events.Count) event records" -ForegroundColor Gray
            
            $filteredEvents = $events
        
            # Filter by Event IDs if specified (small files only - streaming mode handles this inline)
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

function Generate-Reports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)] [string]$InvestigationPath,
        [Parameter(Mandatory=$false)] [string]$CasePath,
        [Parameter(Mandatory=$false)] [string]$HostPath,
        [Parameter(Mandatory=$false)] [string]$CollectionPath
    )

    # Resolve root based on provided input
    $collections = @()
    if ($CollectionPath) {
        if (Test-Path $CollectionPath) { $collections += $CollectionPath } else { Write-Error "CollectionPath not found: $CollectionPath"; return }
    } elseif ($HostPath) {
        if (-not (Test-Path $HostPath)) { Write-Error "HostPath not found: $HostPath"; return }
        $collections += Get-ChildItem -Path $HostPath -Directory | Where-Object { $_.Name -match '^[0-9]{8}_[0-9]{6}$' } | ForEach-Object { $_.FullName }
    } elseif ($CasePath) {
        if (-not (Test-Path $CasePath)) { Write-Error "CasePath not found: $CasePath"; return }
        $hostDirs = Get-ChildItem -Path $CasePath -Directory
        foreach ($h in $hostDirs) {
            $collections += Get-ChildItem -Path $h.FullName -Directory | Where-Object { $_.Name -match '^[0-9]{8}_[0-9]{6}$' } | ForEach-Object { $_.FullName }
        }
    } elseif ($InvestigationPath) {
        # Alias of CasePath (root of investigation)
        if (-not (Test-Path $InvestigationPath)) { Write-Error "InvestigationPath not found: $InvestigationPath"; return }
        $hostDirs = Get-ChildItem -Path $InvestigationPath -Directory
        foreach ($h in $hostDirs) {
            $collections += Get-ChildItem -Path $h.FullName -Directory | Where-Object { $_.Name -match '^[0-9]{8}_[0-9]{6}$' } | ForEach-Object { $_.FullName }
        }
    } else {
        Write-Error "Provide one of: -CollectionPath | -HostPath | -CasePath | -InvestigationPath"
        return
    }

    if ($collections.Count -eq 0) { Write-Warning "No collections found to summarize."; return }

    # Per-collection summary generation
    foreach ($c in $collections) {
        try {
            Generate-InvestigationReport -InvestigationPath $c
        } catch { Write-Warning "Failed to summarize collection '$c': $_" }
    }

    # Group by host
    $byHost = $collections | Group-Object { Split-Path (Split-Path $_ -Parent) -Leaf }
    foreach ($group in $byHost) {
        $hostName = $group.Name
        $hostRoot = Split-Path $group.Group[0] -Parent
        $rollup = @()
        foreach ($c in $group.Group) {
            $mftCsv = Join-Path $c "Phase3_MFT_PathMatches.csv"
            $evCsv = Join-Path $c "Phase3_Filtered_EventLog_Results.csv"
            $stats = [ordered]@{ Collection = Split-Path $c -Leaf; MFTMatches = 0; EventMatches = 0 }
            if (Test-Path $mftCsv) { $stats.MFTMatches = (Import-Csv $mftCsv).Count }
            if (Test-Path $evCsv) { $stats.EventMatches = (Import-Csv $evCsv).Count }
            $rollup += [pscustomobject]$stats
        }
        $hostMd = Join-Path $hostRoot "Host_Summary.md"
        $lines = @("# Host Summary: $hostName", "")
        $lines += "- Collections: $($group.Group.Count)"
        $lines += "- Total MFT Matches: $([int]($rollup | Measure-Object -Property MFTMatches -Sum).Sum)"
        $lines += "- Total Event Matches: $([int]($rollup | Measure-Object -Property EventMatches -Sum).Sum)"
        $lines += ""
        $lines += "**Collections**"
        foreach ($r in $rollup) { $lines += "- $($r.Collection): MFT=$($r.MFTMatches), Events=$($r.EventMatches)" }
        $lines | Set-Content -Path $hostMd -Encoding UTF8
    }

    # Investigation rollup (case root)
    $caseRoot = $null
    if ($CasePath) { $caseRoot = $CasePath }
    elseif ($InvestigationPath) { $caseRoot = $InvestigationPath }
    else { $caseRoot = Split-Path (Split-Path $collections[0] -Parent) -Parent }

    if ($caseRoot -and (Test-Path $caseRoot)) {
        $hosts = Get-ChildItem -Path $caseRoot -Directory
        $invLines = @("# Investigation Summary", "")
        $invLines += "- Hosts: $($hosts.Count)"
        $allStats = @()
        foreach ($h in $hosts) {
            $cols = Get-ChildItem -Path $h.FullName -Directory | Where-Object { $_.Name -match '^[0-9]{8}_[0-9]{6}$' }
            $invLines += "- Host $($h.Name): Collections=$($cols.Count)"
            foreach ($c in $cols) {
                $mftCsv = Join-Path $c.FullName "Phase3_MFT_PathMatches.csv"
                $evCsv = Join-Path $c.FullName "Phase3_Filtered_EventLog_Results.csv"
                $stats = [ordered]@{ Host=$h.Name; Collection=$c.Name; MFTMatches=0; EventMatches=0 }
                if (Test-Path $mftCsv) { $stats.MFTMatches = (Import-Csv $mftCsv).Count }
                if (Test-Path $evCsv) { $stats.EventMatches = (Import-Csv $evCsv).Count }
                $allStats += [pscustomobject]$stats
            }
        }
        $invLines += ""
        $invLines += "**Collections Overview**"
        foreach ($s in $allStats) { $invLines += "- $($s.Host) / $($s.Collection): MFT=$($s.MFTMatches), Events=$($s.EventMatches)" }
        $invMd = Join-Path $caseRoot "Investigation_Summary.md"
        $invLines | Set-Content -Path $invMd -Encoding UTF8
        Write-Host "   Wrote investigation summary: $invMd" -ForegroundColor Green
    }
}

Export-ModuleMember -Function Invoke-YaraScan, Invoke-EventLogParsing, Search-EventLogData, Search-MFTForPaths, Generate-InvestigationReport, Generate-Reports
