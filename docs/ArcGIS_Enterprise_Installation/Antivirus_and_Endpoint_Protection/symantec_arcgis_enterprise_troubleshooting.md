---
title: ArcGIS Enterprise and Symantec Interference
---
# ArcGIS Enterprise and Symantec Interference: Troubleshooting, Remediation, and Security Escalation

## Purpose

This guide documents common ArcGIS Enterprise issues caused by Symantec endpoint protection controls, and provides:

- A structured troubleshooting workflow
- Remediation steps with targeted Symantec exclusions
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

- Symptoms started after Symantec policy or content update
- Issue appears in managed endpoints but not isolated systems
- Service restart provides temporary improvement only

## Why This Happens

ArcGIS Enterprise depends on high-frequency file access, local static content delivery, and continuous database operations. Symantec controls can interfere through:

- Auto-Protect real-time scanning
- Behavioral detection and reputation controls
- Quarantine actions on binaries or data files
- Additional overhead on high-volume read/write operations

Portal symptoms are often the earliest signal, while Data Store effects appear as performance degradation and intermittent reliability failures.

## Troubleshooting Workflow

### 1. Confirm User-Facing Behavior

- Capture screenshots of missing UI elements
- Record affected URLs and timestamps
- Identify whether behavior is intermittent or persistent

### 2. Validate Browser Resource Loading

- Open browser dev tools (F12), then Network
- Filter requests for `.js` and `.css`
- Identify failed, blocked, or very slow responses

### 3. Review ArcGIS Platform Health

- Review Portal and Server logs around incident windows
- Check Data Store status and warning/error patterns
- Note file access delays, startup anomalies, and timeout spikes

### 4. Correlate with Symantec Events and Policy

- Review recent policy changes and definition/content updates
- Check Symantec detections, quarantine, and block history
- Compare affected versus unaffected host policy assignments

### 5. Run Controlled A/B Validation

In an approved maintenance window:

- Apply targeted exclusions to a pilot host or ring
- Re-run UI, query, edit, and backup workflows
- Compare outcomes against baseline

## Remediation

Implement targeted path and process exclusions for ArcGIS components. Avoid broad exclusions.

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
- Backup and restore operations
- Large publishing and migration windows

## Validation After Remediation

1. Restart affected ArcGIS services during a planned change window.
2. Validate Portal header and navigation consistency.
3. Run hosted feature layer query and edit verification.
4. Validate latest Data Store backup completion and restore readiness.
5. Compare response times and failure rates to baseline.

## Operational Best Practices

- Revisit exclusions after ArcGIS upgrades and path changes
- Maintain shared GIS/Security runbook and ownership model
- Add Symantec policy checks to change control
- Monitor for early signs (resource load delays, timeout patterns, backup failures)

## Email Template to Security Team

Subject: Request for Targeted Symantec Exclusions for ArcGIS Enterprise Stability

```
Hello [IT Security Team],

We are troubleshooting ArcGIS Enterprise stability and UI rendering issues that are consistent with Symantec endpoint protection interference.

Observed symptoms include:
- Portal pages intermittently missing header/navigation
- Delayed or failed JavaScript/CSS resource delivery
- Intermittent Data Store and service performance degradation
- Backup/restore instability during peak I/O operations

To remediate this while maintaining security controls, we request targeted Symantec exclusions for ArcGIS Enterprise processes and install/data paths.

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
- [ArcGIS Enterprise and Microsoft Defender interference](microsoft_defender_arcgis_enterprise_troubleshooting.md)
- [ArcGIS Enterprise and McAfee interference](mcafee_arcgis_enterprise_troubleshooting.md)

## Quick Summary

- This is usually not an ArcGIS code defect.
- Symantec endpoint controls can affect ArcGIS local resource and database operations.
- Targeted exclusions and coordinated validation are the most reliable fix.
