# Esri Internal Certificate Generator

This script retrieves certificates from Esri's internal certifactory and creates a full-chain PFX file suitable for use with Tomcat and other services.

## Prerequisites

- Machine must be on the **Esri internal network**
- `openssl` must be installed
- `curl` must be installed
- `python3` (optional, for URL encoding passwords with special characters)

## Usage

```bash
./get_esri_certificate.sh <pfx_password> [output_path] [machine_name]
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `pfx_password` | **Yes** | Password for the PFX certificates (used for both input and output) |
| `output_path` | No | Path for output file (relative or absolute). Defaults to `./tomcat_fullchain.pfx` |
| `machine_name` | No | Machine name for the certificate request. Defaults to current hostname (FQDN) |

### Examples

**Basic usage** (uses current hostname, outputs to current directory):
```bash
./get_esri_certificate.sh 'MyP@ssword'
```

**Specify output path**:
```bash
./get_esri_certificate.sh 'MyP@ssword' /tmp/mycert.pfx
```

**Specify all parameters**:
```bash
./get_esri_certificate.sh 'MyP@ssword' ./certs/tomcat.pfx myserver.esri.com
```

**Relative output path**:
```bash
./get_esri_certificate.sh 'MyP@ssword' ../certificates/server.pfx
```

## What the Script Does

1. **Installs Esri Root CA certificates** — Adds Esri's root and issuing CA certificates to the system trust store (requires sudo)
2. **Downloads server PFX** — Retrieves the machine-specific certificate from certifactory
3. **Downloads intermediate certificate** — Gets the Esri Issuing CA certificate
4. **Downloads CA root certificate** — Gets the Esri Root CA certificate
5. **Extracts certificate and key** — Extracts the server certificate and private key from the downloaded PFX
6. **Normalizes certificates** — Converts DER format certificates to PEM if needed
7. **Builds full chain** — Combines server, intermediate, and root certificates
8. **Creates full-chain PFX** — Packages everything into a single PFX file with the full certificate chain

## Output

The script creates a PKCS#12 (.pfx/.p12) file containing:

- Server private key
- Server certificate
- Intermediate CA certificate
- Root CA certificate

This full-chain certificate is suitable for direct use in:

- Apache Tomcat
- Other Java-based application servers
- Any service requiring PKCS#12 certificates

## Machine Name Detection

If the machine name is not provided, the script attempts to detect it automatically:

1. First tries `hostname -f` to get the fully qualified domain name (FQDN)
2. Falls back to `hostname` if FQDN is not available
3. Appends `.esri.com` if the hostname doesn't contain a domain

## Troubleshooting

### Certificate download fails

- Verify you are on the Esri internal network
- Check that the machine name is correct
- Ensure certifactory.esri.com is accessible

### OpenSSL errors with `-legacy` flag

The script tries OpenSSL commands with the `-legacy` flag first (required for newer OpenSSL versions), then falls back to standard commands for older versions.

### Password with special characters

If your password contains special characters, the script uses Python to URL-encode it. If Python is not available, ensure your password doesn't contain characters that need URL encoding (like `&`, `?`, `=`, etc.).

### Verify the output certificate

```bash
openssl pkcs12 -in tomcat_fullchain.pfx -info -passin pass:'YourPassword'
```

### View certificate details

```bash
openssl pkcs12 -in tomcat_fullchain.pfx -nokeys -passin pass:'YourPassword' | openssl x509 -noout -text
```

---

## PowerShell: Retrieve Certificate and Bind to IIS

The following self-contained PowerShell script retrieves the machine certificate from
certifactory, installs the full certificate chain into the Windows certificate store, and
binds the certificate to the **Default Web Site** in IIS on port 443.

**Prerequisites**

- Run as **Administrator**
- Machine must be on the **Esri internal network**
- IIS must be installed with the `WebAdministration` module available
  (`Install-WindowsFeature Web-Server` installs both IIS and the module)

```powershell
#Requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [string]$MachineName = $env:COMPUTERNAME,
    [string]$Password    = 'EsriRocks!',
    [string]$SiteName    = 'Default Web Site',
    [int]   $Port        = 443
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Strip .esri.com suffix — certifactory rejects FQDNs
$MachineName = $MachineName -replace '\.esri\.com$', ''

