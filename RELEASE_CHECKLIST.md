# Release Workflow Checklist

Use this checklist to ensure quality and consistency before creating a new release of Host Evidence Runner (HER).

## 1. Development & Testing
- [ ] **Code Freeze**: Ensure all feature branches are merged.
- [ ] **Silent Run Test**:
    - Run: `.\run-silent.ps1 -AnalystWorkstation "localhost"`
    - Verify:
        - Console window hides.
        - Files appear in `C:\Temp\Investigations\`.
        - Files are deleted from `%Temp%`.
- [ ] **Standard Collection Test**:
    - Run: `.\run-collector.ps1 -AnalystWorkstation "localhost"`
    - Verify:
        - Console shows progress.
        - Files appear in `C:\Temp\Investigations\`.
- [ ] **Unit Tests**:
    - Run: `.\Test-AnalystWorkstation.ps1 -AnalystWorkstation "localhost"`
    - Run: `.\Test-AnalystWorkstation.ps1 -AnalystWorkstation "\\Server\Share"` (Verify UNC detection)

## 2. Documentation Review
- [ ] **README.md**: Verify "Quick Start" and "Features" match the code.
- [ ] **RELEASE_NOTES.md**:
    - Add a new section for the upcoming version (e.g., `## Version 1.1.1`).
    - List new features (e.g., Silent Mode, UNC Support).
    - List bug fixes.
- [ ] **Sysadmin Guides**: Check `docs/sysadmin/` for outdated instructions.

## 3. Version Increment
- [ ] **Decide Version**: Follow Semantic Versioning (Major.Minor.Patch).
- [ ] **Update RELEASE_NOTES.md**:
    - Update the top metadata block:
      ```markdown
      - **Version**: 1.1.1
      - **Release Date**: January 02, 2026
      ```
    - *Note: The build script can auto-increment the patch version, but manual update is safer for major/minor changes.*

## 4. Build & Release
- [ ] **Run Build Script**:
    ```powershell
    # For GitHub Release (Versioned)
    .\Build-GitHubRelease.ps1 -Version "1.1.1" -CreateTag
    ```
    *Or for local testing:*
    ```powershell
    .\Build-Release.ps1 -Zip
    ```
- [ ] **Verify Artifacts**:
    - Check `releases/v1.1.0/` (or timestamped folder).
    - Ensure `run-silent.ps1` is present.
    - Ensure `HER-v1.1.0.zip` is created.

## 5. Publish
- [ ] **Push to GitHub**:
    ```powershell
    git push origin main
    git push origin v1.1.0
    ```
- [ ] **Create GitHub Release**:
    - Go to GitHub > Releases > New.
    - Select Tag: `v1.1.0`.
    - Title: `Host Evidence Runner v1.1.0`.
    - Description: Paste contents of `releases/v1.1.0/GITHUB_RELEASE_NOTES.txt`.
    - Upload: `releases/HER-v1.1.0.zip`.
    - Publish.

## 6. Post-Release
- [ ] **Announce**: Notify team/users of the new release.
- [ ] **Cleanup**: Remove local test artifacts from `C:\Temp\Investigations`.
