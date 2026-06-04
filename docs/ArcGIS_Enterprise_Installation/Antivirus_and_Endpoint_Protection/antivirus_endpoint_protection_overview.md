---
title: ArcGIS Enterprise Antivirus and Endpoint Protection Guidance
---
# ArcGIS Enterprise Antivirus and Endpoint Protection Guidance

## Purpose

This document is the starting point for ArcGIS Enterprise antivirus and endpoint protection troubleshooting guidance in this folder.

Use it to:

- Understand shared failure patterns across endpoint security products
- Choose the right vendor-specific troubleshooting document
- Follow a consistent remediation and validation model

## What This Collection Covers

ArcGIS Enterprise components that are typically impacted by endpoint protection policy interactions:

- Portal for ArcGIS
- ArcGIS Server
- ArcGIS Data Store

Common failure patterns include:

- Missing or partially rendered Portal UI
- Delayed JavaScript and CSS resource loading
- Slow edits, queries, and publishing workflows
- Data Store backup and restore instability

## How to Use These Documents

1. Identify your active endpoint security platform.
2. Open the matching vendor guide below.
3. Follow the troubleshooting workflow in order.
4. Apply targeted exclusions through Security in a controlled window.
5. Complete the validation checklist and capture before/after results.

## Vendor-Specific Guides

- [ArcGIS Enterprise and CrowdStrike EDR interference](crowdstrike_arcgis_enterprise_troubleshooting.md)
- [ArcGIS Enterprise and Microsoft Defender interference](microsoft_defender_arcgis_enterprise_troubleshooting.md)
- [ArcGIS Enterprise and Symantec interference](symantec_arcgis_enterprise_troubleshooting.md)
- [ArcGIS Enterprise and McAfee interference](mcafee_arcgis_enterprise_troubleshooting.md)

## Shared Remediation Model

Across vendors, successful remediation follows the same pattern:

- Use targeted path and process exclusions for ArcGIS components
- Avoid broad endpoint security bypasses
- Coordinate with Security for change-window implementation
- Validate both UI behavior and backend reliability

### Typical ArcGIS Path Scope

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

### Typical ArcGIS Process Scope

```
portal.exe
java.exe
postgres.exe
configuredatastore.exe
```

## Validation Checklist (All Vendors)

1. Validate Portal header and navigation consistency.
2. Validate hosted feature layer query and edit behavior.
3. Validate publish workflows on representative services.
4. Validate Data Store backup completion and restore readiness.
5. Compare post-change performance and error rates to baseline.

## Governance and Operations Notes

- Product console names and policy labels vary by vendor and version.
- Maintain a shared GIS and Security runbook with ownership and escalation contacts.
- Revisit exclusions after ArcGIS upgrades, endpoint agent upgrades, and path changes.
- Keep rollback and rollback-validation steps in the change record.

## Document Selection Quick Guide

- Use CrowdStrike guide when Falcon policy or sensor behavior is suspected.
- Use Defender guide when Microsoft Defender real-time or ASR policy changes align with onset.
- Use Symantec guide when endpoint policy/content updates or quarantine events align with onset.
- Use McAfee guide when on-access scan policy or module updates align with onset.
