#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Silent launcher for Host Evidence Runner (HER).
    Collects to %Temp%, exfiltrates to Analyst Workstation/Share, and self-cleans.

.DESCRIPTION
    Designed for stealth/remote execution.
    1. Hides the console window.
    2. Sets output to $env:TEMP\HER_Collection_[Timestamp]
    3. Invokes source\collect.ps1
    4. Transfers to -AnalystWorkstation (Hostname or UNC)
    5. Deletes local artifacts after transfer.

.PARAMETER AnalystWorkstation
    [Mandatory] Hostname or UNC Path (\\Server\Share) to receive the evidence.

.PARAMETER NoZip
    Skip compression.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$AnalystWorkstation,

    [Parameter(Mandatory=$false)]
    [switch]$NoZip
)

# 1. Hide Window (Best effort)
try {
    $definition = @"
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
"@
    $win32 = Add-Type -MemberDefinition $definition -Name "Win32ShowWindow" -Namespace Win32Functions -PassThru -ErrorAction SilentlyContinue
    if ($win32) {
        $hwnd = $win32::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero) {
            $win32::ShowWindow($hwnd, 0) # 0 = SW_HIDE
        }
    }
} catch {
    # Ignore hiding errors
}

$ErrorActionPreference = 'Continue'

# 2. Resolve Root
$root = $null
if ($PSCommandPath) { $root = Split-Path -Parent $PSCommandPath }
elseif ($PSScriptRoot) { $root = $PSScriptRoot }
else { $root = Get-Location }

if (-not (Test-Path $root)) {
    exit 1
}

Set-Location -Path $root

# 3. Define Temp Output
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tempDir = Join-Path $env:TEMP "HER_Collection_$timestamp"

# 4. Execute Collection
$collectScript = Join-Path $root "source\collect.ps1"

# Build parameters hashtable
$params = @{
    AnalystWorkstation = $AnalystWorkstation
    OutputDirectory    = $tempDir
    DeleteAfterTransfer = $true
}

if ($NoZip) {
    $params['NoZip'] = $true
}

try {
    # Run the collector
    & $collectScript @params
} catch {
    # Fallback logging
    $errLog = Join-Path $env:TEMP "HER_Silent_Error_$timestamp.txt"
    "Error executing silent collection: $_" | Out-File $errLog
}
