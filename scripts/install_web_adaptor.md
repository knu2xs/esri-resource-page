# ArcGIS Web Adaptor Installation Script

This script automates the installation of Apache Tomcat and ArcGIS Web Adaptor on Ubuntu systems following best practices for file system hierarchy and security.

## Prerequisites

Before running the script, ensure the following files are downloaded to `/tmp`:

| File | Description |
|------|-------------|
| `apache-tomcat-*.tar.gz` | Apache Tomcat binary distribution (any version) |
| `Web_Adapter_for_ArcGIS_Linux_*.tar.gz` | ArcGIS Web Adaptor installer (any version) |
| `*.p12` or `*.pfx` | SSL/TLS certificate file |

### System Requirements

- Ubuntu 20.04 LTS or later
- Root or sudo access
- Internet access (for package installation)

## Usage

### Option 1: Command Line Password

Pass the PFX certificate password as a command line argument:

```bash
./install_web_adaptor.sh --pfx-password "YourPassword"
```

### Option 2: Configuration File

Create a configuration file at `/tmp/config.ini`:

```ini
PFX_PASSWORD=YourPassword
```

Then run the script without arguments:

```bash
./install_web_adaptor.sh
```

### Help

Display usage information:

```bash
./install_web_adaptor.sh --help
```

## What the Script Does

The script performs the following installation steps in order:

1. **Update System Packages** — Runs `apt update` and `apt upgrade`
2. **Configure Firewall** — Enables UFW and allows ports 22, 443, and 8080
3. **Create Service User** — Creates the `tomcat` user and group
4. **Install Java** — Installs OpenJDK 17
5. **Install Authbind** — Configures authbind to allow Tomcat to bind to port 443
6. **Install Tomcat** — Extracts and configures Tomcat with FHS-compliant directory structure:
   - `/opt/tomcat` — Application binaries (read-only)
   - `/etc/opt/tomcat` — Configuration files
   - `/var/opt/tomcat` — Variable data (logs, temp, work, webapps)
7. **Configure Permissions** — Sets appropriate ownership and permissions for each directory
8. **Create Systemd Service** — Creates and enables the Tomcat systemd service
9. **Configure SSL/TLS** — Copies the PFX certificate and configures Tomcat for HTTPS on port 443
10. **Enable Remote Access** — Configures Tomcat manager apps for remote access
11. **Start Tomcat** — Starts and enables the Tomcat service
12. **Install Web Adaptor** — Runs the ArcGIS Web Adaptor silent installer
13. **Deploy WAR Files** — Deploys Portal and Server Web Adaptor WAR files to Tomcat

## Post-Installation

After the script completes:

1. Access Tomcat at `https://<your_server>/`
2. Install Portal for ArcGIS and/or ArcGIS Server on their respective machines
3. Configure the Web Adapters after installing the respective components

!!! warning
    Do **NOT** configure the Web Adapters until Portal for ArcGIS and/or ArcGIS Server are installed and running. The Web Adapter configuration process requires communication with the respective component.

## Directory Structure

After installation, the following directory structure is created:

```
/opt/tomcat/                    # Tomcat binaries (root:tomcat, 750)
├── bin/
├── lib/
├── conf -> /etc/opt/tomcat     # Symlink to config
├── logs -> /var/opt/tomcat/logs
├── temp -> /var/opt/tomcat/temp
├── work -> /var/opt/tomcat/work
└── webapps -> /var/opt/tomcat/webapps

/etc/opt/tomcat/                # Configuration files (root:tomcat, 750)
├── server.xml
├── tomcat-users.xml
├── cert/
│   └── tomcat_fullchain.p12
└── ...

/var/opt/tomcat/                # Variable data (tomcat:tomcat, 750)
├── logs/
├── temp/
├── work/
└── webapps/
    ├── portal.war
    └── server.war

/opt/arcgis/webadaptor/         # Web Adaptor installation (tomcat:tomcat, 750)
├── portal/
└── server/
```

## Troubleshooting

### Check Tomcat Service Status

```bash
sudo systemctl status tomcat
```

### View Tomcat Logs

```bash
sudo tail -f /var/opt/tomcat/logs/catalina.out
```

### Restart Tomcat

```bash
sudo systemctl restart tomcat
```

### Verify SSL Certificate

```bash
openssl s_client -connect localhost:443 -showcerts
```
