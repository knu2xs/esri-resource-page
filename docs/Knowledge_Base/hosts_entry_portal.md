# Hosts Entry Guidance for Portal Install and WebGISDR Recovery

This document explains when a hosts file entry is safe, when it is risky, and how to validate a machine before a Portal install during side-by-side upgrade and WebGISDR recovery work.

## Why hostname consistency matters

Portal is strict about hostname identity.

- Use a fully qualified domain name (FQDN) for the Portal URL and Web Adaptor configuration.
- That hostname is written into organization URLs and internal Portal configuration.

Reference:
- [Determine your organization's URL](https://doc.esri.com/en/arcgis-enterprise/latest/deploy/determine-your-organization-s-url.html)

Example:

```text
portal.domain.com
NOT just portal
```

If identity is inconsistent, Portal and Web Adaptor behavior becomes unreliable.

## What a hosts file entry does

A hosts file entry such as this:

```text
127.0.0.1 portal.domain.com
```

forces local name resolution and bypasses DNS for that hostname.

That override is sometimes useful, but it can also create identity mismatches if not tightly controlled.

## Common failure modes during install or reconfiguration

### 1. FQDN mismatch and identity confusion

If Portal resolves itself one way (for example localhost) while Web Adaptor is configured with an FQDN from hosts, you can see:

- configuration failures
- Web Adaptor errors requiring FQDN
- inconsistent URLs

Reference:
- [Portal for ArcGIS configuration requires fully qualified domain name](https://support.esri.com/en-us/knowledge-base/error-portal-for-arcgis-configuration-requires-fully-qu-000028796)

### 2. Web Adaptor configuration failure

Typical symptom:

```text
Portal for ArcGIS configuration requires fully qualified domain name
```

This usually happens when the URL used for configuration is not the same identity Portal thinks it is.

### 3. Federation and Server communication issues

Portal-to-Server communication depends on consistent forward and reverse resolution. If each component resolves the other differently, federation and service communication can fail.

### 4. SSL certificate mismatch

If certificate identity does not align with the FQDN in use, you may get certificate warnings, Web Adaptor failures, and unstable HTTPS behavior.

Example:

```text
CN = portal.domain.com
```

### 5. Wrong URL values cached in Portal

Portal stores internal URL values, WebContextURL (if set), and service URLs. If installation happens under bad name resolution, these values can be persisted incorrectly and are time-consuming to clean up.

## When using hosts is acceptable

A controlled hosts override can be appropriate for migration or parallel build cutover, for example:

- existing live system uses portal.domain.com
- recovery or new build is on a separate machine
- hosts temporarily maps portal.domain.com to the new machine

Reference:
- [Configure a new ArcGIS Enterprise deployment with a DNS URL in use](https://resources.esri.ca/getting-technical/configure-a-new-arcgis-enterprise-deployment-with-a-dns-url-in-use)

If you use this pattern, enforce all of the following:

- Use FQDN everywhere, no short names.
- Certificate matches FQDN.
- Do not mix localhost, machine short name, and FQDN in workflows.

## Recommended workflow for rebuild and recovery prep

For clean installs or rebuilds:

- Remove hosts entries for the Portal hostname before install.
- Use proper DNS or a properly configured FQDN.

Only use hosts entries when:

- DNS override is intentionally required.
- You are preserving a production URL during a controlled migration step.

## Quick pre-install sanity check

Run:

```cmd
hostname
nslookup <hostname>
ping <fqdn>
```

All should resolve consistently to the same target machine.

## PowerShell validation script (keep as-is)

Run in PowerShell as Administrator.

```powershell
Write-Host "=== ARC GIS PORTAL HOSTNAME + CERT VALIDATION ===" -ForegroundColor Cyan

# --- Get machine info ---
$hostname = $env:COMPUTERNAME
$fqdn = ([System.Net.Dns]::GetHostByName($hostname)).HostName

Write-Host "`n[1] Machine Identity" -ForegroundColor Yellow
Write-Host "Hostname: $hostname"
Write-Host "FQDN:     $fqdn"

# --- DNS resolution test ---
Write-Host "`n[2] DNS Resolution" -ForegroundColor Yellow
try {
  $dns = Resolve-DnsName $fqdn -ErrorAction Stop
  $dns | Where-Object {$_.Type -eq "A"} | ForEach-Object {
    Write-Host "Resolved IP: $($_.IPAddress)"
  }
} catch {
  Write-Host "DNS lookup FAILED for $fqdn" -ForegroundColor Red
}

# --- Check hosts file overrides ---
Write-Host "`n[3] Hosts File Check" -ForegroundColor Yellow
$hosts = Get-Content "C:\Windows\System32\drivers\etc\hosts"
$matches = $hosts | Where-Object {$_ -match $hostname -or $_ -match $fqdn}

if ($matches) {
  Write-Host "Hosts file entries found (CHECK THESE):" -ForegroundColor Red
  $matches | ForEach-Object { Write-Host $_ }
} else {
  Write-Host "No hosts file entries for this machine" -ForegroundColor Green
}

# --- Test HTTP/S binding (Portal ports) ---
Write-Host "`n[4] Port Connectivity (7443)" -ForegroundColor Yellow
try {
  $conn = Test-NetConnection -ComputerName $fqdn -Port 7443
  if ($conn.TcpTestSucceeded) {
    Write-Host "Port 7443 reachable" -ForegroundColor Green
  } else {
    Write-Host "Port 7443 NOT reachable" -ForegroundColor Red
  }
} catch {
  Write-Host "Connection test failed" -ForegroundColor Red
}

# --- Certificate check (local machine store) ---
Write-Host "`n[5] Certificate Check (LocalMachine\My)" -ForegroundColor Yellow
$certs = Get-ChildItem Cert:\LocalMachine\My

$matchingCerts = $certs | Where-Object {
  $_.Subject -match $fqdn -or $_.DnsNameList -match $fqdn
}

if ($matchingCerts) {
  Write-Host "Matching certificates found:" -ForegroundColor Green
  $matchingCerts | ForEach-Object {
    Write-Host "Subject: $($_.Subject)"
    Write-Host "Expires: $($_.NotAfter)"
    Write-Host "---"
  }
} else {
  Write-Host "No certificate matches FQDN ($fqdn)" -ForegroundColor Red
}

# --- Self-resolution check ---
Write-Host "`n[6] Self Ping Test" -ForegroundColor Yellow
$ping = Test-Connection $fqdn -Count 1 -Quiet
if ($ping) {
  Write-Host "FQDN resolves locally OK" -ForegroundColor Green
} else {
  Write-Host "FQDN does NOT resolve locally" -ForegroundColor Red
}

Write-Host "`n=== VALIDATION COMPLETE ===" -ForegroundColor Cyan
```

## Interpretation guide: what good looks like

### Hostname

- FQDN resolves correctly.
- Not localhost or short-name-only behavior.

### DNS

- Resolve-DnsName returns the expected IP.
- DNS, ping, and expected NIC alignment are consistent.

### Hosts file

- Preferred: no hosts entry for the Portal FQDN.
- If present, use one correct mapping only.
- Avoid mixed short-name and FQDN mappings for the same host.

### Certificates

- CN or SAN includes the FQDN.
- Do not rely on localhost-only or short-name-only cert identity.

### Connectivity

- Port 7443 is reachable locally.
- No firewall or binding conflict.

## Failure patterns this catches quickly

### Hosts override to loopback

```text
127.0.0.1 portal.domain.com
```

Likely result: Web Adaptor config failures and Portal URL mismatch.

### Certificate subject mismatch

```text
Cert: CN=portal
FQDN: portal.domain.com
```

Likely result: HTTPS trust issues and possible federation errors.

### Split-brain DNS behavior

```text
ping -> 10.1.1.10
nslookup -> 192.168.1.5
```

Likely result: Portal and Server communication instability.

### Short hostname usage

```text
portal
```

Likely result: FQDN consistency problems that break Web Adaptor configuration.

## Bottom line

- Portal is sensitive to hostname consistency.
- Hosts entries can be useful for controlled migration, but risky for routine install.
- For normal install or rebuild, remove hosts overrides and use proper DNS/FQDN.
