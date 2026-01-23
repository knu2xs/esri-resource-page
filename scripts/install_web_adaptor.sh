#!/bin/bash
#
# ArcGIS Web Adaptor Installation Script for Ubuntu
# 
# This script automates the installation of Apache Tomcat and ArcGIS Web Adaptor
# on Ubuntu systems following best practices for file system hierarchy and security.
#
# Prerequisites:
#   - Ubuntu 20.04 LTS or later
#   - Root or sudo access
#   - Tomcat tar.gz downloaded to /tmp (e.g., apache-tomcat-*.tar.gz)
#   - ArcGIS Web Adaptor tar.gz downloaded to /tmp (e.g., Web_Adapter_for_ArcGIS_Linux_*.tar.gz)
#   - PFX certificate file in /tmp (e.g., tomcat_fullchain.p12)
#   - Either config.ini with PFX_PASSWORD or pass password as command line argument
#
# Usage:
#   ./install_web_adaptor.sh [--pfx-password <password>]
#   
#   Or create /tmp/config.ini with:
#     PFX_PASSWORD=your_password_here
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CONFIG_FILE="/tmp/config.ini"
TOMCAT_USER="tomcat"
TOMCAT_GROUP="tomcat"
JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

# Directories following FHS
OPT_TOMCAT="/opt/tomcat"
ETC_TOMCAT="/etc/opt/tomcat"
VAR_TOMCAT="/var/opt/tomcat"
OPT_ARCGIS="/opt/arcgis"

# Parse command line arguments
PFX_PASSWORD=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --pfx-password)
            PFX_PASSWORD="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--pfx-password <password>]"
            echo ""
            echo "Options:"
            echo "  --pfx-password    Password for the PFX certificate file"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Alternatively, create /tmp/config.ini with:"
            echo "  PFX_PASSWORD=your_password_here"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Read config file if password not provided via command line
