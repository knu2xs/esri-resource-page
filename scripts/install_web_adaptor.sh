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
VAR_LOG_TOMCAT="/var/log/tomcat"
OPT_ARCGIS="/opt/arcgis"

# Parse command line arguments
PFX_PASSWORD=""
MANAGER_PASSWORD=""

# Check if first argument is -h or --help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [<pfx_password>] [<manager_password>]"
    echo ""
    echo "Arguments:"
    echo "  pfx_password      Password for the PFX certificate file (optional)"
    echo "  manager_password  Password for Tomcat Manager admin user (optional)"
    echo "                    If not provided, you will be prompted for them."
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Alternatively, create /tmp/config.ini with:"
    echo "  PFX_PASSWORD=your_pfx_password_here"
    echo "  MANAGER_PASSWORD=your_manager_password_here"
    exit 0
fi

# Accept passwords as positional arguments
if [[ -n "$1" ]]; then
    PFX_PASSWORD="$1"
fi
if [[ -n "$2" ]]; then
    MANAGER_PASSWORD="$2"
fi

# Read config file if passwords not provided via command line
if [[ -f "$CONFIG_FILE" ]]; then
    if [[ -z "$PFX_PASSWORD" || -z "$MANAGER_PASSWORD" ]]; then
        echo -e "${YELLOW}Reading configuration from $CONFIG_FILE...${NC}"
        source "$CONFIG_FILE"
    fi
fi

# Prompt for PFX password if still not set
if [[ -z "$PFX_PASSWORD" ]]; then
    echo -e "${YELLOW}PFX certificate password required.${NC}"
    read -s -p "Enter PFX certificate password: " PFX_PASSWORD
    echo  # New line after password input
    
    # Validate password was entered
    if [[ -z "$PFX_PASSWORD" ]]; then
        echo -e "${RED}Error: PFX password cannot be empty.${NC}"
        exit 1
    fi
fi

# Prompt for Tomcat Manager password if still not set
if [[ -z "$MANAGER_PASSWORD" ]]; then
    echo -e "${YELLOW}Tomcat Manager admin password required.${NC}"
    read -s -p "Enter Tomcat Manager admin password: " MANAGER_PASSWORD
    echo  # New line after password input
    
    # Validate password was entered
    if [[ -z "$MANAGER_PASSWORD" ]]; then
        echo -e "${RED}Error: Manager password cannot be empty.${NC}"
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
    sudo mkdir -p "${VAR_WEBSVC}"/{temp,work,webapps}
    sudo mkdir -p "$VAR_LOG_TOMCAT"
    
    # Extract Tomcat to /opt/tomcat
    sudo tar xf "$TOMCAT_TARBALL" -C "$OPT_WEBSVC" --strip-components=1
    
    # Move configuration files to /etc/opt/tomcat and create symlink
    sudo rsync -av --remove-source-files ${OPT_WEBSVC}/conf/ "$ETC_WEBSVC"/
    sudo rmdir ${OPT_WEBSVC}/conf
    sudo ln -s "$ETC_WEBSVC" ${OPT_WEBSVC}/conf
    
    # Move any logfiles to /var/log/tomcat and create symlink
    sudo rsync -av --remove-source-files ${OPT_WEBSVC}/logs/ "$VAR_LOG_TOMCAT"/
    sudo rmdir ${OPT_WEBSVC}/logs
    sudo ln -s "$VAR_LOG_TOMCAT" ${OPT_WEBSVC}/logs
    
    # Move variable data directories to /var/opt/tomcat and create symlinks
    sudo rsync -av --remove-source-files ${OPT_WEBSVC}/temp/ ${VAR_WEBSVC}/temp/
    sudo rm -rf ${OPT_WEBSVC}/temp
    sudo ln -s ${VAR_WEBSVC}/temp ${OPT_WEBSVC}/temp
    
    sudo rsync -av --remove-source-files ${OPT_WEBSVC}/work/ ${VAR_WEBSVC}/work/
    sudo rm -rf ${OPT_WEBSVC}/work
    sudo ln -s ${VAR_WEBSVC}/work ${OPT_WEBSVC}/work
    
    sudo rsync -av --remove-source-files ${OPT_WEBSVC}/webapps/ ${VAR_WEBSVC}/webapps/
    sudo rm -rf ${OPT_WEBSVC}/webapps
    sudo ln -s ${VAR_WEBSVC}/webapps ${OPT_WEBSVC}/webapps
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
    
    # Log directory - root owns and web-services can write; users can read but cannot modify logs
    sudo chown -R root:${WEBSVC_GROUP} "$VAR_LOG_TOMCAT"/
    sudo chmod -R 775 "$VAR_LOG_TOMCAT"/
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
    
    # XML-escape the password to handle special characters
    # This prevents XML corruption when password contains &, <, >, ", ', etc.
    ESCAPED_PASSWORD="${PFX_PASSWORD//&/&amp;}"
    ESCAPED_PASSWORD="${ESCAPED_PASSWORD//</&lt;}"
    ESCAPED_PASSWORD="${ESCAPED_PASSWORD//>/&gt;}"
    ESCAPED_PASSWORD="${ESCAPED_PASSWORD//\"/&quot;}"
    ESCAPED_PASSWORD="${ESCAPED_PASSWORD//\'/&apos;}"
    
    # Add SSL connector to server.xml
    # First, check if SSL connector already exists
    if grep -q 'port="443"' ${ETC_WEBSVC}/server.xml; then
        print_warning "SSL connector already configured in server.xml"
    else
        # Insert SSL connector before the closing </Service> tag
        # Use absolute path for certificate to avoid path resolution issues
        sudo sed -i '/<\/Service>/i \
    <Connector port="443"\
               protocol="org.apache.coyote.http11.Http11NioProtocol"\
               maxThreads="300"\
               scheme="https"\
               secure="true"\
               SSLEnabled="true">\
\
        <SSLHostConfig protocols="TLSv1.2,TLSv1.3"\
                       honorCipherOrder="true">\
\
            <Certificate\
                certificateKeystoreFile="'"${ETC_WEBSVC}"'/cert/tomcat_fullchain.p12"\
                certificateKeystoreType="PKCS12"\
                certificateKeystorePassword="'"${ESCAPED_PASSWORD}"'"\
            />\
\
        </SSLHostConfig>\
    </Connector>' ${ETC_WEBSVC}/server.xml
    fi
}

