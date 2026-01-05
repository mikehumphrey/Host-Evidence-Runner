# How to Configure CA Permissions for Code Signing

If you are a Local Administrator on the Certificate Authority (CA) server, you can configure the necessary permissions and templates to allow yourself to request a Code Signing certificate.

## Step 1: Configure the Certificate Template

1.  Log in to the CA server.
2.  Press `Win + R`, type `certtmpl.msc`, and press Enter. This opens the **Certificate Templates Console**.
3.  Locate the **Code Signing** template in the list.
    *   *Note: If you don't see it, you may need to duplicate an existing template (like "User") and change its "Application Policies" to "Code Signing".*
4.  Right-click **Code Signing** and select **Properties**.
5.  Go to the **Security** tab.
6.  Click **Add...** and enter your user account (or a group you belong to).
7.  With your user selected, check the **Allow** box for:
    *   **Read**
    *   **Enroll**
8.  Click **OK**.

## Step 2: Publish the Template to the CA

Even if the template exists, the CA won't issue certificates against it unless it is "Published" (Issued).

1.  Press `Win + R`, type `certsrv.msc`, and press Enter. This opens the **Certification Authority** snap-in.
2.  Expand your CA name.
3.  Click on the **Certificate Templates** folder.
4.  Check if **Code Signing** is in the list on the right.
    *   **If it IS listed:** You are good to go.
    *   **If it is NOT listed:**
        1.  Right-click the **Certificate Templates** folder.
        2.  Select **New** > **Certificate Template to Issue**.
        3.  Select **Code Signing** from the list and click **OK**.

## Step 3: Verify CA Access Permissions (Optional)

If you still get permission errors, check the CA's general access settings.

1.  In `certsrv.msc`, right-click the CA name (top level) and select **Properties**.
2.  Go to the **Security** tab.
3.  Ensure **Authenticated Users** (or your specific user) has the **Request Certificates** permission set to **Allow**.

## Step 4: Retry the Request

Go back to the web interface (`https://<ca-server>/certsrv`) or use the command line to submit your request again.

**Important:** You must specify the template name when submitting via command line.

```cmd
certreq -submit -attrib "CertificateTemplate:CodeSigning" code_signing.req
```
