# Analyst Workstation Transfer Guide

> **NOTE:** This document has been superseded by `COLLECTION_SUCCESS_GUIDE.md` which includes comprehensive transfer documentation. This file is retained for reference only and is NOT included in releases.
>
> **For Deployments:** Use `docs/sysadmin/COLLECTION_SUCCESS_GUIDE.md`

## Overview

The `-AnalystWorkstation` parameter enables automatic transfer of collected forensic evidence to a designated analyst workstation via robocopy. This feature streamlines the collection-to-analysis workflow by eliminating manual file transfers.

## Usage

### Basic Syntax

```powershell
.\run-collector.ps1 -AnalystWorkstation "<hostname or IP>"
```

### With No Compression

```powershell
.\run-collector.ps1 -AnalystWorkstation "<hostname>" -NoZip
```

## Supported Values

### Localhost Variants (Local Transfer)

All of the following are treated as localhost and will copy to `C:\Temp\Investigations\`:

- `localhost`
- `127.0.0.1`
- Current computer name (e.g., `$env:COMPUTERNAME`)

**Example:**
```powershell
.\run-collector.ps1 -AnalystWorkstation "localhost"
```

**Result:** Files copied to `C:\Temp\Investigations\[Hostname]\[Timestamp]\`

### Remote Host (Network Transfer)

Any valid hostname or IP address that is NOT localhost will trigger UNC path transfer:

**Examples:**
```powershell
.\run-collector.ps1 -AnalystWorkstation "analyst-pc"
.\run-collector.ps1 -AnalystWorkstation "192.168.1.100"
.\run-collector.ps1 -AnalystWorkstation "forensics-workstation.domain.local"
```

**Result:** Files copied to `\\[Hostname]\c$\Temp\Investigations\[SourceHostname]\[Timestamp]\`

## Transfer Behavior

### When Compression Succeeds

If a ZIP file is successfully created, **only the following files** are transferred:

- `collected_files.zip` (the complete collection archive)
- `forensic_collection_[Hostname]_[Timestamp].txt` (the log file)
- `COLLECTION_SUMMARY.txt` (the summary report)

**Advantage:** Much faster transfer (typically 100-500 MB instead of several GB)

### When Compression is Skipped or Fails

If compression is skipped (`-NoZip`) or fails, **the entire directory** is transferred:

- All collected files in their original structure
- Log and summary files

**Note:** This can take significantly longer for large collections.

## Prerequisites

### For Localhost Transfer

- Local administrator rights (script requirement)
- Sufficient disk space on `C:\Temp`

### For Remote Host Transfer

1. **Network Connectivity:**
   - Target host must be reachable on the network
   - Firewall must allow SMB/CIFS (port 445)

2. **Administrative Access:**
   - You must have administrative rights on the target host
   - The `C$` administrative share must be accessible

3. **Permissions:**
   - Account running the script needs write access to `\\[Hostname]\c$\Temp\`

4. **Disk Space:**
   - Target host must have sufficient space in `C:\Temp\Investigations\`

## Validation Testing

Use the included test script to validate your setup before running a full collection:

```powershell
.\Test-AnalystWorkstation.ps1 -AnalystWorkstation "analyst-pc"
```

This will test:
- Parameter validation
- Host type detection (localhost vs. remote)
- Path construction
- Network connectivity (for remote hosts)
- Directory creation requirements
- Robocopy command syntax

## Transfer Process

1. **Destination Path Construction:**
   ```
   \\[AnalystHost]\c$\Temp\Investigations\[SourceHost]\[Timestamp]\
   ```

2. **Connectivity Test** (remote hosts only):
   - Pings target host to verify reachability
   - Continues even if ping fails (some networks block ICMP)

3. **Directory Creation:**
   - Creates parent directories if they don't exist
   - For localhost: ensures `C:\Temp` exists first

4. **Robocopy Transfer:**
   - Uses `/R:3 /W:5` (3 retries, 5-second wait between retries)
   - Copies file attributes and timestamps (`/DCOPY:T /COPY:DAT`)
   - Generates transfer log: `ROBOCopyLog.txt` in destination folder

5. **Exit Code Validation:**
   - Exit codes 0-7: Success (files copied or no changes needed)
   - Exit codes 8+: Errors (some files failed to copy)

## Troubleshooting

### "Cannot ping [hostname]"

**Symptom:** Warning message about ping failure, but transfer continues

**Cause:** Target host firewall blocks ICMP, or host is unreachable

**Action:**
- If you know the host is reachable, ignore the warning
- Verify network connectivity manually: `Test-Connection -ComputerName [hostname]`
- Check if the C$ share is accessible: `dir \\[hostname]\c$`

### "Access is denied" during robocopy

**Symptom:** Robocopy exits with code 16 or shows "Access is denied" errors

**Cause:** Insufficient permissions on target host

**Action:**
1. Verify you have administrator rights on the target host
2. Check if C$ share is enabled: `net share` (on target host)
3. Manually test access: `dir \\[hostname]\c$\Temp`
4. Ensure target firewall allows File and Printer Sharing

### "Network path not found"

**Symptom:** Cannot access `\\[hostname]\c$`

**Cause:** Network connectivity issue or hostname resolution failure

**Action:**
1. Verify hostname spelling
2. Try IP address instead: `-AnalystWorkstation "192.168.1.100"`
3. Test connectivity: `Test-NetConnection -ComputerName [hostname] -Port 445`
4. Check DNS resolution: `Resolve-DnsName [hostname]`

### Robocopy hangs or takes extremely long

**Symptom:** Robocopy appears stuck or transfers very slowly

**Cause:** Large uncompressed files or slow network

**Action:**
1. Use `-NoZip` parameter to skip compression time if disk space permits
2. For large collections (>10 GB), expect transfer to take 10-30 minutes over gigabit
3. Monitor network utilization in Task Manager
4. Consider running collection locally and manually transferring ZIP file

## Best Practices

### 1. Test Before Production Use

Always validate with the test script first:
```powershell
.\Test-AnalystWorkstation.ps1 -AnalystWorkstation "your-analyst-pc"
```

### 2. Use Compression When Possible

Let the script create a ZIP file unless you have specific reasons not to:
```powershell
# Recommended (default behavior)
.\run-collector.ps1 -AnalystWorkstation "analyst-pc"