# Enable remote access for Tomcat manager apps
enable_remote_access() {
    print_status "Enabling remote access for Tomcat manager applications..."
    
    # Comment out the RemoteAddrValve in manager and host-manager META-INF/context.xml files
    # This allows remote access to the Tomcat Manager and Host Manager web applications
    for webapp in manager host-manager; do
        CONTEXT_FILE="${VAR_WEBSVC}/webapps/${webapp}/META-INF/context.xml"
        if [[ -f "$CONTEXT_FILE" ]]; then
            print_status "Modifying ${webapp} context.xml to allow remote access..."
            
            # Backup the original context.xml
            sudo cp "$CONTEXT_FILE" "${CONTEXT_FILE}.bak"
            
            # Comment out the RemoteAddrValve that restricts access to localhost only
            sudo sed -i 's/<Valve className="org.apache.catalina.valves.RemoteAddrValve"/<!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"/g' "$CONTEXT_FILE"
            sudo sed -i 's/allow="127\\\.\\d+\\\.\\d+\\\.\\d+|::1|0:0:0:0:0:0:0:1" \/>/allow="127\\.\\d+\\.\\d+\\.\\d+|::1|0:0:0:0:0:0:0:1" \/> -->/g' "$CONTEXT_FILE"
            
            # Verify the change was made
            if grep -q '<!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"' "$CONTEXT_FILE"; then
                print_status "Successfully enabled remote access for ${webapp}"
            else
                print_warning "Could not verify remote access configuration for ${webapp}"
            fi
        else
            print_warning "Context file not found: $CONTEXT_FILE"
            print_warning "Remote access for ${webapp} will need to be configured manually"
        fi
    done
    
    print_warning "SECURITY NOTE: Remote access to Tomcat Manager is now enabled."
    print_warning "Ensure you configure strong credentials in tomcat-users.xml"
}

