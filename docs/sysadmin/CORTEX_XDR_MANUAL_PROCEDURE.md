# Cortex XDR Manual Exception Procedure

## Overview

This guide provides step-by-step instructions for manually disabling the Cortex XDR NTDS rule (`sync.raw_file_operation_ntds.1`) through the web console when API access is unavailable or authentication fails.

**Use this procedure when:**
- The automated script (`Disable-XDR-NTDS-Rule.ps1`) fails with authentication errors
- API credentials are unavailable or expired
- You need to disable the rule immediately without troubleshooting API issues
- Your organization uses SSO/SAML for Cortex XDR (script uses Basic Auth only)

---

## Prerequisites

- Access to Cortex XDR web console
- Credentials with **Administrator** or **Privileged Responder** role
- Permissions to manage exception policies

---

## Procedure

### Step 1: Access Cortex XDR Console

1. Open your web browser
2. Navigate to your Cortex XDR tenant URL:
   ```
   https://[your-org].xdr.us.paloaltonetworks.com
   ```
   *(Replace with your actual tenant URL)*

3. Sign in with your credentials
   - Use SSO if configured
   - Or enter username/password

### Step 2: Navigate to Exception Management

Choose **ONE** of the following navigation paths:

#### Option A: Via Response Actions (Recommended)
1. Click **Response** in the left menu
2. Click **Action Center**
3. Click **Response Actions** tab
4. Click **+ Create Response Action**
5. Select **Exception Policy**

#### Option B: Via Policy Management
1. Click **Policies** in the left menu
2. Click **Policy Management**
3. Click **Behavioral Threat Protection**
4. Click **Exceptions** tab
5. Click **+ Add Exception**

### Step 3: Configure the Exception

Fill in the exception details:

**Basic Information:**
- **Name**: `Forensic NTDS Collection - [Date]`
  - Example: `Forensic NTDS Collection - 2025-12-17`
- **Description**: `Temporary exception for forensic collection of NTDS database files during authorized investigation`

**Exception Type:**
- Select: **Disable Prevention** (or **Behavioral Threat Protection Exception**)

**Rule Configuration:**
- **Rule ID**: `sync.raw_file_operation_ntds.1`
  - *You may need to search or select from dropdown*
- **Rule Name**: *Should auto-populate as "Raw File Operation NTDS"*

**Scope (Optional but Recommended):**
- **Process**: `powershell.exe` or `powershell_ise.exe`
  - This limits the exception to PowerShell processes only
- **Device Groups**: Select specific groups if needed
  - Or leave as "All Devices" for org-wide

**Duration:**
- **Expiration**: Set to **4 hours** from current time
  - Example: If current time is 15:00, set expiration to 19:00
- **Auto-Disable**: ✓ Enabled (checkbox)

**Policy Assignment:**
- **Policy Group**: `default` (or select your specific policy)
- **Priority**: Leave as default (or set higher if conflicts exist)

### Step 4: Review and Activate

1. Review all settings
2. Click **Save** or **Create Exception**
3. Confirm the exception is listed with status: **Active**
4. Note the **Expiration Time** displayed

### Step 5: Verify Exception is Active

1. Click on the newly created exception
2. Verify status shows: **Active** or **Enabled**
3. Check expiration time is correct (4 hours from now)
4. If status shows **Pending**, wait 1-2 minutes for policy sync

---

## Running Forensic Collection

Once the exception is active:

1. **Wait 1-2 minutes** for the policy to sync to endpoints
2. Run your forensic collection script:
   ```powershell
   .\run-collector.ps1
   ```
   Or with analyst workstation transfer:
   ```powershell
   .\run-collector.ps1 -AnalystWorkstation "analyst-pc"
   ```

3. Monitor collection progress - it should complete without XDR blocks

---

## Verification

### During Collection

Watch for these indicators that the exception is working:
- ✅ No "Behavioral threat detected" alerts in Cortex XDR
- ✅ No error messages about NTDS file access
- ✅ Collection completes successfully

### After Collection

1. Check **Action Center** → **Incidents** for any alerts
2. Review **Data Sources** → **Query Builder** for any blocked actions
3. If no incidents related to NTDS access, exception worked correctly

---

## Post-Collection Cleanup

### Automatic Re-enable

The rule will **automatically re-enable** after 4 hours (or your configured duration).

**No manual action required** - the exception expires automatically.

### Manual Re-enable (If Needed Immediately)

If you want to re-enable protection before the 4-hour window:

1. Go back to **Exceptions** list
2. Find your exception: `Forensic NTDS Collection - [Date]`
3. Click the **three dots** (⋮) or select the exception
4. Click **Disable** or **Delete**
5. Confirm the action

Protection is restored immediately.

---

## Troubleshooting

### "Cannot find rule sync.raw_file_operation_ntds.1"

**Cause**: Rule ID may be different in your XDR version

**Solution**:
1. Go to **Policies** → **Policy Management** → **Behavioral Threat Protection**
2. Click **Rules** tab
3. Search for: `NTDS` or `raw file operation`
4. Note the exact Rule ID shown
5. Use that Rule ID in your exception

