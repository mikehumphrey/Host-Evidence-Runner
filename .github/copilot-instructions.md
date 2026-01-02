# Host Evidence Runner (HER) - AI Developer Instructions

## Project Overview
**HER** is a PowerShell-based forensic evidence collection and analysis toolkit for Windows.
- **Core Logic:** `source/collect.ps1` (Collection), `source/Analyze-Investigation.ps1` (Analysis).
- **Launchers:** `run-collector.ps1` (PowerShell), `RUN_COLLECT.bat` (Batch).
- **Modules:** `modules/` (CadoBatchAnalysis, ChainsawAnalysis, AIAnalysis).

## Critical Architecture & Patterns

### 1. Path Handling (CRITICAL)
- **ALWAYS** use `SafeJoinPath` (in `collect.ps1`) or `Join-Path` with robust checks.
- **NEVER** assume paths are short. Handle `MAX_PATH` (260 chars) by using `robocopy` for deep structures (e.g., User Profiles).
- **NEVER** hardcode tool paths. Use `Get-BinFile "tool.exe"` to resolve 32/64-bit versions from `tools/bins/`.

### 2. Execution & Resilience
- **Non-Interactive:** Scripts must run without user input (`$ProgressPreference = "SilentlyContinue"`).
- **Error Handling:** `$ErrorActionPreference = "Continue"`. Log errors via `Write-Log` and proceed. Fatal errors are rare; prefer partial collection over failure.
- **Elevation:** Scripts require Administrator privileges (`#Requires -RunAsAdministrator`).

### 3. Logging Standard
- Use `Write-Log "Message" -Level Info|Warning|Error`.
- Log to both console (colored) and file (`forensic_collection_*.txt`).
- Timestamps: `yyyyMMdd_HHmmss` format consistently.

### 4. Tool Resolution Strategy
- Tools live in `tools/bins/`.
- Scripts auto-resolve paths: `source/bins` → `tools/bins` → `bins/`.
- **Do not** commit binaries to `source/`.

## Development Workflows

### Building & Releasing
- Run `.\Build-Release.ps1 -Zip` to generate `releases/<timestamp>/`.
- This packages only runtime-essential files (excludes tests/docs).

### Testing
- **Local Collection:** `.\run-collector.ps1 -AnalystWorkstation "localhost" -NoZip`
- **Unit Tests:** `tests/Test-AnalystWorkstation.ps1`.
- **Analysis Test:** `.\Lab-Analyze.ps1 -InvestigationPath "..."`

### Analysis Modules
- **CadoBatchAnalysis:** Core parsing (EventLogs, MFT, Registry).
- **ChainsawAnalysis:** Fast event log triage (requires external binary).
- **AIAnalysis:** Anomaly detection.

## Key Files
- `source/collect.ps1`: Main collection engine (monolith).
- `source/Analyze-Investigation.ps1`: Analysis entry point.
- `Lab-Analyze.ps1`: Advanced analysis wrapper (Chainsaw + AI).
- `Build-Release.ps1`: Release packaging logic.

