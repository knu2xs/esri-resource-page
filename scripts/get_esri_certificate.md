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