# ---------------------------------------------------------------------------
# Download certificates to a temporary directory
# ---------------------------------------------------------------------------
$TempDir = Join-Path $env:TEMP "esricerts_$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

$EncodedPassword = [Uri]::EscapeDataString($Password)
$PfxUrl          = "https://certifactory.esri.com/api/$MachineName.pfx?password=$EncodedPassword"
$IssuingCaUrl    = 'http://esri_pki.esri.com/crl/Esri%20Issuing%20CA.crt'
$RootCaUrl       = 'https://certifactory.esri.com/api/caroot.crt'

$PfxFile       = Join-Path $TempDir "$MachineName.pfx"
$IssuingCaFile = Join-Path $TempDir 'EsriIssuingCA.cer'
$RootCaFile    = Join-Path $TempDir 'EsriRootCA.cer'

Write-Host '[*] Downloading machine certificate...'        -ForegroundColor Cyan
Invoke-WebRequest -Uri $PfxUrl       -OutFile $PfxFile       -UseBasicParsing
Write-Host '[*] Downloading Esri Issuing CA certificate...' -ForegroundColor Cyan
Invoke-WebRequest -Uri $IssuingCaUrl -OutFile $IssuingCaFile -UseBasicParsing
Write-Host '[*] Downloading Esri Root CA certificate...'   -ForegroundColor Cyan
Invoke-WebRequest -Uri $RootCaUrl    -OutFile $RootCaFile    -UseBasicParsing

# ---------------------------------------------------------------------------
# Install certificates into Windows certificate stores
# ---------------------------------------------------------------------------
Write-Host '[*] Installing certificates...' -ForegroundColor Cyan
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

# Machine PFX -> Personal (My) store — includes the private key
$MachCert = Import-PfxCertificate `
    -FilePath          $PfxFile `
    -CertStoreLocation 'Cert:\LocalMachine\My' `
    -Password          $SecurePassword
Write-Host "    Machine cert thumbprint : $($MachCert.Thumbprint)" -ForegroundColor Green

# Issuing CA -> Intermediate Certification Authorities store
Import-Certificate -FilePath $IssuingCaFile `
    -CertStoreLocation 'Cert:\LocalMachine\CA'   | Out-Null
Write-Host '    Esri Issuing CA installed.' -ForegroundColor Green

# Root CA -> Trusted Root Certification Authorities store
Import-Certificate -FilePath $RootCaFile `
    -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
Write-Host '    Esri Root CA installed.'   -ForegroundColor Green

# ---------------------------------------------------------------------------
# Configure the IIS HTTPS binding on the specified site and port
# ---------------------------------------------------------------------------
Write-Host "[*] Configuring IIS HTTPS binding on '$SiteName' port $Port..." -ForegroundColor Cyan
Import-Module WebAdministration -ErrorAction Stop

# Remove any pre-existing HTTPS binding on this port to avoid duplicates
$ExistingBinding = Get-WebBinding -Name $SiteName -Protocol 'https' -Port $Port `
    -ErrorAction SilentlyContinue
if ($ExistingBinding) {
    Remove-WebBinding -Name $SiteName -Protocol 'https' -Port $Port
    Write-Host "    Removed existing HTTPS binding on port $Port." -ForegroundColor Yellow
}

# Create the new HTTPS binding then attach the certificate
New-WebBinding -Name $SiteName -Protocol 'https' -Port $Port -IPAddress '*' -SslFlags 0
$Binding = Get-WebBinding -Name $SiteName -Protocol 'https' -Port $Port
$Binding.AddSslCertificate($MachCert.Thumbprint, 'My')
Write-Host "    HTTPS binding created and certificate attached." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Clean up temporary files and report
# ---------------------------------------------------------------------------
Remove-Item -Path $TempDir -Recurse -Force

Write-Host ''
Write-Host 'Done.' -ForegroundColor White
Write-Host "  Site       : $SiteName"
Write-Host "  Port       : $Port"
Write-Host "  Thumbprint : $($MachCert.Thumbprint)"
```

**Running the script**

```powershell
# Defaults: current machine name, port 443, Default Web Site
.\install_iis_certificate.ps1

# Override machine name and password
.\install_iis_certificate.ps1 -MachineName myserver -Password 'S3cret!'

# Target a different site or port
.\install_iis_certificate.ps1 -SiteName 'My Site' -Port 8443
```
