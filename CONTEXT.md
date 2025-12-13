# Project Context: Host Evidence Runner (HER)

## 1. Project Overview & Mission
**Host Evidence Runner (HER)** is a lightweight, standalone forensic acquisition utility for Windows endpoints. It is designed to be deployed on "live" systems (including legacy and air-gapped environments) to rapidly preserve volatile data and disk artifacts without requiring installation.

*   **Origin:** This project is a "De-Cadoized" fork of the archived `Cado-Batch` repository.[1, 2]
*   **Goal:** To serve as a professional portfolio piece demonstrating Digital Forensics and Incident Response (DFIR) competence, specifically focusing on tool maintenance, governance, and forensic integrity.
*   **Operational Mode:** The script runs from a USB drive or network share, copies specific artifacts using native Windows binaries and bundled tools (e.g., `RawCopy`, `7za`), and compresses them into a timestamped zip file.

## 2. Governance & Legal Protocols (Apache 2.0)
This project operates under the **Apache License 2.0**. Strict adherence to licensing and trademark rules is required to maintain the legitimacy of the fork.[3, 4]

*   **Attribution:** The original `LICENSE` file from Cado Security must be preserved. A new `NOTICE` file or header section must track modifications.
*   **Trademark "De-Cadoing":**
    *   **Prohibited:** Do not use the terms "Cado," "Cado Response," or "Darktrace" in user-facing output, file names, or new documentation .
    *   **Allowed:** These terms are permitted *only* in the license attribution block to credit the original authors.
*   **Sanitization:** Ensure no proprietary metadata files (e.g., `metadata.json` formatted specifically for Cado's cloud platform) are generated. Output should be generic and tool-agnostic (e.g., plain `.zip` ingestible by Autopsy or KAPE).[5, 6]

## 3. Technical Architecture & Constraints

### 3.1. Language & Runtime
*   **Language:** Windows Batch Script (`.bat` / `.cmd`).
*   **Target OS:** Windows 7 through Windows 11 (including Server variants).
*   **Dependencies:** Must remain "Dependency Free." Do not rely on PowerShell, Python, or.NET being installed unless the script verifies their existence first. Rely on bundled binaries in the `\resources` folder.

### 3.2. Output Standardization
*   **Dynamic Naming:** Output files must use the format `HER_%HOSTNAME%_%YYYY-MM-DD_HHMM%.zip` to prevent evidence collision in multi-host investigations.[7]
*   **Logging:** All script actions (success/failure) must be logged to a local text file `acquisition_log.txt` within the output directory for auditability.

### 3.3. Directory Structure
Host-Evidence-Runner/
├── LICENSE                    (Apache 2.0 Text - DO NOT MODIFY)
├── README.md                  (Project Documentation)
├── host_evidence_runner.bat   (Main Logic)
├── docs/                      (Artifact documentation)
└── resources/                 (External binaries)
    ├── 7za.exe                (7-Zip CLI)
    └── RawCopy.exe            (For locked files)

## 4. Forensic Artifact Objectives
Copilot should assist in writing logic to collect the following high-value artifacts, prioritizing **Raw Copy** methods for locked files :

| Artifact | Path/Source | Forensic Value |
| :--- | :--- | :--- |
| **$MFT** | `\$MFT` | File existence, timestamp manipulation (timestomping), deleted file recovery. |
| **Event Logs** | `\Windows\System32\winevt\Logs\*.evtx` | Login history (4624), Service installation (7045), PowerShell execution (4104). |
| **Registry Hives** | `SAM`, `SYSTEM`, `SOFTWARE`, `SECURITY` | User accounts, USB history, Persistence mechanisms (Run keys). |
| **Prefetch** | `\Windows\Prefetch\*.pf` | Proof of execution (what programs were run). |
| **$UsnJrnl** | `\$Extend\$UsnJrnl` | File modification history (rapid ransomware activity detection). |

## 5. Coding Guidelines for Copilot
*   **Safety:** Always check if a destination directory exists before copying.
*   **Silence:** Use `>NUL 2>&1` to suppress output for non-critical commands to keep the console clean for the investigator.
*   **Error Handling:** If a critical binary (e.g., `7za.exe`) is missing, the script should alert the user and exit gracefully rather than continuing and failing silently.
*   **Comments:** Comment extensively explaining the *forensic relevance* of the artifact being collected (e.g., "Collecting Prefetch to analyze execution history").

***

### References for Context
*   *Based on Cado-Batch (Archived)* [1, 2]
*   *Licensing: Apache 2.0* [3]
*   *Artifact Scope: Standard Windows Forensic Artifacts* [7, 8]