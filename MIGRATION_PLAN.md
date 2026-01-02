# Project Migration Plan: OneDrive to Local Storage

## Problem
The current project location inside OneDrive causes several issues:
1.  **Log Bloat:** OneDrive sync logs (`AppData\Local\Microsoft\OneDrive\logs`) grow exponentially as the collector runs.
2.  **Performance:** OneDrive file locking slows down builds and collection tests.
3.  **Path Limits:** Deep OneDrive paths (`C:\Users\...\OneDrive - Municipality...`) consume ~50 chars of the 260-char limit, causing `MAX_PATH` errors.
4.  **Symlink Confusion:** `C:\Dev` is currently a symlink pointing back to OneDrive, masking the issue.

## Solution
Move the active development environment to a dedicated local directory: `C:\Source\Host-Evidence-Runner`.

## Migration Steps

### 1. Execute Migration
Run the automated migration script:
```powershell
.\Migrate-To-Local.ps1
```
This script will:
*   Create `C:\Source\Host-Evidence-Runner`.
*   Copy all source code and tools.
*   **Exclude** heavy build artifacts (`investigations/`, `releases/`) and temporary environments (`.venv/`).
*   Update the VS Code workspace file to fix relative paths.

### 2. Switch Environments
1.  Close the current VS Code window.
2.  Run `OPEN_NEW_LOCATION.bat` (created by the migration script).
3.  Trust the new folder if prompted.

### 3. Verify New Environment
In the new window (`C:\Source\Host-Evidence-Runner`):
1.  **Check Git:** Ensure git history is preserved (`git log`).
2.  **Test Collection:**
    ```powershell
    .\run-collector.ps1 -AnalystWorkstation "localhost" -Verbose
    ```
3.  **Test Build:**
    ```powershell
    .\Publish-Release-Local.ps1
    ```

### 4. Cleanup (Optional)
Once you are confident in the new location:
1.  Archive the old OneDrive folder (e.g., rename to `Host-Evidence-Runner_OLD`).
2.  Delete the `C:\Dev` symlink if you wish to reclaim that path for real local folders:
    ```cmd
    rmdir C:\Dev
    mkdir C:\Dev
    ```

## Future Workflow
*   **Code:** Exists in `C:\Source\Host-Evidence-Runner`.
*   **Backup:** Use `git push` to GitHub/Azure DevOps. Do not rely on OneDrive for code backup.
*   **Documents:** Keep non-code documentation in OneDrive if needed, but the repo docs should stay with the code.
