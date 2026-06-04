# ArcGIS Enterprise and CrowdStrike EDR Interference: Troubleshooting, Remediation, and Security Escalation

## Purpose

This guide consolidates common ArcGIS Enterprise issues caused by CrowdStrike (or similar EDR tools), and provides:

- A single troubleshooting workflow
- Remediation steps with targeted exclusions
- A ready-to-send email template for IT Security

## Scope

This applies to ArcGIS Enterprise components that are sensitive to real-time file and process inspection:

- Portal for ArcGIS
- ArcGIS Server
- ArcGIS Data Store (especially relational store)

## Typical Symptoms

### Portal/UI Symptoms

- Missing header or navigation menu
- Unstyled or partially rendered pages
- Intermittent UI behavior after refresh
- Failed or delayed `.js` and `.css` requests in browser dev tools

### Data Store/Service Symptoms

- Slow hosted feature layer reads/edits
- Publish operations taking longer than expected
- Intermittent service instability or timeouts
- Backup/restore jobs running slowly or failing

### Environmental Clues

- Problem started after CrowdStrike rollout or policy change
- Issue reproduces in production but not in less-secured environments
- Service restart gives temporary relief, then issue returns

## Why This Happens

ArcGIS Enterprise relies on high-frequency local I/O, static resource delivery, and database operations. EDR real-time scanning can introduce:

- File lock contention
- Read/write latency
- Process execution delays
- Interrupted delivery of local UI assets

When this happens, Portal symptoms are often visible first, while Data Store impacts can be deeper and less obvious.

## Troubleshooting Workflow

### 1. Confirm User-Facing Behavior

- Capture screenshots of missing UI elements
- Identify whether issue is persistent or intermittent
- Record affected URLs and timestamps

### 2. Validate Browser Resource Loading (Portal)

- Open dev tools (F12), check Network tab
- Filter for `.js` and `.css`
- Look for failed, blocked, or very slow requests

### 3. Check ArcGIS Logs and Health

- Review Portal/Server logs around incident timestamps
- Check Data Store status and recent warnings/errors
- Look for startup delays, file access errors, and timeout patterns

### 4. Correlate with Security Policy Changes

- Confirm whether sensor install or policy update occurred recently
- Compare impacted hosts against unaffected hosts
- Verify whether issue aligns with policy enforcement windows

### 5. Perform Controlled A/B Validation

In a security-approved maintenance window:

- Apply targeted exclusions on one host (or test group)
- Retest UI loading, publish/edit performance, and backups
- Compare results before and after exclusions

## Remediation

Implement targeted exclusions for ArcGIS binaries and data paths. Avoid broad exclusions.

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

Coordinate with security for temporary scan relaxation during:

- Data Store creation or upgrade
- Backup and restore operations
- Large publishing or migration events

## Validation After Remediation

After exclusions are applied:

1. Restart affected ArcGIS services in a change window.
2. Retest Portal pages for header/nav consistency.
3. Run a hosted layer query and edit test.
4. Run or validate latest Data Store backup.
5. Compare performance and error rates to pre-change baseline.

## Operational Best Practices

- Review exclusions after ArcGIS upgrades or path changes
- Keep a shared runbook between GIS and Security teams
- Add EDR policy checks to ArcGIS deployment/change checklists
- Monitor for early warning signs (timeouts, backup delays, resource load failures)

## Email Template to Security Team

Subject: Request for Targeted CrowdStrike Exclusions for ArcGIS Enterprise Stability

```
Hello [IT Security Team],

We are troubleshooting ArcGIS Enterprise stability and UI rendering issues that are consistent with endpoint protection interference.

Observed symptoms include:
- Portal pages intermittently missing header/navigation
- Delayed or failed JavaScript/CSS resource delivery
- Intermittent Data Store and service performance degradation
- Backup/restore instability during peak I/O operations

To remediate this while maintaining security controls, we are requesting targeted CrowdStrike exclusions for ArcGIS Enterprise processes and install/data paths.

Requested path exclusions (adjusted to host-specific install paths):
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

We are requesting implementation in a controlled change window so we can validate:
1) Portal UI consistency
2) Hosted service performance
3) Data Store backup/restore reliability

Please let us know if you need host lists, exact install paths, or a phased rollout plan.

Thank you,
[Your Name]
[Team / Contact]
```

## Quick Summary

- This is usually not an ArcGIS code defect.
- It is commonly an infrastructure interaction between EDR scanning and ArcGIS I/O patterns.
- Targeted exclusions and joint GIS/Security validation are the most reliable fix.