#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads machine, Issuing CA, and Root CA certificates from Esri's certifactory
    with file extensions suitable for IIS import.

.DESCRIPTION
    Retrieves three certificate files from certifactory.esri.com:

      - <MachineName>.pfx  : machine certificate with private key  (Personal store in IIS)
      - EsriIssuingCA.cer  : Esri Issuing CA certificate            (Intermediate CA store)
      - EsriRootCA.cer     : Esri Root CA certificate               (Trusted Root store)

    The machine name is auto-detected from $env:COMPUTERNAME unless overridden.
    Must be run on the Esri internal network.

.PARAMETER OutputPath
    Directory where certificate files will be saved. Defaults to the current directory.

.PARAMETER MachineName
    Short machine name to request the certificate for. Defaults to $env:COMPUTERNAME.
    Do not include the .esri.com domain — certifactory adds it automatically.

.PARAMETER Password
    Password for the PFX certificate. Defaults to 'EsriRocks!'.

.EXAMPLE
    .\get_esri_certificate.ps1

.EXAMPLE
    .\get_esri_certificate.ps1 -OutputPath C:\Certs

.EXAMPLE
    .\get_esri_certificate.ps1 -OutputPath C:\Certs -MachineName myserver
#>
[CmdletBinding()]
param(
    [string]$OutputPath   = '.',
    [string]$MachineName  = '',
    [string]$Password = 'EsriRocks!' # Default password for the PFX file (change as needed)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
$CertifactoryBase = 'https://certifactory.esri.com/api'
$IssuingCaUrl     = 'http://esri_pki.esri.com/crl/Esri%20Issuing%20CA.crt'
$RootCaUrl        = "$CertifactoryBase/caroot.crt"

# ---------------------------------------------------------------------------
# Resolve machine name
# ---------------------------------------------------------------------------
if (-not $MachineName) {
    $MachineName = $env:COMPUTERNAME
}
# Strip .esri.com suffix if the caller passed an FQDN — certifactory rejects FQDNs
$MachineName = $MachineName -replace '\.esri\.com$', ''

# ---------------------------------------------------------------------------
# Resolve output directory
# ---------------------------------------------------------------------------
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if (-not (Test-Path -LiteralPath $OutputPath -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Build URLs and output file paths
# ---------------------------------------------------------------------------
$EncodedPassword = [Uri]::EscapeDataString($Password)
$PfxUrl          = "$CertifactoryBase/$MachineName.pfx?password=$EncodedPassword"

$PfxFile       = Join-Path $OutputPath "$MachineName.pfx"
$IssuingCaFile = Join-Path $OutputPath 'EsriIssuingCA.cer'
$RootCaFile    = Join-Path $OutputPath 'EsriRootCA.cer'

# ---------------------------------------------------------------------------
# Download helper
# ---------------------------------------------------------------------------
function Get-RemoteFile {
    param(
        [string]$Uri,
        [string]$Destination,
        [string]$Label
    )
    Write-Host "[*] Downloading $Label ..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing
        Write-Host "    Saved: $Destination" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download $Label`nURL : $Uri`nError: $_"
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Esri Certificate Downloader (IIS)' -ForegroundColor White
Write-Host ('=' * 50)
Write-Host "  Machine Name : $MachineName"
Write-Host "  Output Path  : $OutputPath"
Write-Host ('=' * 50)
Write-Host ''

Get-RemoteFile -Uri $PfxUrl       -Destination $PfxFile       -Label "machine PFX  ($MachineName.pfx)"
Get-RemoteFile -Uri $IssuingCaUrl -Destination $IssuingCaFile -Label 'Esri Issuing CA certificate  (EsriIssuingCA.cer)'
Get-RemoteFile -Uri $RootCaUrl    -Destination $RootCaFile    -Label 'Esri Root CA certificate  (EsriRootCA.cer)'

Write-Host ''
Write-Host 'Done. Certificate files ready for IIS import:' -ForegroundColor White
Write-Host ''
Write-Host "  Machine PFX     : $PfxFile"    -ForegroundColor Yellow
Write-Host "  Issuing CA .cer : $IssuingCaFile" -ForegroundColor Yellow
Write-Host "  Root CA .cer    : $RootCaFile"    -ForegroundColor Yellow
Write-Host ''
Write-Host 'IIS Import Notes:' -ForegroundColor White
Write-Host '  .pfx           -> Personal (My) store  [includes private key]'
Write-Host '  .cer (Issuing) -> Intermediate Certification Authorities store'
Write-Host '  .cer (Root)    -> Trusted Root Certification Authorities store'
Write-Host ''
