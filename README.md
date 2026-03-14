# Reinstall CrowdStrike Falcon Sensor

A PowerShell script that automates the uninstall and reinstall of the CrowdStrike Falcon sensor on Windows endpoints via Real-Time Response (RTR). This is useful when a Falcon agent has fallen off, become unresponsive, or needs a clean reinstall without manual intervention.

## How It Works

1. Reads the host's Falcon Agent ID (AID) from the local registry
2. Authenticates to the CrowdStrike API using OAuth2 client credentials
3. Retrieves the maintenance (uninstall) token for the specific host
4. Quietly uninstalls the existing Falcon sensor using the token
5. Automatically reinstalls the sensor once removal completes

## Prerequisites

- **Windows endpoint** with the Falcon sensor currently installed (even if unhealthy)
- **CrowdStrike API credentials** — see [Step 1: Create a CrowdStrike API Client](#step-1-create-a-crowdstrike-api-client) below
- **Falcon sensor installer** (`WindowsSensor.exe`) pre-staged on the endpoint (default path: `C:\Temp\WindowsSensor.exe`)
- **Administrative privileges** on the target machine
- **Your CrowdStrike Customer ID (CID)** — found in the Falcon console under **Host setup and management > Deploy > Sensor downloads**

---

## Setup Instructions

### Step 1: Create a CrowdStrike API Client

You need to create an API client in the Falcon console to generate the Client ID and Client Secret used by this script.

1. Log in to the [CrowdStrike Falcon Console](https://falcon.crowdstrike.com/)
2. Navigate to **Support and resources > API clients and keys** (or go to **Support > API Clients and Keys** depending on your console version)
3. Click **Create API client**
4. Fill in the details:
   - **Client Name**: Give it a descriptive name (e.g., `Falcon Reinstall Script`)
   - **Description**: Optional — e.g., `Used for automated sensor reinstall via RTR`
5. Assign the following **API scopes** (these are the minimum permissions required):

   | Scope                        | Permission |
   |------------------------------|------------|
   | **Hosts**                    | Read       |
   | **Sensor update policies**   | Read       |
   | **Maintenance Token** (listed as *Reveal uninstall token*) | Read |

   > **Important:** Do not grant more permissions than necessary. This follows the principle of least privilege.

6. Click **Create**
7. You will be shown your **Client ID** and **Client Secret** — **copy both immediately**. The Client Secret is only displayed once. If you lose it, you will need to create a new API client.

### Step 2: Find Your CID

1. In the Falcon console, go to **Host setup and management > Deploy > Sensor downloads**
2. Your **Customer ID (CID)** is displayed at the top of the page, including the checksum (e.g., `ABCDEF1234567890ABCDEF1234567890-12`)
3. Copy the full CID value (including the two-digit checksum after the hyphen)

### Step 3: Download the Sensor Installer

1. On the same **Sensor downloads** page, download the latest **Windows sensor installer** (`WindowsSensor.exe`)
2. Place the installer on the target endpoint at `C:\Temp\WindowsSensor.exe` (or update the path in the script to match your chosen location)

### Step 4: Configure the Script

Open `uninstall_crowdstrike_force.ps1` and update the user config section at the top of the script with the values you gathered:

```powershell
$Hostname      = "https://api.crowdstrike.com"                          # API base URL — change if your tenant is in a different cloud (see table below)
$Id            = 'your_client_id_here'                                   # Paste your Client ID from Step 1
$Secret        = 'your_client_secret_here'                               # Paste your Client Secret from Step 1
$InstallerPath = 'C:\Temp\WindowsSensor.exe'                             # Path where you placed the installer in Step 3
$InstallArgs   = '/install /quiet /norestart CID=your_full_CID_here'     # Replace with your CID from Step 2
```

**Example** (with fake values):
```powershell
$Id          = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4'
$Secret      = 'X9y8Z7w6V5u4T3s2R1q0P9o8N7m6L5k4'
$InstallArgs = '/install /quiet /norestart CID=ABCDEF1234567890ABCDEF1234567890-12'
```

### CrowdStrike Cloud Regions

Set `$Hostname` to match your CrowdStrike tenant's cloud region:

| Cloud    | API Base URL                              |
|----------|-------------------------------------------|
| US-1     | `https://api.crowdstrike.com`             |
| US-2     | `https://api.us-2.crowdstrike.com`        |
| EU-1     | `https://api.eu-1.crowdstrike.com`        |
| US-GOV-1 | `https://api.laggar.gcw.crowdstrike.com`  |

> **Tip:** If you're unsure which cloud your tenant is on, check the URL in your browser when logged into the Falcon console, or ask your CrowdStrike administrator.

---

## Usage

### Step 5: Run the Script

#### Option A: Running via RTR (Real-Time Response)

1. Stage `WindowsSensor.exe` on the target host (e.g., use RTR `put` to drop it to `C:\Temp\`)
2. Run the script through an RTR session:

```
runscript -CloudFile="uninstall_crowdstrike_force" -Timeout=120
```

#### Option B: Running Locally

```powershell
.\uninstall_crowdstrike_force.ps1
```

> **Note:** The script must be run with administrative privileges. The endpoint will briefly lose sensor coverage during the reinstall window.

---

## Troubleshooting

| Error Message | Cause | Fix |
|---|---|---|
| `API credentials not configured in script` | `$Id` or `$Secret` still has placeholder values | Replace with your actual Client ID and Secret from Step 1 |
| `Unable to locate WindowsSensor.exe` | Installer not found at the path specified in `$InstallerPath` | Verify the installer is staged at the correct path on the endpoint |
| `Unable to request token` | API authentication failed | Verify your Client ID, Secret, and `$Hostname` are correct for your cloud region |
| `Unable to retrieve uninstall token` | API call succeeded but the token request failed | Confirm the API client has the **Maintenance Token (Reveal uninstall token)** Read scope |
| `QuietUninstallString not found` | Falcon sensor is not installed or registry entry is missing | The sensor may already be fully uninstalled — proceed with a fresh install instead |

---

## Security Considerations

- **Do not commit real API credentials** into the script. If forking this repo, add the `.ps1` file to `.gitignore` after configuring it, or use environment variables / a secrets manager.
- The API Client Secret and uninstall maintenance token are sensitive — restrict access to this script accordingly.
- Use the minimum required API scopes when creating your OAuth2 client.
- Consider revoking or rotating the API client credentials after use if this is a one-time operation.

## License

This project is provided as-is for use by IT and security teams managing CrowdStrike Falcon deployments.
