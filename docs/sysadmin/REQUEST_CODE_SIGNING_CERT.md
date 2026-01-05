# How to Request a Code Signing Certificate (Manual CSR Method)

If your internal Certificate Authority (CA) does not have a "Code Signing" template published in the web interface, you can generate a request manually using `certreq.exe` and submit it.

## Step 1: Create the Request Configuration File

1. Create a new file named `code_signing.inf` on your computer.
2. Paste the following content into it (update the `Subject` line as needed):

```ini
[Version]
Signature="$Windows NT$"

[NewRequest]
; UPDATE THIS LINE:
Subject = "CN=HER Code Signing, O=Municipality of Anchorage, C=US"
KeyLength = 2048
KeySpec = 1
KeyUsage = 0xA0
MachineKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
RequestType = PKCS10

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.3 ; This OID identifies the cert as valid for Code Signing
```

## Step 2: Generate the Certificate Signing Request (CSR)

1. Open a Command Prompt or PowerShell.
2. Navigate to the folder where you saved `code_signing.inf`.
3. Run the following command:

```cmd
certreq -new code_signing.inf code_signing.req
```

This will create a file named `code_signing.req`. This is your Base-64 encoded request.

## Step 3: Submit the Request to the CA

### Option A: Via Web Interface
1. Go to your CA's web interface (usually `https://<ca-server>/certsrv`).
2. Select **"Request a certificate"**.
3. Select **"advanced certificate request"**.
4. Select **"Submit a certificate request by using a base-64-encoded CMC or PKCS #10 file..."**.
5. Open `code_signing.req` in Notepad and copy the entire content.
6. Paste it into the **"Saved Request"** box on the webpage.
7. For **"Certificate Template"**, select "Code Signing" if available in the dropdown.
8. Click **Submit**.

### Option B: Via Command Line (Recommended)
If the web interface gives permission errors or doesn't show the template, use the command line:

```cmd
certreq -submit -attrib "CertificateTemplate:CodeSigning" code_signing.req her_signing.cer
```

*Note: "CodeSigning" is the default internal name. If your admin renamed it (e.g., "MOA Code Signing"), use that name instead (no spaces usually).*

## Step 4: Download and Install the Certificate

**If you used Option A (Web):**
1. Once issued, select **"Base 64 encoded"** and click **"Download certificate"**.
2. Save the file as `her_signing.cer`.

**Then (for both options):**
3. In your Command Prompt/PowerShell (same folder as before), run:

```cmd
certreq -accept her_signing.cer
```

This pairs the public certificate with the private key generated in Step 2 and installs it into your **Current User > Personal** store.

## Step 5: Verify

Run this PowerShell command to see if it's available for signing:

```powershell
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert
```
