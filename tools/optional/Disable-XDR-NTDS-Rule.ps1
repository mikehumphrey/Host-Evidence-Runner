#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Temporarily disable Cortex XDR NTDS rule for forensic collection.

.DESCRIPTION
    Connects to Cortex XDR API and creates a temporary exception for the
    sync.raw_file_operation_ntds.1 rule, allowing forensic collection scripts
    to access NTDS and other protected files for 4 hours (default, customizable).

.PARAMETER TenantURL
    Your Cortex XDR tenant URL (e.g., https://your-org.xdr.us.paloaltonetworks.com)
    No trailing slash.

.PARAMETER APIKey
    Cortex XDR API Key (from Cortex XDR console Settings > API Keys)

.PARAMETER APISecret
    Cortex XDR API Secret (from Cortex XDR console Settings > API Keys)

.PARAMETER DurationHours
    How many hours to disable the rule (default: 4)
    
.PARAMETER PolicyGroup
    Which policy group to apply exception to (default: "default")
    
.PARAMETER ProcessName
    Optional: Limit exception to specific process (e.g., "powershell.exe")

.EXAMPLE
    # Disable for 4 hours using environment variables
    $env:XDR_URL = "https://org.xdr.us.paloaltonetworks.com"
    $env:XDR_KEY = "your-api-key"
    $env:XDR_SECRET = "your-api-secret"
    .\Disable-XDR-NTDS-Rule.ps1

.EXAMPLE
    # Disable for 6 hours with specific parameters
    .\Disable-XDR-NTDS-Rule.ps1 `
        -TenantURL "https://org.xdr.us.paloaltonetworks.com" `
        -APIKey "key" `
        -APISecret "secret" `
        -DurationHours 6

.NOTES
    Author: Forensic Collection Tool
    Requires: Administrator privileges, network access to Cortex XDR API
    Important: Rule automatically re-enables after specified duration
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TenantURL = $env:XDR_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$APIKey = $env:XDR_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$APISecret = $env:XDR_SECRET,
    
    [Parameter(Mandatory=$false)]
    [int]$DurationHours = 4,
    
    [Parameter(Mandatory=$false)]
    [string]$PolicyGroup = "default",
    
    [Parameter(Mandatory=$false)]
    [string]$ProcessName = ""
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# Validation
# ============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Cortex XDR NTDS Rule Disable - Forensic Collection" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $TenantURL -or -not $APIKey -or -not $APISecret) {
    Write-Host "[ERROR] Missing required credentials" -ForegroundColor Red
    Write-Host ""
    Write-Host "Provide credentials via parameters or environment variables:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Option 1: Environment Variables" -ForegroundColor Green
    Write-Host '    $env:XDR_URL = "https://org.xdr.us.paloaltonetworks.com"' -ForegroundColor White
    Write-Host '    $env:XDR_KEY = "your-api-key"' -ForegroundColor White
    Write-Host '    $env:XDR_SECRET = "your-api-secret"' -ForegroundColor White
    Write-Host "    .\Disable-XDR-NTDS-Rule.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "  Option 2: Command Line Parameters" -ForegroundColor Green
    Write-Host "    .\Disable-XDR-NTDS-Rule.ps1 \" -ForegroundColor White
    Write-Host '      -TenantURL "https://org.xdr.us.paloaltonetworks.com" \' -ForegroundColor White
    Write-Host '      -APIKey "key" \' -ForegroundColor White
    Write-Host '      -APISecret "secret"' -ForegroundColor White
    Write-Host ""
    exit 1
}

# Clean up URL
$TenantURL = $TenantURL.TrimEnd('/')

# Calculate expiration
$ExpirationTime = (Get-Date).AddHours($DurationHours)
$ExpirationISO = $ExpirationTime.ToUniversalTime().ToString("o")

# Display parameters
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Rule ID:        sync.raw_file_operation_ntds.1" -ForegroundColor White
Write-Host "  Duration:       $DurationHours hours" -ForegroundColor White
Write-Host "  Expires at:     $($ExpirationTime.ToString('yyyy-MM-dd HH:mm:ss K'))" -ForegroundColor White
Write-Host "  Policy Group:   $PolicyGroup" -ForegroundColor White
if ($ProcessName) {
    Write-Host "  Process:        $ProcessName" -ForegroundColor White
}
Write-Host "  Tenant:         $TenantURL" -ForegroundColor White
Write-Host ""

# ============================================================================
# API Call
# ============================================================================

Write-Host "Connecting to Cortex XDR API..." -ForegroundColor Cyan

