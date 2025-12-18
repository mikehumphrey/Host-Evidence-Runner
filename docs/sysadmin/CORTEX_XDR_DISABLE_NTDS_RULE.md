# Disabling Cortex XDR NTDS Rule for Forensic Collection

## Overview

When running forensic collection on systems with Cortex XDR behavioral threat protection, you may encounter the following error:

```
Prevention information:
  Rule: sync.raw_file_operation_ntds.1
  Status: c0400067
  Component: Behavioral Threat Protection
  Description: Behavioral threat detected
```

This rule blocks access to NTDS (Active Directory Database) files, which are critical for forensic analysis. This guide provides PowerShell commands to temporarily disable this rule during collection.

---

## Method 1: Using Cortex XDR API (Recommended)

### Prerequisites
- Administrator access on the forensic workstation
- Cortex XDR tenant credentials or API token
- PowerShell 5.0+

### Script: Disable Rule for 4 Hours

```powershell
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Temporarily disable Cortex XDR NTDS rule for forensic collection.
.PARAMETER TenantURL
    Your Cortex XDR tenant URL (e.g., https://your-org.xdr.us.paloaltonetworks.com)
.PARAMETER APIKey
    Cortex XDR API Key
.PARAMETER APISecret
    Cortex XDR API Secret
.PARAMETER DurationHours
    How many hours to disable the rule (default: 4)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantURL,
    
    [Parameter(Mandatory=$true)]
    [string]$APIKey,
    
    [Parameter(Mandatory=$true)]
    [string]$APISecret,
    
    [Parameter(Mandatory=$false)]
    [int]$DurationHours = 4
)

$ErrorActionPreference = 'Stop'

Write-Host "Cortex XDR - NTDS Rule Disable Script" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Calculate expiration time
$ExpirationTime = (Get-Date).AddHours($DurationHours)
$ExpirationISO = $ExpirationTime.ToUniversalTime().ToString("o")

Write-Host "Disabling rule: sync.raw_file_operation_ntds.1" -ForegroundColor Yellow
Write-Host "Duration: $DurationHours hours" -ForegroundColor Yellow
Write-Host "Expires at: $ExpirationTime (local time)" -ForegroundColor Yellow
Write-Host ""

# Create API authentication header
$AuthString = "$APIKey`:`$APISecret"
$EncodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($AuthString))
$Headers = @{
    "Authorization" = "Basic $EncodedAuth"
    "Content-Type" = "application/json"
}

# Prepare payload for disabling the rule
$Payload = @{
    "group_id" = "default"
    "rule_id" = "sync.raw_file_operation_ntds.1"
    "expiration_time" = $ExpirationISO
    "reason" = "Forensic NTDS collection - temporary exception"
} | ConvertTo-Json

try {
    # Create the exception in Cortex XDR
    $Uri = "$TenantURL/api/v1/prevention/rules/exceptions/add"
    
    Write-Host "Connecting to Cortex XDR..." -ForegroundColor Cyan
    $Response = Invoke-RestMethod -Uri $Uri -Method POST -Headers $Headers -Body $Payload
    
    if ($Response.reply.success -eq $true) {
        Write-Host "✓ Rule successfully disabled!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Rule Details:" -ForegroundColor Green
        Write-Host "  Rule ID: sync.raw_file_operation_ntds.1" -ForegroundColor White
        Write-Host "  Expiration: $ExpirationTime" -ForegroundColor White
        Write-Host "  Duration: $DurationHours hours" -ForegroundColor White
        Write-Host ""
        Write-Host "You can now run your forensic collection." -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host "✗ Failed to disable rule" -ForegroundColor Red
        Write-Host "Response: $($Response | ConvertTo-Json)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Error connecting to Cortex XDR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify TenantURL is correct (no trailing slash)" -ForegroundColor White
    Write-Host "  2. Check APIKey and APISecret are valid" -ForegroundColor White
    Write-Host "  3. Ensure API credentials have permission to manage prevention rules" -ForegroundColor White
    Write-Host "  4. Verify your network can reach the Cortex XDR API" -ForegroundColor White
    exit 1
}

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run: .\run-collector.ps1" -ForegroundColor White
Write-Host "  2. Collection will complete without XDR blocking" -ForegroundColor White
Write-Host "  3. Rule will automatically re-enable in $DurationHours hours" -ForegroundColor White
Write-Host ""
```

### Usage:
```powershell
# Set your credentials (store securely, don't hardcode)
$Creds = @{
    TenantURL = "https://your-org.xdr.us.paloaltonetworks.com"
    APIKey = "your-api-key-here"
    APISecret = "your-api-secret-here"
    DurationHours = 4
}

# Run the script
.\Disable-XDR-NTDS-Rule.ps1 @Creds
```

---

## Method 2: Group Policy / Local Policy (Windows Defender Alternative)

If you're using Windows Defender instead of Cortex XDR, you can temporarily disable threat protection:

