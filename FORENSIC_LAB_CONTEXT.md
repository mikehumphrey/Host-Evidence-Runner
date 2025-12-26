# Forensic Lab Environment Context

## Origin
This environment was provisioned using the `LaptopSetup` automation suite for the Lenovo Legion Pro 7 Gen 10. This document provides context for AI agents working within this environment to understand available tools, paths, and configurations.

## System Specifications
*   **Host**: Lenovo Legion Pro 7 Gen 10 (16AFR10H)
*   **CPU**: AMD Ryzen 9 9955HX3D (16C/32T)
*   **GPU**: NVIDIA RTX 5080 (16GB GDDR7)
*   **RAM**: 64GB DDR5
*   **OS**: Windows 11 Enterprise
*   **Subsystem**: WSL2 (Ubuntu, Kali Linux)

## Installed Toolset

### 1. Forensics & Security
*   **Velociraptor**: 
    *   Binary Path: `C:\Tools\velociraptor.exe`
    *   Status: In system PATH.
*   **Chainsaw**: 
    *   Binary Path: `C:\Tools\chainsaw\chainsaw_x86_64-pc-windows-msvc\chainsaw.exe`
    *   Status: In system PATH.
*   **Plaso (log2timeline)**: 
    *   Implementation: Docker Container (`log2timeline/plaso:latest`)
    *   PowerShell Aliases: `log2timeline`, `pinfo`, `psort`
    *   Execution: Aliases automatically mount `${PWD}` to `/data` inside the container.
*   **Network Tools**: Wireshark, Nmap (Installed via WinGet).

### 2. AI & Data Processing
*   **Python**: Python 3.11+ (User Scope).
*   **CUDA Toolkit**: Version 12.x installed.
*   **Libraries**:
    *   PyTorch (with CUDA 12.1 support)
    *   TensorFlow
    *   Hugging Face Transformers
    *   Pandas, NumPy, Jupyter
*   **Hardware Acceleration**: NVIDIA RTX 5080 available for inference and training.

### 3. Infrastructure & Containerization
*   **Container Runtime**: Rancher Desktop (Dockerd/Moby backend).
*   **Orchestration**: Kubernetes (K3s).
    *   Active Context: `rancher-desktop`
*   **IaC**: Terraform, Pulumi.

## Integration Guide for Automation Scripts

### PowerShell Integration
*   **Calling Binaries**: Tools in `C:\Tools` are in the global PATH and can be invoked directly.
    ```powershell
    # Example: Running Chainsaw
    chainsaw hunt --mapping mappings/sigma-event-logs --rules rules/ ...
    ```
*   **Calling Plaso**: Use the aliases defined in `$PROFILE`.
    ```powershell
    # Example: Processing an image
    log2timeline timeline.plaso evidence.dd
    ```

### Python Integration
*   **Subprocess Calls**: When calling forensic tools from Python, assume they are in the PATH.
    ```python
    import subprocess
    subprocess.run(["velociraptor", "query", ...])
    ```
*   **GPU Access**:
    ```python
    import torch
    # Verify GPU availability
    device = "cuda" if torch.cuda.is_available() else "cpu"
    ```

### WSL2 Interoperability
*   **Distributions**: `Ubuntu` (General Dev), `kali-linux` (Security/Pen-testing).
*   **Cross-OS Access**: 
    *   Windows tools accessible from WSL via `/mnt/c/Tools/`.
    *   Windows drives mounted at `/mnt/c/`.