try {
    # Create authentication header
    $AuthString = "$APIKey`:`$APISecret"
    $EncodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($AuthString))
    $Headers = @{
        "Authorization" = "Basic $EncodedAuth"
        "Content-Type" = "application/json"
    }

    # Build the reason string using the format operator and single quotes for safety
    $Reason = 'Forensic NTDS collection - temporary exception ({0} hours)' -f $DurationHours
    
    # Prepare API payload
    $PayloadObj = @{
        "group_id" = $PolicyGroup
        "rule_id" = "sync.raw_file_operation_ntds.1"
        "expiration_time" = $ExpirationISO
        "reason" = $Reason
    }
    
    # Add optional process scope
    if ($ProcessName) {
        $PayloadObj["process_name"] = $ProcessName
    }
    
    $Payload = $PayloadObj | ConvertTo-Json
    
    # Make API request
    $Uri = "$TenantURL/api/v1/prevention/rules/exceptions/add"
    
    Write-Verbose "URI: $Uri"
    Write-Verbose "Payload: $Payload"
    
    $Response = Invoke-RestMethod -Uri $Uri `
        -Method POST `
        -Headers $Headers `
        -Body $Payload `
        -TimeoutSec 30 `
        -ErrorAction Stop
    
    # ============================================================================
    # Handle Response
    # ============================================================================
    
    $success = $false
    if ($Response.reply) {
        if (($Response.reply.success -eq $true) -or ($Response.reply.err -eq 0)) {
            $success = $true
        }
    }

    if ($success) {
        Write-Host "[SUCCESS] Rule disabled successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Rule Details:" -ForegroundColor Green
        Write-Host "  Status:     DISABLED" -ForegroundColor Green
        Write-Host "  Rule ID:    sync.raw_file_operation_ntds.1" -ForegroundColor White
        Write-Host "  Duration:   $DurationHours hours" -ForegroundColor White
        Write-Host "  Re-enable:  $($ExpirationTime.ToString('yyyy-MM-dd HH:mm:ss K'))" -ForegroundColor White
        Write-Host ""
        Write-Host "You can now proceed with forensic collection." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Run your forensic collection: .\run-collector.ps1" -ForegroundColor White
        Write-Host "  2. Collection will NOT be blocked by XDR" -ForegroundColor White
        Write-Host "  3. Rule will automatically re-enable in $DurationHours hours" -ForegroundColor White
        Write-Host ""
        # Script will exit with 0 implicitly
    } else {
        Write-Host "[ERROR] API returned unexpected response" -ForegroundColor Red
        Write-Host ""
        
        # Check if response is HTML (login page redirect)
        $responseText = $Response | ConvertTo-Json -Depth 3
        if ($responseText -like "*html*" -or $responseText -like "*Sign-In*") {
            Write-Host "AUTHENTICATION ISSUE DETECTED" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "The API returned an HTML login page instead of JSON." -ForegroundColor Yellow
            Write-Host "This typically means:" -ForegroundColor Yellow
            Write-Host "  1. API credentials are invalid or expired" -ForegroundColor White
            Write-Host "  2. API endpoint URL is incorrect" -ForegroundColor White
            Write-Host "  3. Your organization requires OAuth/SAML instead of Basic Auth" -ForegroundColor White
            Write-Host ""
            Write-Host "RECOMMENDED ACTIONS:" -ForegroundColor Cyan
            Write-Host "  1. Verify API credentials in Cortex XDR Console:" -ForegroundColor White
            Write-Host "     Settings > Configurations > API Keys" -ForegroundColor Gray
            Write-Host "  2. Regenerate API Key and API Key ID" -ForegroundColor White
            Write-Host "  3. Verify API endpoint format (should be api-*.xdr.*.paloaltonetworks.com)" -ForegroundColor White
            Write-Host "  4. Use manual procedure: See docs/sysadmin/CORTEX_XDR_MANUAL_PROCEDURE.md" -ForegroundColor White
            Write-Host ""
        } else {
            Write-Host "Response:" -ForegroundColor Yellow
            Write-Host $responseText -ForegroundColor White
            Write-Host ""
        }
        exit 1
    }
    
} catch [System.Net.Http.HttpRequestException] {
    Write-Host "[ERROR] Connection Error" -ForegroundColor Red
    Write-Host ""
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Verify TenantURL is correct: $TenantURL" -ForegroundColor White
    Write-Host "  - Ensure no trailing slash in URL" -ForegroundColor White
    Write-Host "  - Check network connectivity to Cortex XDR" -ForegroundColor White
    Write-Host "  - Verify your firewall allows HTTPS (port 443)" -ForegroundColor White
    Write-Host ""
    exit 1
    
} catch [System.Management.Automation.MethodInvocationException] {
    Write-Host "[ERROR] API Authentication Failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Verify APIKey is valid" -ForegroundColor White
    Write-Host "  - Verify APISecret is valid" -ForegroundColor White
    Write-Host "  - Check API credentials have Manage Prevention Rules permission" -ForegroundColor White
    Write-Host "  - Regenerate credentials in Cortex XDR console if needed" -ForegroundColor White
    Write-Host ""
    exit 1
    
} catch {
    Write-Host "[ERROR] Unexpected Error" -ForegroundColor Red
    Write-Host ""
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Category: $($_.CategoryInfo.Category)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Full Exception:" -ForegroundColor Yellow
    Write-Host $_ -ForegroundColor White
    Write-Host ""
    exit 1
}
