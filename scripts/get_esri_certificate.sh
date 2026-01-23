#!/bin/bash
#
# Esri Internal Certificate Generator
#
# This script retrieves certificates from Esri's internal certifactory and
# creates a full-chain PFX file suitable for use with Tomcat and other services.
#
# Prerequisites:
#   - Machine must be on the Esri internal network
#   - openssl must be installed
#   - curl must be installed
#
# Usage:
#   ./get_esri_certificate.sh <pfx_password> [output_path] [machine_name]
#
#   pfx_password  - Required. Password for the PFX certificates (input and output)
#   output_path   - Optional. Path for output file. Defaults to ./tomcat_fullchain.pfx
#   machine_name  - Optional. Machine name for certificate. Defaults to hostname
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[X]${NC} $1"
}

# Display help
show_help() {
    echo "Usage: $0 <pfx_password> [output_path] [machine_name]"
    echo ""
    echo "Arguments:"
    echo "  pfx_password    Required. Password for the PFX certificates (input and output)"
    echo "  output_path     Optional. Path for output file (relative or absolute)"
    echo "                  Defaults to: ./tomcat_fullchain.pfx"
    echo "  machine_name    Optional. Machine name for the certificate request"
    echo "                  Defaults to: current hostname (FQDN)"
    echo ""
    echo "Examples:"
    echo "  $0 'MyP@ssword'"
    echo "  $0 'MyP@ssword' /tmp/mycert.pfx"
    echo "  $0 'MyP@ssword' ./certs/tomcat.pfx myserver.esri.com"
    echo ""
    exit 0
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

# Validate required parameter
if [[ -z "$1" ]]; then
    print_error "PFX password is required"
    echo ""
    show_help
fi

# Parameters
PFX_PASSWORD="$1"
OUTPUT_PATH="${2:-./tomcat_fullchain.pfx}"
MACHINE_NAME="${3:-}"

# If machine name not provided, get it from the system
if [[ -z "$MACHINE_NAME" ]]; then
    # Try to get FQDN first
    MACHINE_NAME=$(hostname -f 2>/dev/null || hostname)
    
    # If hostname doesn't include domain, try to append .esri.com
    if [[ ! "$MACHINE_NAME" == *.* ]]; then
        MACHINE_NAME="${MACHINE_NAME}.esri.com"
    fi
fi

# Resolve output path
# If path is relative, make it relative to current working directory
if [[ "$OUTPUT_PATH" != /* ]]; then
    OUTPUT_PATH="$(pwd)/$OUTPUT_PATH"
fi

# Ensure output directory exists
OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
mkdir -p "$OUTPUT_DIR"

# Create temporary working directory
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

print_status "Esri Internal Certificate Generator"
echo "=============================================="
echo "  Machine Name: $MACHINE_NAME"
echo "  Output Path:  $OUTPUT_PATH"
echo "  Working Dir:  $WORK_DIR"
echo "=============================================="
echo ""

# Step 1: Install Esri Root CA certificates (if running as root/sudo available)
print_status "Installing Esri Root CA certificates..."
if [[ -w "/usr/local/share/ca-certificates/" ]] || [[ $EUID -eq 0 ]]; then
    sudo curl -sL http://certifactory.esri.com/certs/esriroot.crt \
        --output /usr/local/share/ca-certificates/esri_root_ca.crt
    sudo curl -sL http://certifactory.esri.com/certs/caroot.crt \
        --output /usr/local/share/ca-certificates/esri_issuing_ca.crt
    sudo update-ca-certificates 2>/dev/null || true
    print_status "Root CA certificates installed"
else
    print_warning "Cannot install system CA certificates (not running as root)"
    print_warning "Continuing with --insecure flag for curl..."
    CURL_OPTS="--insecure"
fi

cd "$WORK_DIR"

# Step 2: Download server PFX certificate
# Strip .esri.com from machine name for the API request (certifactory expects short name)
API_MACHINE_NAME="${MACHINE_NAME%.esri.com}"
print_status "Downloading server certificate for $API_MACHINE_NAME..."
# URL encode the password for the query string
ENCODED_PASSWORD=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PFX_PASSWORD'))" 2>/dev/null \
    || echo "$PFX_PASSWORD")
curl ${CURL_OPTS:-} -sf -o server.pfx \
    "https://certifactory.esri.com/api/${API_MACHINE_NAME}.pfx?password=${ENCODED_PASSWORD}" \
    || { print_error "Failed to download server certificate. Check machine name and network."; exit 1; }
print_status "Server certificate downloaded"

# Step 3: Download intermediate certificate
print_status "Downloading intermediate certificate..."
curl ${CURL_OPTS:-} -sf -o esri_intermediate.crt \
    "http://esri_pki.esri.com/crl/Esri%20Issuing%20CA.crt" \
    || { print_error "Failed to download intermediate certificate"; exit 1; }
print_status "Intermediate certificate downloaded"

# Step 4: Download CA (domain) root certificate
print_status "Downloading CA root certificate..."
curl ${CURL_OPTS:-} -sf -o caroot.crt \
    "https://certifactory.esri.com/api/caroot.crt" \
    || { print_error "Failed to download CA root certificate"; exit 1; }
print_status "CA root certificate downloaded"

# Step 5: Extract server certificate and private key from PFX
print_status "Extracting server certificate and private key..."
openssl pkcs12 -in server.pfx \
    -clcerts -nokeys \
    -out server.crt \
    -passin pass:"$PFX_PASSWORD" \
    -legacy 2>/dev/null \
    || openssl pkcs12 -in server.pfx \
        -clcerts -nokeys \
        -out server.crt \
        -passin pass:"$PFX_PASSWORD"

openssl pkcs12 -in server.pfx \
    -nocerts -nodes \
    -out server.key \
    -passin pass:"$PFX_PASSWORD" \
    -legacy 2>/dev/null \
    || openssl pkcs12 -in server.pfx \
        -nocerts -nodes \
        -out server.key \
        -passin pass:"$PFX_PASSWORD"
print_status "Certificate and key extracted"

# Step 6: Normalize the intermediate and root certificates
print_status "Normalizing intermediate and root certificates..."

# Try DER format first, fall back to PEM
openssl x509 -inform DER -in esri_intermediate.crt -out esri_intermediate.pem 2>/dev/null \
    || cp esri_intermediate.crt esri_intermediate.pem

openssl x509 -inform DER -in caroot.crt -out esri_root.pem 2>/dev/null \
    || cp caroot.crt esri_root.pem

print_status "Certificates normalized"

# Step 7: Build the full chain bundle
print_status "Building full chain bundle..."
cat server.crt esri_intermediate.pem esri_root.pem > fullchain.crt
print_status "Full chain bundle created"

# Step 8: Create the new PFX file with full chain
print_status "Creating full-chain PFX file..."
openssl pkcs12 -export \
    -inkey server.key \
    -in server.crt \
    -certfile esri_intermediate.pem \
    -certfile esri_root.pem \
    -name tomcat \
    -out tomcat_fullchain.p12 \
    -passout pass:"$PFX_PASSWORD" \
    -legacy 2>/dev/null \
    || openssl pkcs12 -export \
        -inkey server.key \
        -in server.crt \
        -certfile esri_intermediate.pem \
        -certfile esri_root.pem \
        -name tomcat \
        -out tomcat_fullchain.p12 \
        -passout pass:"$PFX_PASSWORD"

# Step 9: Copy to output location
print_status "Copying certificate to output location..."
cp tomcat_fullchain.p12 "$OUTPUT_PATH"

# Verify the certificate
print_status "Verifying certificate..."
openssl pkcs12 -in "$OUTPUT_PATH" -nokeys -passin pass:"$PFX_PASSWORD" -legacy 2>/dev/null \
    | openssl x509 -noout -subject -issuer -dates 2>/dev/null \
    || openssl pkcs12 -in "$OUTPUT_PATH" -nokeys -passin pass:"$PFX_PASSWORD" \
        | openssl x509 -noout -subject -issuer -dates

echo ""
echo "=============================================="
print_status "Certificate generation complete!"
echo "=============================================="
echo ""
echo "Output file: $OUTPUT_PATH"
echo ""
echo "Certificate details:"
openssl pkcs12 -in "$OUTPUT_PATH" -nokeys -passin pass:"$PFX_PASSWORD" -legacy 2>/dev/null \
    | openssl x509 -noout -text 2>/dev/null \
    | grep -E "Subject:|Issuer:|Not Before:|Not After:" \
    | head -4 \
    || openssl pkcs12 -in "$OUTPUT_PATH" -nokeys -passin pass:"$PFX_PASSWORD" \
        | openssl x509 -noout -text \
        | grep -E "Subject:|Issuer:|Not Before:|Not After:" \
        | head -4
echo ""
