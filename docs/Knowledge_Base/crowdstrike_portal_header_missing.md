# ArcGIS Portal UI Issue: Header / Navigation Not Loading (CrowdStrike Interference)

In environments with endpoint detection and response (EDR) tools such as CrowdStrike, ArcGIS Enterprise components (especially Portal) may exhibit **partial UI rendering**, including missing headers, navigation menus, or styling.

This is typically caused by **real-time security scanning interfering with file access and local resource delivery**, and is resolved through **targeted CrowdStrike exclusions**.

## Symptoms

The issue often presents as **incomplete or broken UI rendering**, including:

-   Header, navigation bar, or menu **not appearing**
-   Page layout appearing **unstyled or partially loaded**
-   Application pages loading but missing **core UI components**
-   Intermittent behavior (sometimes works, sometimes not)

Additional backend symptoms may include:

-   JavaScript files failing to load
-   Delayed or blocked static content delivery
-   File access issues during startup or runtime
-   Database initialization inconsistencies

## How to Detect the Issue

### 1. Visual/UI Indicators

-   Portal home page loads but **header/menu is missing**
-   Browser shows a “broken” or **minimal HTML-only layout**
-   UI elements appear inconsistently between refreshes

### 2. Browser Developer Tools

Open **F12 → Network tab**:

-   Look for **failed or delayed requests** for:
    -   `.js` files
    -   `.css` files
-   Requests may show:
    -   Long load times
    -   Failed status
    -   Blocked/interrupted responses

### 3. Server-Side Behavior

-   Portal logs may show:
    -   Slow initialization
    -   Resource loading inconsistencies
-   System may exhibit:
    -   File locking behavior
    -   Intermittent startup issues
    -   Database access delays

### 4. Environmental Clues

-   CrowdStrike (or other EDR) recently installed or enabled
-   Issue occurs **only in secured environments**, not dev/test
-   Issue resolves temporarily when services restart

## Root Cause

The root cause is **real-time endpoint protection interference** with ArcGIS Enterprise components.

Specifically:

### 1. Interference with Local Resource Delivery

ArcGIS Portal UI depends on locally served:

-   JavaScript
-   CSS
-   Static assets

EDR tools may:

-   Inspect files before access
-   Delay file reads
-   Block or interrupt delivery

This results in:

-   **Incomplete page rendering (missing header/menu)**

### 2. High-Frequency File Operations

ArcGIS components (especially Portal) use:

-   Embedded PostgreSQL database
-   High-volume small file operations

EDR scanning can cause:

-   File locking
-   Delayed reads/writes
-   Initialization failures

### 3. Process-Level Interference

Key processes affected:

-   Java application server
-   Database engine
-   Portal services

Scanning or restricting these processes results in:

-   Runtime instability
-   Partial UI failures

## Resolution

### Implement Targeted CrowdStrike Exclusions

The issue is resolved by **excluding ArcGIS directories and processes** from real-time scanning.

These exclusions prevent:

-   File locking
-   Scan-induced delays
-   Resource delivery failures

#### Typical Required Exclusions

##### Directories:

```
C:\Program Files\ArcGIS\Portal
D:\arcgisportal
C:\Program Files\ArcGIS\Server
C:\arcgisserver
D:\arcgisserver
```

##### Processes:

```
portal.exe
java.exe
postgres.exe
```

## Example Email to IT Security (CrowdStrike Exclusions)

Use this template to accelerate resolution with IT/security teams:

**Subject:** Request for CrowdStrike Exclusions – ArcGIS Enterprise UI Rendering Issue

**Body:**

```
Hello [IT Security Team],

We are currently experiencing issues with ArcGIS Enterprise (Portal) where the web UI is not fully rendering. Specifically, we are seeing missing header/navigation elements and incomplete page loads.

Based on observed behavior, this appears to be caused by endpoint protection interference (CrowdStrike), particularly with real-time scanning impacting file access and JavaScript resource delivery.

We are also seeing symptoms consistent with:
- Failure to load JavaScript/CSS resources
- Partial UI rendering
- Intermittent file locking and initialization issues

To resolve this, we request targeted CrowdStrike exclusions for the following directories and processes.

Directories:
- C:\Program Files\ArcGIS\Portal
- D:\arcgisportal
- C:\Program Files\ArcGIS\Server
- D:\arcgisserver

Processes:
- portal.exe
- java.exe
- postgres.exe

These components perform high-frequency file operations and serve local application resources. Real-time scanning is likely introducing latency or blocking access, resulting in the observed UI issues.

Please let us know once these exclusions are in place, or if additional information is needed.

Respectfully,

[Your Name]
```

## Key Takeaways

-   Missing Portal header/navigation is a **strong indicator of EDR interference**
-   The issue is **not a UI bug**, but an infrastructure/security interaction problem
-   Resolution requires **security configuration changes**, not ArcGIS changes
-   Early detection saves significant troubleshooting timeDirektoriekDirektoriek