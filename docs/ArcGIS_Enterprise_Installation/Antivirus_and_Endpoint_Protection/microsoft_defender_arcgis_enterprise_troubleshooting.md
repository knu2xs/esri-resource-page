---
title: ArcGIS Enterprise and Microsoft Defender Interference
---
# ArcGIS Enterprise and Microsoft Defender Interference: Troubleshooting, Remediation, and Security Escalation

## Purpose

This guide documents common ArcGIS Enterprise issues caused by Microsoft Defender controls, and provides:

- A practical troubleshooting workflow
- Remediation steps with targeted Defender exclusions
- A ready-to-send email template for Security

## Scope

This guidance applies to:

- Portal for ArcGIS
- ArcGIS Server
- ArcGIS Data Store (especially relational store)

## Typical Symptoms

### Portal and UI Symptoms

- Missing header or navigation menu
- Unstyled or partially rendered pages
- Intermittent UI behavior after refresh
- Failed or delayed `.js` and `.css` requests in browser dev tools

### Data Store and Service Symptoms

- Slow hosted feature layer reads and edits
- Publish operations taking longer than expected
- Intermittent timeouts or service instability
- Backup and restore operations running slowly or failing

### Environmental Clues

- Symptoms started after Defender policy changes
- Issues appear in secured environments but not isolated test systems
- Restart temporarily improves behavior, then symptoms return

## Why This Happens

ArcGIS Enterprise uses frequent local disk I/O, process-to-process communication, and static asset delivery. Defender can introduce latency or interruptions through:

- Real-time protection scanning
- Controlled Folder Access policy enforcement
- Attack Surface Reduction rule interactions
- Additional inspection overhead on binaries and database files

Portal UI symptoms are often the first visible sign, while Data Store effects can emerge later as performance or reliability problems.

## Troubleshooting Workflow

### 1. Confirm User-Facing Behavior

- Capture screenshots of missing UI elements
- Record affected URLs and timestamps
- Note whether symptoms are constant or intermittent

### 2. Validate Browser Resource Loading

- Open browser dev tools (F12), then Network
- Filter requests for `.js` and `.css`
- Identify failed, blocked, or unusually slow responses

### 3. Review ArcGIS Platform Health

- Check Portal and Server logs near incident windows
- Check Data Store status and recent warnings or errors
- Look for file access delays, startup issues, and timeouts

### 4. Correlate with Defender Events and Policy

- Review recent Defender configuration or baseline changes
- Check Windows security events tied to scan/quarantine actions
- Compare affected and unaffected hosts by policy assignment

### 5. Run Controlled A/B Validation

In an approved maintenance window:

- Apply targeted exclusions to one host or ring
- Repeat UI, query, edit, and backup tests
- Compare baseline versus post-change behavior

## Remediation

Use targeted exclusions for ArcGIS binaries and data paths. Avoid broad system-wide exemptions.

### Recommended Path Exclusions (Adjust to Actual Install Paths)

```
C:\Program Files\ArcGIS\Portal
C:\Program Files\ArcGIS\Server
C:\Program Files\ArcGIS\DataStore
C:\arcgisportal
C:\arcgisserver
C:\arcgisdatastore
D:\arcgisportal
D:\arcgisserver
D:\arcgisdatastore
```

### Recommended Process Exclusions

```
portal.exe
java.exe
postgres.exe
configuredatastore.exe
```

### During Critical Operations

Coordinate temporary policy tuning during:

- Data Store creation and upgrade
- Backup and restore
- Large publishing or migration windows

## Validation After Remediation

1. Restart affected ArcGIS services during a change window.
2. Validate Portal header and navigation across key pages.
3. Run hosted layer query and edit tests.
4. Validate latest Data Store backup completion and integrity.
5. Compare latency and failure rates to pre-change baseline.

## Operational Best Practices

- Revalidate exclusions after ArcGIS upgrades and path changes
- Keep a shared runbook between GIS and Security operations
- Add Defender policy checks to deployment and change control
- Monitor for recurring warning signals (timeouts, resource load failures, backup drift)

## Email Template to Security Team

Subject: Request for Targeted Microsoft Defender Exclusions for ArcGIS Enterprise Stability

```
Hello [IT Security Team],

We are troubleshooting ArcGIS Enterprise stability and UI rendering issues that align with Microsoft Defender policy interference.

Observed symptoms include:
- Portal pages intermittently missing header/navigation
- Delayed or failed JavaScript/CSS resource delivery
- Intermittent Data Store and service performance degradation
- Backup/restore instability during peak I/O operations

To remediate this while maintaining security controls, we request targeted Microsoft Defender exclusions for ArcGIS Enterprise processes and install/data paths.

Requested path exclusions (host-specific paths will be confirmed):
- C:\Program Files\ArcGIS\Portal
- C:\Program Files\ArcGIS\Server
- C:\Program Files\ArcGIS\DataStore
- C:\arcgisportal
- C:\arcgisserver
- C:\arcgisdatastore
- D:\arcgisportal
- D:\arcgisserver
- D:\arcgisdatastore

Requested process exclusions:
- portal.exe
- java.exe
- postgres.exe
- configuredatastore.exe

We request implementation in a controlled change window so we can validate:
1) Portal UI consistency
2) Hosted service performance
3) Data Store backup/restore reliability

Please let us know if you need host inventory, exact install paths, or a phased rollout plan.

Thank you,
[Your Name]
[Team / Contact]
```

## Related Documents

- [Antivirus and endpoint protection collection overview](antivirus_endpoint_protection_overview.md)
- [ArcGIS Enterprise and CrowdStrike EDR interference](crowdstrike_arcgis_enterprise_troubleshooting.md)
- [ArcGIS Enterprise and Symantec interference](symantec_arcgis_enterprise_troubleshooting.md)
- [ArcGIS Enterprise and McAfee interference](mcafee_arcgis_enterprise_troubleshooting.md)

## Quick Summary

- This is usually not an ArcGIS code defect.
- Defender policy interactions can disrupt ArcGIS file and process workflows.
- Targeted exclusions and joint GIS/Security validation are the most reliable fix.