```powershell
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Temporarily disable Windows Defender real-time protection for forensic collection.
.PARAMETER DurationMinutes
    How many minutes to disable protection (default: 240 = 4 hours)
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$DurationMinutes = 240
)

$ErrorActionPreference = 'Stop'

Write-Host "Windows Defender - Temporary Disable" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$ExpirationTime = (Get-Date).AddMinutes($DurationMinutes)

Write-Host "Disabling real-time protection for $DurationMinutes minutes" -ForegroundColor Yellow
Write-Host "Will re-enable at: $ExpirationTime" -ForegroundColor Yellow
Write-Host ""

try {
    # Disable real-time protection
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
    
    Write-Host "✓ Real-time protection disabled" -ForegroundColor Green
    Write-Host ""
    
    # Create scheduled task to re-enable after duration
    $TaskAction = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -WindowStyle Hidden -Command `"Set-MpPreference -DisableRealtimeMonitoring `$false`""
    
    $TaskTrigger = New-ScheduledTaskTrigger -Once -At $ExpirationTime
    
    Register-ScheduledTask -TaskName "XDR-Re-Enable-RealTimeProtection" `
        -Action $TaskAction `
        -Trigger $TaskTrigger `
        -Description "Re-enable real-time protection after forensic collection" `
        -Force | Out-Null
    
    Write-Host "✓ Auto-re-enable scheduled for $ExpirationTime" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now run your forensic collection." -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host "✗ Error disabling protection:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "IMPORTANT: Remember to verify protection is re-enabled!" -ForegroundColor Yellow
Write-Host ""
```

---

## Method 3: Manual Console Approach (If API unavailable)

If PowerShell API access isn't available, manually disable in the Cortex XDR console:

1. **Log into Cortex XDR Console**
   - Navigate to: `Policies` → `Policy Management` → `Behavioral Threat Protection`

2. **Create Exception Rule**
   - Click: `+ Add Rule` or `Add Exception`
   - **Rule Type**: `Disable Prevention`
   - **Priority**: Set high to override blocking rule

3. **Scope Configuration**
   - **Process**: `powershell.exe` or `powershell_ise.exe`
   - **Or Scope by SHA256**: 
     ```powershell
     (Get-FileHash "C:\path\to\run-collector.ps1" -Algorithm SHA256).Hash
     ```

4. **Select Rule to Disable**
   - **Rule ID**: `sync.raw_file_operation_ntds.1`

5. **Set Expiration**
   - **Duration**: 4 hours from now
   - **Auto-disable**: Yes

6. **Save and Apply**

---

## Quick Reference: One-Liner Formats

### Disable for 4 hours (Windows Defender):
```powershell
Set-MpPreference -DisableRealtimeMonitoring $true; Start-Sleep -Seconds 14400; Set-MpPreference -DisableRealtimeMonitoring $false
```

### Check current Cortex XDR status:
```powershell
Get-WmiObject -Namespace root\cimv2 -Class CIM_Process | Where-Object {$_.Name -eq "csfalcon.exe"} | Select-Object ProcessId, Name
```

---

## Verification

After disabling the rule, verify you can access NTDS files:

```powershell
# Test NTDS access
$NTDS = "C:\Windows\NTDS\ntds.dit"
if (Test-Path $NTDS) {
    Write-Host "✓ NTDS file accessible" -ForegroundColor Green
    (Get-Item $NTDS).FullName
} else {
    Write-Host "✗ NTDS file not accessible" -ForegroundColor Red
    Write-Host "Rule may still be blocking. Verify disabling was successful." -ForegroundColor Yellow
}
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "API Key invalid" | Verify credentials in Cortex XDR console |
| "Connection timeout" | Check firewall, ensure TenantURL is reachable |
| "Permission denied" | Ensure API credentials have "Manage Prevention Rules" permission |
| "Rule still blocking" | Allow 1-2 minutes for policy sync, or manually verify in console |
| "Script blocked by execution policy" | Run: `powershell -ExecutionPolicy Bypass -File .\script.ps1` |

---

## Important Notes

⚠️ **Security Considerations:**
- Only disable rules during active forensic investigations
- Set automatic re-enable timers (don't rely on manual re-enabling)
- Document all rule disablements for audit trail
- Notify your SOC/Security team before disabling rules
- Use API keys with minimal required permissions
- Never hardcode credentials in scripts (use secure vaults)

✓ **Best Practices:**
- Use 4-hour window for typical forensic collection
- Test in lab environment first
- Have a rollback plan if collection fails
- Verify protection is re-enabled after collection
- Archive forensic data before rule re-enables

---

## Support

If you encounter issues:
1. Check Cortex XDR console for rule status
2. Review XDR event logs: `Behavioral Threat Protection` events
3. Contact your SOC/Security team for API troubleshooting
4. Verify all prerequisites (Admin rights, API access, network connectivity)
