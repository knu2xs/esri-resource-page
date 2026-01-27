# KB: Troubleshooting Windows Firewall + Docker NAT Issues on ArcGIS Notebook Server

**Last Updated:** January 2026  
**Author:** Joel McCune, Sr. Technical Consultant

***

## **Overview**

When running **ArcGIS Notebook Server** on Windows Server (2022+), Docker containers may start successfully, but Notebook Server cannot connect to the Jupyter port (typically **8888**) inside the container.  
A common root cause is that Docker’s **NAT network adapter** is assigned to the **Public** firewall profile, which—under CIS or similar hardened baselines—may be configured to **ignore local firewall rules**, meaning any rules you create manually will not apply.

This KB provides a repeatable diagnostic and remediation procedure.

***

## **1. Determine the Active Windows Firewall Profile**

Windows may incorrectly classify the Docker NAT adapter under the **Public** profile. Confirm which profile is currently active:

### **PowerShell**

```powershell
Get-NetFirewallSetting -PolicyStore ActiveStore |
  Select-Object -ExpandProperty ActiveProfile
```

### **Command Line**

```cmd
netsh advfirewall show currentprofile
```

If **Public** is active, continue to Section 2.

***

## **2. Detect Whether Local Rules Are Being Ignored (CIS Baseline Behavior)**

Many organizations configure hardened baselines (e.g., **CIS Benchmarks**) to **disable local firewall rules** for the Public profile.

### **Check Public Profile Settings**

```powershell
Get-NetFirewallProfile -Profile Public |
  Select-Object Name, DefaultInboundAction, AllowLocalFirewallRules, AllowLocalIPsecRules
```

If `AllowLocalFirewallRules = False`, any local “Allow inbound TCP 8888” rule will be ignored.

### **Check the Effective Rule Source**

```powershell
Get-NetFirewallRule -PolicyStore ActiveStore |
  Select-Object DisplayName, Enabled, Direction, Action, Profile, PolicyStoreSource
```

*If the only rules that apply to the Public profile come from `GroupPolicy`, the machine is enforcing centralized security baselines.*

***

## **3. Resolution Options**

### **Option A — Add a GPO Firewall Rule for the Public Profile (Recommended in Hardened Environments)**

Since local rules are ignored, create a **GPO-based inbound rule**:

*   Profile: **Public**
*   Action: **Allow**
*   Protocol/Port: **TCP 8888** (or the Notebook Server → Docker port range: e.g., 30001–31000)
*   Scope: Server(s) hosting ArcGIS Notebook Server

This is the **correct** fix when CIS or enterprise baselines block local rules.

***

### **Option B — Change Docker NAT Adapter to Private Profile**

If organizational policy allows, change the Docker NAT network category from Public → Private.

#### **Steps**

1.  Identify the adapter:
    ```powershell
    Get-NetConnectionProfile | Format-Table Name, InterfaceAlias, NetworkCategory
    ```
    Look for: **vEthernet (nat)**

2.  Change category:
    ```powershell
    Set-NetConnectionProfile -InterfaceAlias "vEthernet (nat)" -NetworkCategory Private
    ```

After changing, re-run `netsh advfirewall show currentprofile` and validate expected behavior.

***

### **Option C — Temporary Test: Disable Public Firewall**

**Only for diagnostics.**

```powershell
Set-NetFirewallProfile -Profile Public -Enabled False
```

If the Notebook Server immediately works, the issue is confirmed as Public-profile enforcement (CIS baseline + ignored local rules).

***

## **4. Validate End-to-End Connectivity**

After applying A or B:

### **From the host**

```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 8888
```

### **Check Docker's NAT port mappings**

```powershell
Get-NetNatStaticMapping
```

### **Verify effective firewall rules**

In **wf.msc → Monitoring → Firewall → Effective Rules**, confirm:

*   Your rule appears
*   Source = **Group Policy** (if Option A)
*   Profile = **Public** or **Private**, depending on your configuration

***

## **5. Recommended Practice for ArcGIS Notebook Deployments**

*   Standardize whether Docker NAT adapters should be **Private** or **Public with GPO rules**.
*   If using CIS baselines, always create **GPO-based firewall exceptions** rather than relying on local rules.
*   Document required ports:
    *   **8888** (Jupyter Notebook)
    *   **30001–31000** (Notebook Server → Docker container ephemeral mapping range)

***

## **6. Quick Reference**

### **Common Commands**

```powershell
# Active profile
netsh advfirewall show currentprofile

# Firewall profile details
Get-NetFirewallProfile -Profile Public

# Effective rule sources
Get-NetFirewallRule -PolicyStore ActiveStore

# NAT adapter profile fix
Set-NetConnectionProfile -InterfaceAlias "vEthernet (nat)" -NetworkCategory Private
```

***

## **7. Summary**

Most customer and internal cases trace back to:

*   Docker NAT adapter categorized as **Public**, **AND**
*   Hardened baseline sets **“Ignore local firewall rules”** for Public, **SO**
*   Local allow rules appear correct but **never apply**

The fix is either:

1.  **Create a GPO-based allow rule** (preferred under CIS), or
2.  **Change NAT to Private**.
