# Troubleshooting Windows Firewall + Docker NAT Issues on ArcGIS Notebook Server

**Last Updated:** January 2026  
**Author:** Joel McCune, Sr. Technical Consultant

***

## Overview

When running **ArcGIS Notebook Server** on Windows Server (2022+), Docker containers may start successfully, yet the Notebook Server cannot reach the Jupyter service inside the container (default port **8888**).

A common root cause is that Docker’s **NAT network adapter** is assigned to the **Public firewall profile**, and the organization applies **CIS Benchmark policies** that cause the Public profile to **ignore locally created firewall rules**. When this happens, manually created firewall rules **never take effect**, and connectivity fails until a **GPO‑delivered allow rule** is deployed.

This KB provides a repeatable diagnostic and remediation workflow.

***

## What CIS Benchmarks Are

The **Center for Internet Security (CIS)** publishes widely adopted **security baselines** for operating systems and applications.

🔗 <https://www.cisecurity.org/cis-benchmarks/>

For Windows Server, CIS Benchmarks often enforce:

*   Ignoring locally created firewall rules on the **Public** profile
*   Mandatory use of centrally managed **GPO firewall rules**
*   Highly restrictive inbound policy defaults
*   Alignment with NIST, ISO 27001, and Zero Trust frameworks

If your organization implements CIS Level 1 or Level 2 benchmarks, local firewall rules may not apply, and only GPO-sourced rules will be honored.

***

## What GPO Firewall Rules Are

A **Group Policy Object (GPO)** is a centrally managed configuration package distributed through **Active Directory**.

A **GPO firewall rule**:

*   Is enforced by domain controllers
*   Overrides locally created rules
*   Ensures consistent, auditable security policy
*   Is required for systems hardened under CIS baselines

If your Public profile ignores local rules, **GPO rules are the only rules that apply**.

***

## 1. Determine the Active Windows Firewall Profile

### PowerShell

```powershell
Get-NetFirewallSetting -PolicyStore ActiveStore |
  Select-Object -ExpandProperty ActiveProfile
```

### Command Line

```cmd
netsh advfirewall show currentprofile
```

If **Public** is active, continue.

**Reference:** KB0015997 – Determine Active Windows Firewall Profile  
🔗 <https://esri.service-now.com/api/now/table/kb_knowledge_base/0122d41adba8a700951dab8b4b9619ed>

***

## 2. Detect Whether Local Rules Are Being Ignored (CIS/GPO Behavior)

### Check Public Profile Settings

```powershell
Get-NetFirewallProfile -Profile Public |
  Select-Object Name, DefaultInboundAction, AllowLocalFirewallRules, AllowLocalIPsecRules
```

If `AllowLocalFirewallRules = False`, the machine is enforcing CIS-like restrictions.

### Check Effective Rule Sources

```powershell
Get-NetFirewallRule -PolicyStore ActiveStore |
  Select-Object DisplayName, Enabled, Direction, Action, Profile, PolicyStoreSource
```

If only `GroupPolicy` rules appear for the Public profile, local rules are being ignored.

**Reference:** KB0015998 – Domain Profile Not Selected (NLA Troubleshooting)  
🔗 <https://esri.service-now.com/api/now/table/kb_knowledge_base/0122d41adba8a700951dab8b4b9619ed>

***

## 3. Resolution Options

### Option A — Add a GPO Firewall Rule (Recommended for CIS Environments)

Create a **GPO-delivered inbound allow rule**:

| Setting       | Value                                                     |
| ------------- | --------------------------------------------------------- |
| Profile       | Public                                                    |
| Protocol/Port | TCP **8888**                                              |
| Optional      | Port range **30001–31000** for Notebook → Docker mappings |
| Rule Source   | Group Policy                                              |

This is the correct solution when local rules are ignored.

***

### Option B — Change the Docker NAT Adapter to Private

If allowed by IT/security policy, this lets local firewall rules apply.

#### Identify the adapter:

```powershell
Get-NetConnectionProfile | Format-Table Name, InterfaceAlias, NetworkCategory
```

#### Change the category:

```powershell
Set-NetConnectionProfile -InterfaceAlias "vEthernet (nat)" -NetworkCategory Private
```

Re-check the active firewall profile after making the change.

***

### Option C — Diagnostic Only: Temporarily Disable Public Firewall

```powershell
Set-NetFirewallProfile -Profile Public -Enabled False
```

If everything works immediately, you have confirmed that the Public profile was blocking required traffic.  
**Do not** use this as a permanent solution.

***

## 4. Validate End-to-End Connectivity

### Test host-to-container connection:

```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 8888
```

### Validate NAT port mappings:

```powershell
Get-NetNatStaticMapping
```

### Check effective rules (GUI):

Open **wf.msc → Monitoring → Firewall → Effective Rules**

*   Confirm the rule appears
*   Confirm **Policy Source = GroupPolicy** if using Option A

***

## 5. Recommended Practices

*   Establish whether Docker NAT should be treated as **Private** or remain **Public + GPO rules**.
*   If CIS Benchmarks are active:
    *   Assume local rules do not apply
    *   Always apply ports through **GPO**
*   Required Notebook Server ports:
    *   **8888** (Jupyter)
    *   **30001–31000** (ephemeral mapping range)
*   Follow ArcGIS Enterprise Hardening practices.

### Hardening Guides (Internal Files)

*   *ArcGIS\_Enterprise\_Hardening\_Guide.pdf*
*   *ArcGIS\_Enterprise\_Hardening\_Guide\_March\_2025.pdf*

(These are internal SharePoint/OneDrive assets accessible in the Esri environment.)

***

## 6. Quick Command Reference

```powershell
# Active firewall profile
netsh advfirewall show currentprofile

# Public profile settings
Get-NetFirewallProfile -Profile Public

# Effective firewall rule sources
Get-NetFirewallRule -PolicyStore ActiveStore

# Change Docker NAT to Private
Set-NetConnectionProfile -InterfaceAlias "vEthernet (nat)" -NetworkCategory Private
```

***

## 7. Additional Useful References

*   **CIS Benchmarks (Windows Server)**  
    <https://www.cisecurity.org/cis-benchmarks/>

*   **Internal Case: Docker / Public Firewall / CIS Baseline Issue**  
    <https://esri.lightning.force.com/lightning/r/Case/500UU00000ICkkjYAD/view>

*   **KB0015997 – Determine Active Windows Firewall Profile**  
    <https://esri.service-now.com/api/now/table/kb_knowledge_base/0122d41adba8a700951dab8b4b9619ed>

*   **KB0015998 – Domain Profile Not Selected (NLA Issue)**  
    <https://esri.service-now.com/api/now/table/kb_knowledge_base/0122d41adba8a700951dab8b4b9619ed>

