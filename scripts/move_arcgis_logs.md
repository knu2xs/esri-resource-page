# ArcGIS Log Directory Relocation Script

This script automates the process of relocating log directories for ArcGIS Server or ArcGIS Portal for ArcGIS on Linux systems. It handles token generation, log settings updates, migration of existing logs, and service restarts.

## Prerequisites

- ArcGIS Server or Portal for ArcGIS installed on Linux
- `curl` must be installed
- `rsync` must be installed
- `sudo` privileges for directory creation and service management
- Admin credentials for the ArcGIS Server or Portal

## Usage

```bash
./move_portal_logs.sh -t TYPE -h HOST -u USER -p PASS [OPTIONS]
```

### Parameters

| Parameter | Short | Long | Required | Description |
|-----------|-------|------|----------|-------------|
| Type | `-t` | `--type` | **Yes** | ArcGIS type: `"server"` or `"portal"` |
| Host | `-h` | `--host` | **Yes** | ArcGIS hostname (e.g., `yourarcgis.domain.com`) |
| Username | `-u` | `--username` | **Yes** | Admin username |
| Password | `-p` | `--password` | **Yes** | Admin password |
| Log Directory | `-l` | `--log-dir` | No | Custom log directory path<br/>**Default Server:** `/var/opt/arcgis/server/logs`<br/>**Default Portal:** `/var/opt/arcgis/portal/logs` |
| Port | `-P` | `--port` | No | Custom port number<br/>**Default Server:** `6443`<br/>**Default Portal:** `7443` |
| Help | | `--help` | No | Display help message and exit |

### Examples

**Basic usage - Move Portal logs to default location:**
```bash
./move_portal_logs.sh -t portal -h myportal.example.com -u admin -p 'MyPassword'
```

**Move Server logs to default location:**
```bash
./move_portal_logs.sh -t server -h myserver.example.com -u admin -p 'MyPassword'
```

**Move Portal logs to custom location:**
```bash
./move_portal_logs.sh -t portal -h myportal.example.com -u admin -p 'MyPassword' -l /custom/logs/portal
```

**Specify custom port:**
```bash
./move_portal_logs.sh -t server -h myserver.example.com -u admin -p 'MyPassword' -P 6443
```

**Using long parameter names:**
```bash
./move_portal_logs.sh --type portal --host myportal.example.com --username admin --password 'MyPassword' --log-dir /var/log/arcgis/portal
```

## What the Script Does

1. **Creates target directory** — Creates the new log directory with proper permissions (`root:arcgis`, `775`)
2. **Generates admin token** — Authenticates with the ArcGIS Server or Portal Admin API
3. **Updates log settings** — Configures the new log directory path via the Admin API
4. **Migrates existing logs** — Uses `rsync` to copy existing log files to the new location
5. **Restarts service** — Restarts the ArcGIS service (`arcgisserver` or `arcgisportal`)
6. **Confirmation** — Displays success message with the new log directory path

## Default Configurations

### ArcGIS Server
- **Port:** `6443`
- **Log Directory:** `/var/opt/arcgis/server/logs`
- **Service Name:** `arcgisserver`
- **Admin API:** `https://{host}:6443/arcgis/admin`
- **Old Log Default:** `/arcgis/server/usr/logs`

### ArcGIS Portal
- **Port:** `7443`
- **Log Directory:** `/var/opt/arcgis/portal/logs`
- **Service Name:** `arcgisportal`
- **Admin API:** `https://{host}:7443/arcgis/portaladmin`
- **Old Log Default:** `/arcgis/portal/usr/arcgisportal/logs`

## Directory Permissions

The script automatically sets the following permissions on the new log directory:

- **Owner:** `root:arcgis`
- **Permissions:** `775` (rwxrwxr-x)

This allows:
- Root user has full access
- Members of the `arcgis` group have full access
- Others have read and execute access

## Troubleshooting

### Token generation fails

- Verify the hostname is correct and accessible
- Check that admin credentials are correct
- Ensure the port is correct (6443 for Server, 7443 for Portal)
- Verify SSL certificate is valid or use `-k` flag for self-signed certificates

### Directory creation fails

- Ensure you have sudo privileges
- Check that the parent directory exists and is writable
- Verify disk space is available

### Service restart fails

- Check the service name is correct (`arcgisserver` or `arcgisportal`)
- Verify systemctl is available
- Check service status: `sudo systemctl status arcgisserver` or `sudo systemctl status arcgisportal`
- Review system logs: `sudo journalctl -u arcgisserver` or `sudo journalctl -u arcgisportal`

### Log migration issues

- Ensure rsync is installed: `which rsync`
- Check that the old log directory exists
- Verify sufficient disk space in the new location
- Review rsync output for specific errors

### Verify the log directory change

**For ArcGIS Server:**
```bash
curl -sk "https://yourserver.com:6443/arcgis/admin/logs/settings?f=json&token=YOUR_TOKEN" | jq .
```

**For ArcGIS Portal:**
```bash
curl -sk "https://yourportal.com:7443/arcgis/portaladmin/logs/settings?f=json&token=YOUR_TOKEN" | jq .
```

### Check new log directory

```bash
ls -la /var/opt/arcgis/portal/logs
# or
ls -la /var/opt/arcgis/server/logs
```

## Security Considerations

- **Password handling:** The password is passed as a command-line argument and may be visible in process listings. Consider using environment variables or secure credential storage in production.
- **Token security:** Admin tokens are generated but not stored. They're used only for the API calls during script execution.
- **HTTPS verification:** The script uses `-k` flag with curl to skip SSL verification. In production, ensure proper SSL certificates are configured.

## Notes

- The script requires `sudo` privileges for directory creation, permission changes, and service restarts
- Existing logs are copied (not moved) to preserve originals during migration
- The service restart will cause brief downtime for the ArcGIS Server or Portal
- Log rotation settings are preserved and will continue to work with the new directory
