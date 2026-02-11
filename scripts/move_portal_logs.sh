#!/bin/bash
#
# move-arcgis-logs.sh
# Automates relocating the ArcGIS Server or Portal log directory on Linux
#

# Display help documentation
show_help() {
    cat << EOF
Usage: $(basename "$0") -t TYPE -h HOST -u USER -p PASS [OPTIONS]

Automates relocating the ArcGIS Server or Portal log directory on Linux.

Required Arguments:
  -t, --type TYPE       ArcGIS type: "server" or "portal"
  -h, --host HOST       ArcGIS hostname (e.g., yourarcgis.domain.com)
  -u, --username USER   Admin username
  -p, --password PASS   Admin password

Optional Arguments:
  -l, --log-dir DIR     Custom log directory path
                        Default: /var/opt/arcgis/server/logs (server)
                                 /var/opt/arcgis/portal/logs (portal)
  -P, --port PORT       Custom port number
                        Default: 6443 (server), 7443 (portal)
  --help                Display this help message and exit

Examples:
  # Move portal logs to default location
  $(basename "$0") -t portal -h myportal.example.com -u admin -p secret

  # Move server logs to custom location
  $(basename "$0") -t server -h myserver.example.com -u admin -p secret -l /custom/path

EOF
    exit 0
}

# Parse command line arguments
ARCGIS_TYPE=""
ARCGIS_HOST=""
ARCGIS_ADMIN=""
ARCGIS_PASSWORD=""
CUSTOM_LOG_DIR=""
CUSTOM_PORT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            ARCGIS_TYPE="$2"
            shift 2
            ;;
        -h|--host)
            ARCGIS_HOST="$2"
            shift 2
            ;;
        -u|--username)
            ARCGIS_ADMIN="$2"
            shift 2
            ;;
        -p|--password)
            ARCGIS_PASSWORD="$2"
            shift 2
            ;;
        -l|--log-dir)
            CUSTOM_LOG_DIR="$2"
            shift 2
            ;;
        -P|--port)
            CUSTOM_PORT="$2"
            shift 2
            ;;
        --help)
            show_help
            ;;
        *)
            echo "ERROR: Unknown parameter: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$ARCGIS_TYPE" ] || [ -z "$ARCGIS_HOST" ] || [ -z "$ARCGIS_ADMIN" ] || [ -z "$ARCGIS_PASSWORD" ]; then
    echo "ERROR: Missing required parameters."
    echo "Use --help for usage information."
    exit 1
fi

# Validate type parameter
if [ "$ARCGIS_TYPE" != "server" ] && [ "$ARCGIS_TYPE" != "portal" ]; then
    echo "ERROR: --type must be 'server' or 'portal'"
    exit 1
fi

# Auto-configure based on type
if [ "$ARCGIS_TYPE" = "server" ]; then
    ARCGIS_PORT="${CUSTOM_PORT:-6443}"
    NEW_LOG_DIR="${CUSTOM_LOG_DIR:-/var/opt/arcgis/server/logs}"
    SERVICE_NAME="arcgisserver"
    ADMIN_API_BASE="https://${ARCGIS_HOST}:${ARCGIS_PORT}/arcgis/admin"
    OLD_LOG_DIR_DEFAULT="/arcgis/server/usr/logs"
elif [ "$ARCGIS_TYPE" = "portal" ]; then
    ARCGIS_PORT="${CUSTOM_PORT:-7443}"
    NEW_LOG_DIR="${CUSTOM_LOG_DIR:-/var/opt/arcgis/portal/logs}"
    SERVICE_NAME="arcgisportal"
    ADMIN_API_BASE="https://${ARCGIS_HOST}:${ARCGIS_PORT}/arcgis/portaladmin"
    OLD_LOG_DIR_DEFAULT="/arcgis/portal/usr/arcgisportal/logs"
else
    echo "ERROR: ARCGIS_TYPE must be set to 'server' or 'portal'"
    exit 1
fi

echo "=== ArcGIS $ARCGIS_TYPE Log Relocation Script ==="

# Step 1 — Create target directory
echo "[1/6] Creating new log directory at $NEW_LOG_DIR ..."
sudo mkdir -p "$NEW_LOG_DIR"
sudo chown root:arcgis "$NEW_LOG_DIR"
sudo chmod 775 "$NEW_LOG_DIR"

# Step 2 — Get admin token
echo "[2/6] Requesting admin token ..."
if [ "$ARCGIS_TYPE" = "server" ]; then
    TOKEN=$(curl -sk \
      -d "username=${ARCGIS_ADMIN}" \
      -d "password=${ARCGIS_PASSWORD}" \
      -d "client=referer" \
      -d "referer=https://${ARCGIS_HOST}" \
      -d "f=json" \
      "${ADMIN_API_BASE}/generateToken" \
      | grep -oP '(?<="token":")[^"]+')
else
    TOKEN=$(curl -sk \
      -d "username=${ARCGIS_ADMIN}" \
      -d "password=${ARCGIS_PASSWORD}" \
      -d "client=referer" \
      -d "referer=https://${ARCGIS_HOST}" \
      -d "f=json" \
      "https://${ARCGIS_HOST}:${ARCGIS_PORT}/arcgis/sharing/rest/generateToken" \
      | grep -oP '(?<="token":")[^"]+')
fi

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to obtain admin token. Check credentials."
    exit 1
fi

echo "Token acquired."

# Step 3 — Update log settings via Admin API
echo "[3/6] Updating $ARCGIS_TYPE log directory path in Admin API ..."
if [ "$ARCGIS_TYPE" = "server" ]; then
    EDIT_RESPONSE=$(curl -sk \
      -d "f=json" \
      -d "logDir=${NEW_LOG_DIR}" \
      -d "token=${TOKEN}" \
      "${ADMIN_API_BASE}/logs/settings/edit")
else
    EDIT_RESPONSE=$(curl -sk \
      -d "f=json" \
      -d "logDir=${NEW_LOG_DIR}" \
      -d "token=${TOKEN}" \
      "${ADMIN_API_BASE}/logs/settings/edit")
fi

echo "Response: $EDIT_RESPONSE"

# Step 4 — Move existing logs (optional but recommended)
OLD_LOG_DIR=$(echo "$EDIT_RESPONSE" | grep -oP '"oldLogDir":"\K[^"]+' || echo "$OLD_LOG_DIR_DEFAULT")

echo "[4/6] Moving existing logs from $OLD_LOG_DIR ..."
if [ -d "$OLD_LOG_DIR" ]; then
    sudo rsync -av "$OLD_LOG_DIR/" "$NEW_LOG_DIR/"
else
    echo "WARNING: Old log directory not found, skipping migration."
fi

# Step 5 — Restart Portal
echo "[5/6] Restarting $ARCGIS_TYPE service ..."
sudo systemctl restart "$SERVICE_NAME"

echo "[6/6] Done!"

echo "=== $ARCGIS_TYPE log directory successfully moved to: $NEW_LOG_DIR ==="
``