# Only use -NoZip if compression fails or takes too long
.\run-collector.ps1 -AnalystWorkstation "analyst-pc" -NoZip
```

### 3. Verify Transfer Completion

After collection completes, check:
- The summary report confirms "Successfully transferred"
- Review `ROBOCopyLog.txt` in the destination for any errors
- Verify file integrity on the analyst workstation

### 4. Network Considerations

For remote transfers:
- Use wired network connections when possible (avoid WiFi)
- Run during off-peak hours for large collections
- Ensure analyst workstation is powered on and accessible

### 5. Localhost Testing

For testing or development, use localhost to avoid network dependencies:
```powershell
.\run-collector.ps1 -AnalystWorkstation "localhost" -NoZip
```

## Example Scenarios

### Scenario 1: Standard Remote Collection

**Goal:** Collect from server `WEB-SRV-01` and transfer to analyst workstation `FORENSICS-PC`

**Command:**
```powershell
# Run on WEB-SRV-01
.\run-collector.ps1 -AnalystWorkstation "FORENSICS-PC"
```

**Result:** Compressed evidence copied to `\\FORENSICS-PC\c$\Temp\Investigations\WEB-SRV-01\[Timestamp]\`

### Scenario 2: Large Collection Without Compression

**Goal:** Collect from file server with >50 GB of user data, skip compression to save time

**Command:**
```powershell
.\run-collector.ps1 -AnalystWorkstation "FORENSICS-PC" -NoZip
```

**Result:** Full uncompressed collection copied to analyst workstation

### Scenario 3: Local Testing

**Goal:** Test the collector on your own workstation before deploying to servers

**Command:**
```powershell
.\run-collector.ps1 -AnalystWorkstation "localhost"
```

**Result:** Files copied to `C:\Temp\Investigations\[YourComputerName]\[Timestamp]\`

### Scenario 4: IP Address Transfer

**Goal:** Transfer to analyst workstation by IP (bypassing DNS)

**Command:**
```powershell
.\run-collector.ps1 -AnalystWorkstation "10.50.100.25"
```

**Result:** Evidence transferred to IP-addressed host via UNC path

## Output Directory Structure

On the analyst workstation, files are organized as:

```
C:\Temp\Investigations\
└── [SourceHostname]\
    └── [Timestamp]\
        ├── collected_files.zip (if compression succeeded)
        ├── forensic_collection_[Hostname]_[Timestamp].txt
        ├── COLLECTION_SUMMARY.txt
        └── ROBOCopyLog.txt
```

Or, if compression was skipped:

```
C:\Temp\Investigations\
└── [SourceHostname]\
    └── [Timestamp]\
        ├── collected_files\
        │   ├── MFT_C.bin
        │   ├── Registry\
        │   ├── [all collected artifacts]
        │   └── ...
        ├── forensic_collection_[Hostname]_[Timestamp].txt
        ├── COLLECTION_SUMMARY.txt
        └── ROBOCopyLog.txt
```

## Security Considerations

1. **Credential Security:** Script uses your current credentials (pass-through authentication)
2. **Network Sniffing:** SMB traffic is encrypted by default on Windows 10+ and Server 2016+
3. **Administrative Shares:** Requires C$ share access (standard for domain administrators)
4. **Audit Trail:** Robocopy log provides complete transfer record

## Performance Expectations

| Collection Size | Compression Time | Transfer Time (Gigabit) | Total Time |
|----------------|------------------|------------------------|------------|
| Small (<1 GB)  | 1-3 minutes      | 30-60 seconds          | 2-5 minutes |
| Medium (1-5 GB)| 5-15 minutes     | 2-5 minutes            | 10-20 minutes |
| Large (5-20 GB)| 20-60 minutes    | 10-20 minutes          | 30-80 minutes |
| Very Large (>20 GB) | Use `-NoZip` | 20-120 minutes | Varies |

*Times are approximate and depend on disk speed, CPU, and network performance*

## Related Documentation

- `README.md` - Main documentation
- `Test-AnalystWorkstation.ps1` - Validation test script
- `COLLECTION_SUMMARY.txt` - Generated after each collection
- `ROBOCopyLog.txt` - Detailed transfer log
