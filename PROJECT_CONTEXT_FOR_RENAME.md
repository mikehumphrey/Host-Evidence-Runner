# Project Context (for renaming decision)

## What this project is
- Purpose: Windows host forensic/evidence collector (PowerShell-first) for sysadmins to run locally (USB/C:\temp) and produce `collected_files` + logs + optional hash/signature outputs.
- Heritage: Fork/modernization of the archived "Cado-Batch" project; no ongoing upstream support. There is a commercial product "Cado Host" (exe/SaaS upload) that is separate. Current repo is independently maintained.
- Audience: Sysadmins/IR responders who need a one-step collector with minimal dependencies.

## Core entry points
- `source/collect.ps1`: Main collector. Requires Admin. Resolves tools from a single `tools\bins` (or `source\bins` if present). Produces `source/collected_files/` and logs under `source/logs/`.
- `run-collector.ps1`: One-step launcher from release root; calls `source/collect.ps1` with ExecutionPolicy Bypass.
- `RUN_COLLECT.bat`: Batch wrapper for environments with restrictive PowerShell policies.

## Build pipeline
- Script: `Build-Release.ps1`.
- Output: `releases/<timestamp>/` plus zip `releases/Cado-Batch-Collector.zip` (ignored by git).
- Contents in release: `run-collector.ps1`, `RUN_COLLECT.bat`, `source/collect.ps1`, `source/collect.bat`, `source/RUN_ME.bat`, `tools/bins/*`, `templates/*`, `README.md`.
- Signing: Optional (`-Sign`) using available code-signing cert; otherwise skipped.
- Zip: Optional (`-Zip`).

## Tooling/binaries
- Live under `tools/bins` (single copy expected). Key tools used:
  - `RawCopy.exe` (locked-file copy for MFT, $LogFile, $UsnJrnl, SRUM, Amcache).
  - `hashdeep.exe` (SHA256 manifest), `sigcheck.exe`, `strings.exe`.
- `collect.ps1` resolves bins via helper: checks `source/bins` then `../tools/bins` then `../bins`; throws clearly if missing.

## Behavior highlights
- Creates timestamped log: `source/logs/forensic_collection_<HOST>_<timestamp>.txt`.
- Outputs `collected_files` with NTFS metadata, event logs, registry hives, browser history, temp dirs, USB/WiFi/RDP info, etc.
- Phase 1: hash manifest, sigcheck, strings (when tools present).
- Phase 2: optional parsing helpers (SRUM, Amcache, prefetch analysis) using RawCopy if available.
- Minimal dependencies: stock PowerShell 5.1+, admin rights; optional external runtimes only for optional tools (Zimmerman, etc., not shipped in release).

## Current naming/branding touchpoints to change if rebranding
- Repo name: `Cado-Batch`.
- Release zip name: `Cado-Batch-Collector.zip` (set in `Build-Release.ps1`).
- README title: "Cado Evidence Collector".
- Inline comments/banners: `run-collector.ps1` synopsis references "Cado-Batch"; `collect.ps1` banner is generic ("Forensic Collection Tool").
- Docs in root mentioning Cado (e.g., `CADO_HOST_ANALYSIS_AND_RECOMMENDATIONS.md`, `PROJECT_STRUCTURE.md`, etc.).

## Proposed rename steps (high level)
1) Choose new name (project + release zip + doc titles). Keep a short attribution line: "Derived from the archived Cado-Batch project; independently maintained." 
2) Update: README title/first paragraph; `Build-Release.ps1` zip name; `run-collector.ps1` synopsis; any doc filenames/headers that carry "Cado" branding.
3) Tag current state (last Cado-branded) then cut first release under new name to give users a clean switch.

## Name candidates (short list)
- Forensic QuickCollect
- Rapid Response Collector
- Host Evidence Runner
- Evidence Lift
- HostSweep Collector
- TraceKit Collector

## Notes for LLM prompt (Gemini)
- Goal: suggest/choose a new project name that avoids confusion with the commercial "Cado Host" product and reflects a lightweight, sysadmin-friendly Windows forensic collector.
- Constraints: Windows-focused, offline-capable, single-folder release with `tools/bins` only; avoid implying SaaS/upload; emphasize reliability and clarity for non-forensics admins.
- Tone: professional, incident-response oriented, not vendor-specific.