### "Permission denied" when creating exception

**Cause**: Insufficient permissions

**Solution**:
1. Verify your role in XDR: Settings → Users → Your Account
2. Contact your XDR administrator to request **Privileged Responder** role
3. Or ask administrator to create the exception for you

### Exception shows "Pending" for more than 5 minutes

**Cause**: Policy sync delay or conflict

**Solution**:
1. Check **Notifications** (bell icon) for sync status
2. Try deleting and recreating the exception
3. Verify no conflicting policies exist with higher priority
4. Contact Palo Alto Networks support if issue persists

### Collection still blocked after creating exception

**Cause**: Exception not applied to correct scope

**Solution**:
1. Verify exception scope includes the target devices
2. Check **Process** field includes `powershell.exe`
3. Ensure **Policy Group** matches your device's policy
4. Wait 2-3 minutes for policy propagation, then retry

---

## Alternative: Temporary Global Disable (Emergency Only)

**⚠️ WARNING:** Only use this in emergency situations where forensic collection is time-critical and targeted exceptions cannot be configured.

### Procedure

1. Go to **Policies** → **Policy Management**
2. Select your **Behavioral Threat Protection** policy
3. Click **Edit Policy**
4. Find the NTDS rule: `sync.raw_file_operation_ntds.1`
5. Change status from **Enabled** to **Disabled**
6. Set a reminder to **re-enable after collection**
7. Click **Save**

**Important**: This disables the rule for ALL devices in the policy group. Re-enable as soon as collection completes.

---

## Best Practices

### 1. Document Every Exception

Create a tracking log:
```
Date: 2025-12-17
Time: 15:00 - 19:00
Rule: sync.raw_file_operation_ntds.1
Reason: Authorized forensic collection on SERVER-01
Approver: [Your Name/Ticket Number]
Status: Completed successfully
```

### 2. Use Narrow Scope

Always scope exceptions to:
- ✅ Specific processes (`powershell.exe`)
- ✅ Specific device groups (if possible)
- ✅ Shortest necessary duration (4 hours is usually sufficient)

Avoid:
- ❌ Org-wide exceptions for all processes
- ❌ Indefinite/permanent exceptions
- ❌ Disabling entire policy categories

### 3. Coordinate with SOC

Before creating exceptions:
1. Notify your Security Operations Center (SOC)
2. Provide ticket/incident number if applicable
3. Confirm expected timeframe
4. Document in your ticketing system

### 4. Verify Auto-Re-enable

After the expiration time:
1. Check that exception status changed to **Expired**
2. Verify rule is active again in the policy
3. Test that NTDS access is now blocked (optional)

---

## Reference Information

### Rule Details

**Rule ID**: `sync.raw_file_operation_ntds.1`

**Rule Name**: Raw File Operation NTDS

**Description**: Detects attempts to access NTDS database files (Active Directory) which may indicate credential dumping or unauthorized domain database access.

**Severity**: High

**Why This Blocks Forensic Collection**: Legitimate forensic tools need to access NTDS.dit to extract domain/user information for investigation purposes. This triggers the same behavioral signature as malicious tools.

### Typical Collection Files Affected

When this rule is active, XDR blocks access to:
- `C:\Windows\NTDS\ntds.dit` (AD database)
- `C:\Windows\NTDS\*.log` (transaction logs)
- `C:\Windows\System32\config\SYSTEM` (registry hive for decryption keys)

The forensic collector needs these files to perform comprehensive Windows domain analysis.

---

## Quick Reference Card

**Create Exception:**
1. Response → Action Center → Response Actions → + Create Response Action → Exception Policy
2. Name: `Forensic NTDS Collection - [Date]`
3. Rule ID: `sync.raw_file_operation_ntds.1`
4. Duration: 4 hours
5. Auto-disable: ✓ Enabled
6. Save

**Verify Active:**
- Status: Active/Enabled
- Expiration: 4 hours from now

**Run Collection:**
```powershell
.\run-collector.ps1
```

**Auto Re-enables:** After 4 hours (no action needed)

---

## Support Contacts

**Internal Support:**
- SOC/Security Team: [Your SOC contact]
- IT Helpdesk: [Your helpdesk]

**Vendor Support:**
- Palo Alto Networks TAC: 1-866-898-9087
- Support Portal: https://support.paloaltonetworks.com

**Emergency After-Hours:**
- Contact your on-call security team
- For critical incidents, call Palo Alto Networks 24/7 support

---

## Related Documentation

- `Disable-XDR-NTDS-Rule.ps1` - Automated script (when API works)
- `CORTEX_XDR_DISABLE_NTDS_RULE.md` - Full API documentation
- `ANALYST_WORKSTATION_GUIDE.md` - Forensic collection transfer guide
- Cortex XDR Admin Guide: https://docs.paloaltonetworks.com/cortex/cortex-xdr

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-17 | 1.0 | Initial manual procedure created |
