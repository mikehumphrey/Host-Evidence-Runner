# Sysadmin End-User Deployment Guide

**For Administrators: Print this or save to your computer**

---

## Quick Start (3 Simple Steps)

### Step 1: Prepare the USB Drive
- [ ] Copy the entire `Cado-Batch` folder to your USB drive
- [ ] USB folder structure should look like:
  ```
  USB Drive\Cado-Batch\
    ├── RUN_ME.bat
    ├── collect-server.ps1
    ├── logs\
    ├── bins\
    └── README.md
  ```

### Step 2: Run on the Server
1. **Connect USB to the server**
2. **Open File Explorer** → Navigate to USB drive
3. **Double-click `RUN_ME.bat`** (Windows will ask for permission, click "Yes")
4. **Wait** - A window will open showing collection progress
5. **See "Collection Complete!" message** when finished
6. **USB will contain output folder** with all collected data

### Step 3: Return Data to Analyst
- [ ] Disconnect USB drive from server
- [ ] Connect to your computer
- [ ] Copy the `collected_files_[ServerName]_[Date]` folder back to analyst
- [ ] Include the `FORENSIC_COLLECTION_LOG.txt` file

---

## What This Tool Does

This forensic collection tool gathers diagnostic and security information from your server including:
- System configuration and event logs
- File system metadata
- Active Directory information (if applicable)
- Network configuration
- Registry settings
- Temporary files and recent activity

**Total Data Size:** ~500MB to 5GB depending on server configuration
**Runtime:** 15-30 minutes (depends on server size/activity)

---

## Troubleshooting

### "Access Denied" or "Administrator Required" Error
**Solution:**
1. Close the window
2. Right-click on `RUN_ME.bat`
3. Select "Run as administrator"
4. Click "Yes" when Windows asks for permission

### The window closes too quickly
**Solution:**
1. Open Command Prompt as Administrator
2. Navigate to USB drive: `D:\` (or your USB letter)
3. Type: `cd Cado-Batch`
4. Type: `RUN_ME.bat`
5. Read any error messages shown

### "PowerShell is disabled" Error
**Solution:**
1. Contact your IT department - PowerShell execution policy may be restricted
2. They may need to allow execution for this collection

### Collection Takes Too Long (>1 hour)
**Solution:**
1. This is normal on very large servers
2. Do not close the window - let it complete
3. Server performance may be temporarily affected - it's safe
4. Completion will be announced when done

### Antivirus Warning
**Solution:**
1. The collection tool is legitimate and safe
2. It performs read-only operations only
3. You may need to add the USB drive to antivirus exclusions
4. Contact your IT department if antivirus blocks execution

---

## Output Files

After collection completes, you'll see a folder named like:
```
collected_files_DC01_20251212_143022
├── System/                          (System files and registry)
├── ActiveDirectory/                 (AD database and logs, if applicable)
├── DNS/                            (DNS zones and config, if applicable)
├── DFS/                            (DFS metadata, if applicable)
├── CA/                             (Certificate data, if applicable)
└── ExecutionLog.txt                (Details of what was collected)
```

**All output is read-only forensic data. It is safe to handle and return.**

---

## FAQ

**Q: Does this affect my server or running applications?**
A: No. The tool performs read-only operations only. No files are modified.

**Q: Can I use the server while this runs?**
A: Yes. The server continues normal operation. Collection happens in the background.

**Q: What if the script fails partway through?**
A: Check `FORENSIC_COLLECTION_LOG.txt` for error details. All successfully collected data is preserved.

**Q: Does this require network connectivity?**
A: No. The tool works completely offline/locally on the server.

**Q: Can I cancel the collection?**
A: Yes. Close the window. Any data already collected is preserved.

**Q: What should I do with the collected data?**
A: Return the entire output folder and the log file to the analyst who gave you this tool.

---

## Support

If you encounter issues:
1. **Keep the `FORENSIC_COLLECTION_LOG.txt` file** - it contains error details
2. **Note the error message** shown in the window
3. **Contact the analyst** with:
   - The error message
   - The contents of `FORENSIC_COLLECTION_LOG.txt`
   - Your server name and role (DC, DNS, File Server, etc.)

---

## System Requirements

- Windows Server 2016 or newer
- Administrator access
- USB drive with at least 10GB free space (or server data size)
- ~30 minutes of runtime
- No specific PowerShell version required

---

**Version:** 1.0  
**Last Updated:** December 12, 2025