if [[ -z "$PFX_PASSWORD" && -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}Reading configuration from $CONFIG_FILE...${NC}"
    source "$CONFIG_FILE"
fi

# Validate PFX password is set
if [[ -z "$PFX_PASSWORD" ]]; then
    echo -e "${RED}Error: PFX_PASSWORD not set.${NC}"
    echo "Either provide --pfx-password argument or create $CONFIG_FILE with PFX_PASSWORD=<password>"
    exit 1
fi

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

# Function to check for required files
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for Tomcat tar.gz
    TOMCAT_TARBALL=$(ls /tmp/apache-tomcat-*.tar.gz 2>/dev/null | head -1)
    if [[ -z "$TOMCAT_TARBALL" ]]; then
        print_error "Tomcat tar.gz not found in /tmp"
        exit 1
    fi
    print_status "Found Tomcat: $TOMCAT_TARBALL"
    
    # Check for Web Adaptor tar.gz
    WEBADAPTOR_TARBALL=$(ls /tmp/Web_Adapter_for_ArcGIS_Linux_*.tar.gz 2>/dev/null | head -1)
    if [[ -z "$WEBADAPTOR_TARBALL" ]]; then
        print_error "ArcGIS Web Adaptor tar.gz not found in /tmp"
        exit 1
    fi
    print_status "Found Web Adaptor: $WEBADAPTOR_TARBALL"
    
    # Check for PFX certificate
    PFX_FILE=$(ls /tmp/*.p12 /tmp/*.pfx 2>/dev/null | head -1)
    if [[ -z "$PFX_FILE" ]]; then
        print_error "PFX certificate file (.p12 or .pfx) not found in /tmp"
        exit 1
    fi
    print_status "Found PFX certificate: $PFX_FILE"
}

# Update system packages
update_system() {
    print_status "Updating system packages..."
    sudo apt update
    sudo apt upgrade -y
}

# Configure firewall
configure_firewall() {
    print_status "Configuring firewall (UFW)..."
    sudo ufw allow 22,443,8080/tcp
    sudo ufw --force enable
}

# Create tomcat user
create_tomcat_user() {
    print_status "Creating tomcat service user..."
    if id "$TOMCAT_USER" &>/dev/null; then
        print_warning "User $TOMCAT_USER already exists, skipping creation"
    else
        sudo useradd -s /bin/false -m -U "$TOMCAT_USER"
    fi
}

# Install Java
install_java() {
    print_status "Installing OpenJDK 17..."
    sudo apt install openjdk-17-jdk -y
    java -version
}

# Install authbind
install_authbind() {
    print_status "Installing and configuring authbind..."
    sudo apt install authbind -y
    sudo touch /etc/authbind/byport/443
    sudo chown ${TOMCAT_USER}:${TOMCAT_GROUP} /etc/authbind/byport/443
    sudo chmod 500 /etc/authbind/byport/443
}

# Install Tomcat
install_tomcat() {
    print_status "Installing Apache Tomcat..."
    
    # Create directory structure
    sudo mkdir -p "$OPT_TOMCAT"
    sudo mkdir -p "$ETC_TOMCAT"
    sudo mkdir -p "${VAR_TOMCAT}"/{logs,temp,work,webapps}
    
    # Extract Tomcat to /opt/tomcat
    sudo tar xf "$TOMCAT_TARBALL" -C "$OPT_TOMCAT" --strip-components=1
    
    # Move configuration files to /etc/opt/tomcat
    sudo mv ${OPT_TOMCAT}/conf/* "$ETC_TOMCAT"/
    sudo rmdir ${OPT_TOMCAT}/conf
    sudo ln -sf "$ETC_TOMCAT" ${OPT_TOMCAT}/conf
    
    # Move variable directories to /var/opt/tomcat and create symlinks
    sudo rm -rf ${OPT_TOMCAT}/logs ${OPT_TOMCAT}/temp ${OPT_TOMCAT}/work ${OPT_TOMCAT}/webapps
    sudo ln -sf ${VAR_TOMCAT}/logs ${OPT_TOMCAT}/logs
    sudo ln -sf ${VAR_TOMCAT}/temp ${OPT_TOMCAT}/temp
    sudo ln -sf ${VAR_TOMCAT}/work ${OPT_TOMCAT}/work
    sudo ln -sf ${VAR_TOMCAT}/webapps ${OPT_TOMCAT}/webapps
    
    # Extract webapps to new location
    sudo tar xf "$TOMCAT_TARBALL" -C /tmp --strip-components=1 --wildcards "*/webapps/*"
    sudo mv /tmp/webapps/* ${VAR_TOMCAT}/webapps/
    sudo rm -rf /tmp/webapps
}

# Configure Tomcat permissions
configure_tomcat_permissions() {
    print_status "Configuring Tomcat permissions..."
    
    # Binary directory - root owns, tomcat can read/execute
    sudo chown -R root:${TOMCAT_GROUP} "$OPT_TOMCAT"/
    sudo chmod -R 750 "$OPT_TOMCAT"/
    sudo chmod -R u+x ${OPT_TOMCAT}/bin
    
    # Configuration directory - root owns, tomcat can read
    sudo chown -R root:${TOMCAT_GROUP} "$ETC_TOMCAT"/
    sudo chmod -R 750 "$ETC_TOMCAT"/
    
    # Variable data directory - tomcat owns (needs write access)
    sudo chown -R ${TOMCAT_USER}:${TOMCAT_GROUP} "$VAR_TOMCAT"/
    sudo chmod -R 750 "$VAR_TOMCAT"/
}

# Create systemd service file
create_tomcat_service() {
    print_status "Creating Tomcat systemd service..."
    
    sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description="Apache Tomcat Web Application Server"
After=network.target

[Service]
Type=forking

# although the service is started as root, it runs as the tomcat user
User=${TOMCAT_USER}
Group=${TOMCAT_GROUP}

# environment variables, where to find Java and Tomcat
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="CATALINA_HOME=${OPT_TOMCAT}"
Environment="CATALINA_BASE=${OPT_TOMCAT}"
Environment="CATALINA_PID=${VAR_TOMCAT}/temp/tomcat.pid"
Environment="CATALINA_TMPDIR=${VAR_TOMCAT}/temp"

# Startup using authbind so can use port 443
ExecStart=/usr/bin/authbind --deep ${OPT_TOMCAT}/bin/startup.sh
ExecStop=${OPT_TOMCAT}/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

# Configure SSL/TLS
configure_ssl() {
    print_status "Configuring SSL/TLS..."
    
    # Create certificate directory
    sudo mkdir -p ${ETC_TOMCAT}/cert
    sudo chown -R root:${TOMCAT_GROUP} ${ETC_TOMCAT}/cert
    sudo chmod -R 750 ${ETC_TOMCAT}/cert
    
    # Copy PFX certificate
    sudo cp "$PFX_FILE" ${ETC_TOMCAT}/cert/tomcat_fullchain.p12
    sudo chown root:${TOMCAT_GROUP} ${ETC_TOMCAT}/cert/tomcat_fullchain.p12
    sudo chmod 640 ${ETC_TOMCAT}/cert/tomcat_fullchain.p12
    
    # Backup original server.xml
    sudo cp ${ETC_TOMCAT}/server.xml ${ETC_TOMCAT}/server.xml.bak
    
    # Add SSL connector to server.xml
    # First, check if SSL connector already exists
    if grep -q 'port="443"' ${ETC_TOMCAT}/server.xml; then
        print_warning "SSL connector already configured in server.xml"
    else
        # Insert SSL connector before the closing </Service> tag
        sudo sed -i '/<\/Service>/i \
    <!-- HTTPS Connector -->\
    <Connector port="443"\
               protocol="org.apache.coyote.http11.Http11NioProtocol"\
               address="0.0.0.0"\
               maxThreads="300"\
               scheme="https"\
               secure="true"\
               SSLEnabled="true">\
\
        <SSLHostConfig protocols="TLSv1.2,TLSv1.3"\
                       honorCipherOrder="true">\
\
            <Certificate\
                certificateKeystoreFile="cert/tomcat_fullchain.p12"\
                certificateKeystoreType="PKCS12"\
                certificateKeystorePassword="'"${PFX_PASSWORD}"'"\
            />\
\
        </SSLHostConfig>\
    </Connector>' ${ETC_TOMCAT}/server.xml
    fi
}

# Enable remote access for Tomcat manager apps
enable_remote_access() {
    print_status "Enabling remote access for Tomcat manager applications..."
    
    # Comment out the RemoteAddrValve in manager and host-manager context.xml files
    for webapp in manager host-manager; do
        CONTEXT_FILE="${VAR_TOMCAT}/webapps/${webapp}/META-INF/context.xml"
        if [[ -f "$CONTEXT_FILE" ]]; then
            sudo sed -i 's/<Valve className="org.apache.catalina.valves.RemoteAddrValve"/<!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"/g' "$CONTEXT_FILE"
            sudo sed -i 's/allow="127\\\.\\d+\\\.\\d+\\\.\\d+|::1|0:0:0:0:0:0:0:1" \/>/allow="127\\.\\d+\\.\\d+\\.\\d+|::1|0:0:0:0:0:0:0:1" \/> -->/g' "$CONTEXT_FILE"
        fi
    done
}

# Start Tomcat service
start_tomcat() {
    print_status "Starting Tomcat service..."
    sudo systemctl daemon-reload
    sudo systemctl start tomcat
    sudo systemctl enable tomcat
    sudo systemctl status tomcat --no-pager
}

# Install ArcGIS Web Adaptor
install_web_adaptor() {
    print_status "Installing ArcGIS Web Adaptor..."
    
    # Unpack the installer
    rm -rf /tmp/WebAdapter
    tar xf "$WEBADAPTOR_TARBALL" -C /tmp
    
    # Create the installation directory
    sudo mkdir -p ${OPT_ARCGIS}/webadaptor
    sudo chown -R ${TOMCAT_USER}:${TOMCAT_GROUP} ${OPT_ARCGIS}/webadaptor
    sudo chmod -R 750 ${OPT_ARCGIS}/webadaptor
    
    # Run the installer as tomcat user
    sudo -u ${TOMCAT_USER} /tmp/WebAdapter/Setup -m silent -l yes -d /opt -v
    
    # Cleanup
    rm -rf /tmp/WebAdapter
}

# Deploy Web Adaptor WAR files
deploy_web_adaptor_wars() {
    print_status "Deploying Portal and Server Web Adaptor WAR files..."
    
    # Create webapps directory for arcgis if it doesn't exist
    sudo mkdir -p ${VAR_TOMCAT}/webapps
    
    # Deploy Portal Web Adaptor
    if [[ -f "${OPT_ARCGIS}/webadaptor/portal/war/arcgis.war" ]]; then
        sudo cp ${OPT_ARCGIS}/webadaptor/portal/war/arcgis.war ${VAR_TOMCAT}/webapps/portal.war
        sudo chown ${TOMCAT_USER}:${TOMCAT_GROUP} ${VAR_TOMCAT}/webapps/portal.war
        print_status "Deployed Portal Web Adaptor as portal.war"
    fi
    
    # Deploy Server Web Adaptor
    if [[ -f "${OPT_ARCGIS}/webadaptor/server/war/arcgis.war" ]]; then
        sudo cp ${OPT_ARCGIS}/webadaptor/server/war/arcgis.war ${VAR_TOMCAT}/webapps/server.war
        sudo chown ${TOMCAT_USER}:${TOMCAT_GROUP} ${VAR_TOMCAT}/webapps/server.war
        print_status "Deployed Server Web Adaptor as server.war"
    fi
    
    # Restart Tomcat to deploy WARs
    sudo systemctl restart tomcat
}

# Main installation flow
main() {
    echo "=============================================="
    echo "ArcGIS Web Adaptor Installation Script"
    echo "=============================================="
    echo ""
    
    check_prerequisites
    update_system
    configure_firewall
    create_tomcat_user
    install_java
    install_authbind
    install_tomcat
    configure_tomcat_permissions
    create_tomcat_service
    configure_ssl
    enable_remote_access
    start_tomcat
    install_web_adaptor
    deploy_web_adaptor_wars
    
    echo ""
    echo "=============================================="
    print_status "Installation complete!"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo "  1. Access Tomcat at https://<your_server>/"
    echo "  2. Install Portal for ArcGIS and/or ArcGIS Server"
    echo "  3. Configure the Web Adapters after installing respective components"
    echo ""
    print_warning "Do NOT configure Web Adapters until Portal/Server are installed!"
    echo ""
}

# Run main function
main "$@"
