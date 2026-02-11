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
#   ./install_web_adaptor.sh [<password>]
#   
#   If password not provided, you will be prompted for it.
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
WEBSVC_USER="web-services"
WEBSVC_GROUP="web-services"
JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

# Directories following FHS
OPT_WEBSVC="/opt/tomcat"
ETC_WEBSVC="/etc/opt/tomcat"
VAR_WEBSVC="/var/opt/tomcat"
OPT_ARCGIS="/opt/arcgis"

# Parse command line arguments
PFX_PASSWORD=""

# Check if first argument is -h or --help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [<password>]"
    echo ""
    echo "Arguments:"
    echo "  password          Password for the PFX certificate file (optional)"
    echo "                    If not provided, you will be prompted for it."
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Alternatively, create /tmp/config.ini with:"
    echo "  PFX_PASSWORD=your_password_here"
    exit 0
fi

# Accept password as first positional argument
if [[ -n "$1" ]]; then
    PFX_PASSWORD="$1"
fi

# Read config file if password not provided via command line
if [[ -z "$PFX_PASSWORD" && -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}Reading configuration from $CONFIG_FILE...${NC}"
    source "$CONFIG_FILE"
fi

# Prompt for password if still not set
if [[ -z "$PFX_PASSWORD" ]]; then
    echo -e "${YELLOW}PFX certificate password required.${NC}"
    read -s -p "Enter PFX certificate password: " PFX_PASSWORD
    echo  # New line after password input
    
    # Validate password was entered
    if [[ -z "$PFX_PASSWORD" ]]; then
        echo -e "${RED}Error: Password cannot be empty.${NC}"
        exit 1
    fi
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
    
    # Check for Web Adaptor tar.gz (try multiple naming patterns)
    WEBADAPTOR_TARBALL=$(ls /tmp/Web_Adapter_for_ArcGIS_Linux_*.tar.gz /tmp/ArcGIS_Web_Adaptor_*_Linux_*.tar.gz 2>/dev/null | head -1)
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

# Create web services user
create_web_services_user() {
    print_status "Creating web services user..."
    if id "$WEBSVC_USER" &>/dev/null; then
        print_warning "User $WEBSVC_USER already exists, skipping creation"
    else
        sudo useradd -s /bin/false -m -U "$WEBSVC_USER"
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
    sudo chown ${WEBSVC_USER}:${WEBSVC_GROUP} /etc/authbind/byport/443
    sudo chmod 500 /etc/authbind/byport/443
}

# Install Tomcat
install_tomcat() {
    print_status "Installing Apache Tomcat..."
    
    # Create directory structure
    sudo mkdir -p "$OPT_WEBSVC"
    sudo mkdir -p "$ETC_WEBSVC"
    sudo mkdir -p "${VAR_WEBSVC}"/{logs,temp,work,webapps}
    
    # Extract Tomcat to /opt/tomcat
    sudo tar xf "$TOMCAT_TARBALL" -C "$OPT_WEBSVC" --strip-components=1
    
    # Move configuration files to /etc/opt/tomcat
    sudo mv ${OPT_WEBSVC}/conf/* "$ETC_WEBSVC"/
    sudo rmdir ${OPT_WEBSVC}/conf
    sudo ln -sf "$ETC_WEBSVC" ${OPT_WEBSVC}/conf
    
    # Move variable directories to /var/opt/tomcat and create symlinks
    sudo rm -rf ${OPT_WEBSVC}/logs ${OPT_WEBSVC}/temp ${OPT_WEBSVC}/work ${OPT_WEBSVC}/webapps
    sudo ln -sf ${VAR_WEBSVC}/logs ${OPT_WEBSVC}/logs
    sudo ln -sf ${VAR_WEBSVC}/temp ${OPT_WEBSVC}/temp
    sudo ln -sf ${VAR_WEBSVC}/work ${OPT_WEBSVC}/work
    sudo ln -sf ${VAR_WEBSVC}/webapps ${OPT_WEBSVC}/webapps
    
    # Extract webapps to new location
    sudo tar xf "$TOMCAT_TARBALL" -C /tmp --strip-components=1 --wildcards "*/webapps/*"
    # Remove existing webapps to allow clean installation
    sudo rm -rf ${VAR_WEBSVC}/webapps/*
    sudo mv /tmp/webapps/* ${VAR_WEBSVC}/webapps/
    sudo rm -rf /tmp/webapps
}

# Configure Tomcat permissions
configure_tomcat_permissions() {
    print_status "Configuring Tomcat permissions..."
    
    # Binary directory - root owns, web-services can read/execute
    sudo chown -R root:${WEBSVC_GROUP} "$OPT_WEBSVC"/
    sudo chmod -R 750 "$OPT_WEBSVC"/
    sudo chmod -R u+x ${OPT_WEBSVC}/bin
    
    # Configuration directory - root owns, web-services can read
    sudo chown -R root:${WEBSVC_GROUP} "$ETC_WEBSVC"/
    sudo chmod -R 750 "$ETC_WEBSVC"/
    
    # Variable data directory - web-services owns (needs write access)
    sudo chown -R ${WEBSVC_USER}:${WEBSVC_GROUP} "$VAR_WEBSVC"/
    sudo chmod -R 750 "$VAR_WEBSVC"/
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

    # although the service is started as root, it runs as the web-services user
    User=${WEBSVC_USER}
    Group=${WEBSVC_GROUP}

    # environment variables, where to find Java and Tomcat
    Environment="JAVA_HOME=${JAVA_HOME}"
    Environment="CATALINA_HOME=${OPT_WEBSVC}"
    Environment="CATALINA_BASE=${OPT_WEBSVC}"
    Environment="CATALINA_PID=${VAR_WEBSVC}/temp/tomcat.pid"
    Environment="CATALINA_TMPDIR=${VAR_WEBSVC}/temp"

    # Startup using authbind so can use port 443
    ExecStart=/usr/bin/authbind --deep ${OPT_WEBSVC}/bin/startup.sh
    ExecStop=${OPT_WEBSVC}/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF
}

# Configure SSL/TLS
configure_ssl() {
    print_status "Configuring SSL/TLS..."
    
    # Create certificate directory
    sudo mkdir -p ${ETC_WEBSVC}/cert
    sudo chown -R root:${WEBSVC_GROUP} ${ETC_WEBSVC}/cert
    sudo chmod -R 750 ${ETC_WEBSVC}/cert
    
    # Copy PFX certificate
    sudo cp "$PFX_FILE" ${ETC_WEBSVC}/cert/tomcat_fullchain.p12
    sudo chown root:${WEBSVC_GROUP} ${ETC_WEBSVC}/cert/tomcat_fullchain.p12
    sudo chmod 640 ${ETC_WEBSVC}/cert/tomcat_fullchain.p12
    
    # Backup original server.xml
    sudo cp ${ETC_WEBSVC}/server.xml ${ETC_WEBSVC}/server.xml.bak
    
    # Add SSL connector to server.xml
    # First, check if SSL connector already exists
    if grep -q 'port="443"' ${ETC_WEBSVC}/server.xml; then
        print_warning "SSL connector already configured in server.xml"
    else
        # Insert SSL connector before the closing </Service> tag
        sudo sed -i '/<\/Service>/i \
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
    </Connector>' ${ETC_WEBSVC}/server.xml
    fi
}

# Enable remote access for Tomcat manager apps
enable_remote_access() {
    print_status "Enabling remote access for Tomcat manager applications..."
    
    # Comment out the RemoteAddrValve in manager and host-manager context.xml files
    for webapp in manager host-manager; do
        CONTEXT_FILE="${VAR_WEBSVC}/webapps/${webapp}/META-INF/context.xml"
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
    rm -rf /tmp/WebAdapter*
    tar xf "$WEBADAPTOR_TARBALL" -C /tmp
    
    # Find the Setup file (directory name may vary)
    SETUP_FILE=$(find /tmp -maxdepth 2 -name "Setup" -type f 2>/dev/null | grep -i webadaptor | head -1)
    if [[ -z "$SETUP_FILE" ]]; then
        print_error "Setup file not found after extracting Web Adaptor tarball"
        exit 1
    fi
    print_status "Found Setup at: $SETUP_FILE"
    
    # Make Setup executable
    chmod +x "$SETUP_FILE"
    
    # Create the installation directory with proper ownership
    sudo mkdir -p ${OPT_ARCGIS}
    sudo chown ${WEBSVC_USER}:${WEBSVC_GROUP} ${OPT_ARCGIS}
    sudo chmod 750 ${OPT_ARCGIS}
    
    # Run the installer as web-services user
    sudo -u ${WEBSVC_USER} "$SETUP_FILE" -m silent -l yes -d /opt/arcgis -v

    print_status "Checking installation directory..."
    
    # Find the installed WebAdaptor directory (case-insensitive)
    WEBADAPTOR_DIR=$(find /opt/arcgis -maxdepth 1 -type d -iname "webadaptor*" 2>/dev/null | head -1)
    
    if [[ -n "$WEBADAPTOR_DIR" ]]; then
        # Remove existing webadaptor symlink or directory if present
        if [ -L "/opt/arcgis/webadaptor" ] || [ -d "/opt/arcgis/webadaptor" ]; then
            sudo rm -rf /opt/arcgis/webadaptor
        fi
        
        # Create symlink to the installed directory
        sudo ln -sf "$WEBADAPTOR_DIR" /opt/arcgis/webadaptor
        print_status "Created symlink: /opt/arcgis/webadaptor -> $WEBADAPTOR_DIR"
    else
        print_warning "Web Adaptor directory not found in expected location"
        echo "Contents of /opt/arcgis:"
        ls -la /opt/arcgis/
    fi

    # Cleanup
    rm -rf /tmp/WebAdapter*
}

# Deploy Web Adaptor WAR files
deploy_web_adaptor_wars() {
    print_status "Deploying Portal and Server Web Adaptor WAR files..."
    
    # Create webapps directory for arcgis if it doesn't exist
    sudo mkdir -p ${VAR_WEBSVC}/webapps
    
    # Deploy Portal Web Adaptor
    if [[ -f "${OPT_ARCGIS}/webadaptor/portal/war/arcgis.war" ]]; then
        sudo cp ${OPT_ARCGIS}/webadaptor/portal/war/arcgis.war ${VAR_WEBSVC}/webapps/portal.war
        sudo chown ${WEBSVC_USER}:${WEBSVC_GROUP} ${VAR_WEBSVC}/webapps/portal.war
        print_status "Deployed Portal Web Adaptor as portal.war"
    fi
    
    # Deploy Server Web Adaptor
    if [[ -f "${OPT_ARCGIS}/webadaptor/server/war/arcgis.war" ]]; then
        sudo cp ${OPT_ARCGIS}/webadaptor/server/war/arcgis.war ${VAR_WEBSVC}/webapps/server.war
        sudo chown ${WEBSVC_USER}:${WEBSVC_GROUP} ${VAR_WEBSVC}/webapps/server.war
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
    create_web_services_user
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
