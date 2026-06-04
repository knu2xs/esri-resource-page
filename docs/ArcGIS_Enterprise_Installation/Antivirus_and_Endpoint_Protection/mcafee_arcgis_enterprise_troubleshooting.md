---
title: ArcGIS Enterprise and McAfee Interference
---
# ArcGIS Enterprise and McAfee Interference: Troubleshooting, Remediation, and Security Escalation

## Purpose

This guide documents common ArcGIS Enterprise issues caused by McAfee endpoint security controls, and provides:

- A practical troubleshooting workflow
- Remediation steps with targeted McAfee exclusions
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

- Symptoms started after McAfee policy or module update
- Issue appears on managed hosts only
- Restart provides temporary relief but not lasting resolution

## Why This Happens

ArcGIS Enterprise depends on sustained read/write activity and local static asset delivery. McAfee controls can interfere through:

- On-access scanning overhead
- Behavioral and exploit protection interactions
- Quarantine or block actions on trusted binaries or data files
- Increased I/O latency in high-frequency database operations

Portal rendering issues are often the first visible symptom, while Data Store disruption can appear later as latency and reliability issues.

## Troubleshooting Workflow

### 1. Confirm User-Facing Behavior

- Capture screenshots of missing UI elements
- Record affected URLs and timestamps
- Identify whether symptoms are intermittent or persistent

### 2. Validate Browser Resource Loading

- Open browser dev tools (F12), then Network
- Filter requests for `.js` and `.css`
- Identify failed, blocked, or unusually slow responses

### 3. Review ArcGIS Platform Health

- Review Portal and Server logs near the incident window
- Check Data Store status and warning/error trends
- Note file access delays, startup anomalies, and timeout behavior

### 4. Correlate with McAfee Events and Policy

- Review recent policy, engine, or module updates
- Check endpoint detections and quarantine logs
- Compare affected and unaffected hosts for policy differences

### 5. Run Controlled A/B Validation

In an approved maintenance window:

- Apply targeted exclusions to one host or pilot group
- Repeat UI and backend validation workflows
- Compare against baseline metrics

## Remediation

Implement targeted exclusions for ArcGIS install/data paths and key processes. Avoid broad exclusions.

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
- Large publish and migration activities

## Validation After Remediation

1. Restart affected ArcGIS services during an approved change window.
2. Validate Portal header and navigation behavior.
3. Run hosted feature layer query and edit tests.
4. Validate latest Data Store backup and recovery readiness.
5. Compare post-change latency and failure rates against baseline.

## Operational Best Practices

- Revalidate exclusions after ArcGIS upgrades and path updates
- Maintain shared GIS/Security runbook and ownership
- Add McAfee policy checks to release and change workflows
- Monitor for early indicators (timeouts, resource load delays, backup failures)

## Email Template to Security Team

Subject: Request for Targeted McAfee Exclusions for ArcGIS Enterprise Stability

```
Hello [IT Security Team],

We are troubleshooting ArcGIS Enterprise stability and UI rendering issues that are consistent with McAfee endpoint security interference.

Observed symptoms include:
- Portal pages intermittently missing header/navigation
- Delayed or failed JavaScript/CSS resource delivery
- Intermittent Data Store and service performance degradation
- Backup/restore instability during peak I/O operations

To remediate this while maintaining security controls, we request targeted McAfee exclusions for ArcGIS Enterprise processes and install/data paths.

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
- [ArcGIS Enterprise and Symantec interference](symantec_arcgis_enterprise_troubleshooting.md)

## Quick Summary

- This is usually not an ArcGIS code defect.
- McAfee endpoint controls can interfere with ArcGIS I/O-intensive operations.
- Targeted exclusions and GIS/Security coordination are the most reliable fix.
