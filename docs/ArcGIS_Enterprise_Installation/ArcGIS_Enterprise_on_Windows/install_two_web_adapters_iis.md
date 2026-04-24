# Installing Multiple ArcGIS Web Adaptors on a Single IIS Machine<br/><small>(Portal and Server Web Adaptors)</sm>

## Overview

In ArcGIS Enterprise deployments, it is common—and supported—to install **multiple ArcGIS Web Adaptor instances on the same IIS web server**, typically:

*   One Web Adaptor registered with **Portal for ArcGIS** (e.g., `/portal`)
*   One Web Adaptor registered with **ArcGIS Server** (e.g., `/server`)

However, administrators often encounter a confusing behavior when attempting this:

> When running the ArcGIS Web Adaptor installer a second time, the installer only offers **Repair** or **Remove**, and does not allow installing a second instance.

This document explains **why this happens** and provides **supported silent installation examples** for deploying two Web Adaptors correctly.

***

## Why the Installer Shows *Repair* or *Remove*

This behavior is caused by **Windows Installer (MSI) instance detection**, not by a limitation of ArcGIS itself.

### Key Points

*   ArcGIS Enterprise **fully supports multiple Web Adaptors** on the same machine, provided each has a **unique IIS virtual directory name** [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/web-adaptor/latest/install/iis/install-multiple-arcgis-web-adaptors-iis.htm)
*   The ArcGIS Web Adaptor installer is implemented as an **MSI package**
*   By default, when an MSI detects that its **ProductCode is already installed**, Windows Installer enters **maintenance mode**
*   Maintenance mode only allows:
    *   **Repair**
    *   **Remove**

As a result, simply re‑running `Setup.exe` after installing the first Web Adaptor causes the installer to assume you want to modify the existing installation rather than create a new one.

This is a **Windows Installer design behavior**, not a Portal/Server distinction, and is commonly encountered in single‑machine or shared web-tier Enterprise builds. [\[community.esri.com\]](https://community.esri.com/t5/implementing-arcgis-questions/unable-to-install-second-web-adaptor-for-arcgis/td-p/668742)

***

## Supported Approach: Multiple MSI Instances

ArcGIS Web Adaptor (IIS) supports **multiple MSI instances**, but **each instance must be explicitly created**. This is typically done using **silent installation parameters**.

Each instance:

*   Has its own IIS virtual directory
*   Has its own IIS application pool
*   Is registered independently with Portal or Server

 [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/web-adaptor/latest/install/iis/install-multiple-arcgis-web-adaptors-iis.htm)

***

## Naming and Registration Model

| Component              | Example                                                          |
| ---------------------- | ---------------------------------------------------------------- |
| Portal Web Adaptor URL | `https://gis.example.com/portal`                                 |
| Server Web Adaptor URL | `https://gis.example.com/server`                                 |
| IIS App Pools          | `ArcGISWebAdaptorAppPoolportal`, `ArcGISWebAdaptorAppPoolserver` |
| Registration           | Portal → `/portal`, Server → `/server`                           |

***

## Example: Silent Installation Commands (IIS)

> The examples below assume:
>
> *   Windows Server with IIS already installed
> *   ArcGIS Web Adaptor (IIS) media extracted
> *   **Administrator** command prompt
> *   ArcGIS Enterprise versions are compatible

### 1️⃣ Install Web Adaptor for **Portal** (`/portal`)

```bat
msiexec /i setup.msi MSINEWINSTANCE=1 TRANSFORMS=:InstanceId1.mst VDIRNAME=portal ACCEPTEULA=YES REBOOT=ReallySuppress /qb
```

✅ Result:

*   Creates IIS application `/portal`
*   Creates a new MSI instance
*   Ready to be registered with **Portal for ArcGIS**

***

### 2️⃣ Install Web Adaptor for **Server** (`/server`)

```bat
msiexec /i setup.msi MSINEWINSTANCE=1 TRANSFORMS=:InstanceId2.mst VDIRNAME=server ACCEPTEULA=YES REBOOT=ReallySuppress /qb
```

✅ Result:

*   Creates IIS application `/server`
*   Installs as a separate MSI instance
*   Ready to be registered with **ArcGIS Server**

> **Important:**  
> Each `InstanceId#.mst` value may be used **only once per machine**. Choose a new number (1–50) for each Web Adaptor instance. [\[support.esri.com\]](https://support.esri.com/en-us/knowledge-base/only-one-instance-can-be-installed-of-arcgis-web-adapto-000038798)

***

## Post‑Installation: Web Adaptor Registration

After installation:

### Register Portal Web Adaptor

```text
https://<webserver>/portal/webadaptor
```

Choose **Portal for ArcGIS** and complete registration.

### Register Server Web Adaptor

```text
https://<webserver>/server/webadaptor
```

Choose **ArcGIS Server** and complete registration.

These registration steps are performed locally on the Web Adaptor machine for security reasons. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/web-adaptor/latest/install/iis/configure-arcgis-web-adaptor-server.htm)

***

## Common Pitfalls

| Issue                      | Cause                                                   |
| -------------------------- | ------------------------------------------------------- |
| Repair/Remove prompt       | MSI maintenance mode                                    |
| Virtual directory conflict | Reusing the same `VDIRNAME`                             |
| Broken URLs                | Attempting to reuse `/arcgis` or nested contexts        |
| Mixed versions             | Web Adaptor version must match the registered component |

***

## Summary

*   ✅ Multiple ArcGIS Web Adaptors on one IIS machine are **supported**
*   ✅ Portal and Server **must not share** the same Web Adaptor
*   ❌ Re‑running `Setup.exe` alone triggers **MSI maintenance mode**
*   ✅ Use **silent MSI instance installs** to deploy multiple Web Adaptors cleanly

This approach aligns with Esri’s supported installation model and avoids unsupported IIS duplication hacks.

***

If you want, next I can:

*   Convert this into a **one‑page customer‑safe PDF**
*   Add a **PowerShell wrapper**
*   Include **ArcGIS Server + Portal registration automation**
*   Add a **troubleshooting appendix (logs, app pools, certs)**