# Configure Tomcat manager users
configure_tomcat_users() {
    print_status "Configuring Tomcat manager users..."
    
    # Backup original tomcat-users.xml
    sudo cp ${ETC_WEBSVC}/tomcat-users.xml ${ETC_WEBSVC}/tomcat-users.xml.bak
    
    # XML-escape the manager password to handle special characters
    ESCAPED_MANAGER_PASSWORD="${MANAGER_PASSWORD//&/&amp;}"
    ESCAPED_MANAGER_PASSWORD="${ESCAPED_MANAGER_PASSWORD//</&lt;}"
    ESCAPED_MANAGER_PASSWORD="${ESCAPED_MANAGER_PASSWORD//>/&gt;}"
    ESCAPED_MANAGER_PASSWORD="${ESCAPED_MANAGER_PASSWORD//\"/&quot;}"
    ESCAPED_MANAGER_PASSWORD="${ESCAPED_MANAGER_PASSWORD//\'/&apos;}"
    
    # Create tomcat-users.xml with admin credentials
    sudo tee ${ETC_WEBSVC}/tomcat-users.xml > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!--
  NOTE: By default, no user is included in the "manager-gui" role required
  to operate the "/manager/html" web application.  If you wish to use this app,
  you must define such a user - the username and password are arbitrary.
-->
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  
  <!-- Define roles for Tomcat Manager access -->
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>
  
  <!-- Admin user with all manager roles -->
  <user username="admin" password="${ESCAPED_MANAGER_PASSWORD}" roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>
  
</tomcat-users>
EOF
    
    sudo chown root:${WEBSVC_GROUP} ${ETC_WEBSVC}/tomcat-users.xml
    sudo chmod 640 ${ETC_WEBSVC}/tomcat-users.xml
    
    # Save credentials to a secure file
    sudo tee /root/tomcat-credentials.txt > /dev/null <<EOF
Tomcat Manager Credentials
==========================
Username: admin
Password: ${MANAGER_PASSWORD}

Manager URL: https://<your_server>/manager/html
Host Manager URL: https://<your_server>/host-manager/html

IMPORTANT: Store these credentials securely and delete this file after saving them.
EOF
    sudo chmod 600 /root/tomcat-credentials.txt
    
    print_status "Tomcat manager users configured"
    print_warning "Manager credentials saved to /root/tomcat-credentials.txt"
    print_warning "Username: admin"
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
    
    # Make Setup executable
    chmod +x /tmp/WebAdaptor/Setup
    
    # Create the installation directory with proper ownership
    sudo mkdir -p ${OPT_ARCGIS}
    sudo chown ${WEBSVC_USER}:${WEBSVC_GROUP} ${OPT_ARCGIS}
    sudo chmod 750 ${OPT_ARCGIS}
    
    # Run the installer as web-services user
    sudo -u ${WEBSVC_USER} /tmp/WebAdaptor/Setup -m silent -l yes -d /opt/arcgis -v
    
    print_status "Creating Web Adaptor symlink..."
    
    # Create symlink to make installation directory consistent
    sudo -u ${WEBSVC_USER} ln -sf $(sudo find /opt/arcgis -maxdepth 1 -type d -name 'webadaptor[0-9]*' | sort -V | tail -1) /opt/arcgis/webadaptor
    
    # Cleanup
    rm -rf /tmp/WebAdapter*
}

# Deploy Web Adaptor WAR files
deploy_web_adaptor_wars() {
    print_status "Deploying Portal and Server Web Adaptor WAR files..."
    
    # Find and store the WAR file path
    WAR_FILE=$(find /opt/arcgis/webadaptor -name "*.war" -type f | head -1)
    
    if [[ -z "$WAR_FILE" ]]; then
        print_error "WAR file not found in /opt/arcgis/webadaptor"
        exit 1
    fi
    print_status "Found WAR file: $WAR_FILE"
    
    # Deploy Portal Web Adaptor WAR file
    # Note: Do NOT create directories - Tomcat auto-deploys WAR files only if the directory doesn't exist
    sudo cp "$WAR_FILE" ${VAR_WEBSVC}/webapps/portal.war
    
    # Deploy Server Web Adaptor WAR file
    sudo cp "$WAR_FILE" ${VAR_WEBSVC}/webapps/server.war
    
    # Set proper ownership
    sudo chown -R ${WEBSVC_USER}:${WEBSVC_GROUP} ${VAR_WEBSVC}/webapps/
    
    print_status "Deployed Portal and Server Web Adaptor WAR files"
    
    # Check Tomcat logs for deployment confirmation
    print_status "Checking Tomcat logs for deployment status..."
    sleep 5
    sudo tail -n 20 ${VAR_LOG_TOMCAT}/catalina.out
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
    configure_tomcat_users
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
    echo "  2. Tomcat Manager: https://<your_server>/manager/html"
    echo "     - Credentials saved in /root/tomcat-credentials.txt"
    echo "  3. Install Portal for ArcGIS and/or ArcGIS Server"
    echo "  4. Configure the Web Adapters after installing respective components"
    echo ""
    print_warning "Do NOT configure Web Adapters until Portal/Server are installed!"
    print_warning "Remote access to Tomcat Manager is enabled - secure your credentials!"
    echo ""
}

# Run main function
main "$@"
