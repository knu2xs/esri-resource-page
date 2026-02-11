#!/bin/bash
#
# ArcGIS Web Adaptor Installation Script for Ubuntu with Nginx + Tomcat
# 
# This script automates the installation of Nginx (reverse proxy), Apache Tomcat, 
# and ArcGIS Web Adaptor on Ubuntu systems following production-ready best practices
# with defense-in-depth security architecture.
#
# Architecture:
#   Internet -> Nginx (HTTPS:443) -> Tomcat (HTTP:8080, localhost) -> Web Adapters
#
# Prerequisites:
#   - Ubuntu 20.04 LTS or later
#   - Root or sudo access
#   - Tomcat tar.gz downloaded to /tmp (e.g., apache-tomcat-*.tar.gz)
#   - ArcGIS Web Adaptor tar.gz downloaded to /tmp
#   - SSL certificate files (PEM format) for Nginx:
#       * /tmp/server.crt (certificate with chain)
#       * /tmp/server.key (private key)
#     OR PFX file in /tmp (will be converted)
#
# Usage:
#   ./install_web_adaptor_nginx.sh [options]
#
# Options:
#   -h, --help              Show this help message
#   -s, --skip-nginx        Skip Nginx installation (Tomcat only)
#   -d, --domain <domain>   Specify server domain name (default: hostname)
#   --skip-firewall         Skip UFW firewall configuration
#   --skip-updates          Skip system package updates
#

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WEBSVC_USER="web-services"
WEBSVC_GROUP="web-services"
JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

# Directories following FHS
OPT_WEBSVC="/opt/tomcat"
ETC_WEBSVC="/etc/opt/tomcat"
VAR_WEBSVC="/var/opt/tomcat"
OPT_ARCGIS="/opt/arcgis"
NGINX_SSL_DIR="/etc/nginx/ssl"

# Default options
SKIP_NGINX=false
SKIP_FIREWALL=false
SKIP_UPDATES=false
SKIP_FAIL2BAN=false
SERVER_DOMAIN=$(hostname -f)
PFX_FILE=""
PFX_PASSWORD=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            cat << EOF
Usage: $0 [options] [pfx_password]

Positional Arguments:
  pfx_password            Password for PFX certificate (optional, will prompt if not provided)

Options:
  -h, --help              Show this help message
  -s, --skip-nginx        Skip Nginx installation (Tomcat only, NOT recommended for production)
  -d, --domain <domain>   Specify server domain name (default: $(hostname -f))
  -p, --pfx-password <password>  Password for PFX certificate
  --skip-firewall         Skip UFW firewall configuration
  --skip-updates          Skip system package updates
  --skip-fail2ban         Skip Fail2Ban installation (default: install)

Examples:
  $0                                    # Full installation with all components
  $0 mypassword                         # Provide PFX password as argument
  $0 -p mypassword                      # Provide PFX password as flag
  $0 -d webserver.esri.com             # Specify custom domain
  $0 -s                                 # Tomcat only (development/testing)
  $0 --skip-fail2ban -p mypassword     # Skip Fail2Ban, provide password

Prerequisites:
  Place required files in /tmp:
    - apache-tomcat-*.tar.gz
    - Web_Adapter_for_ArcGIS_Linux_*.tar.gz (or ArcGIS_Web_Adaptor_*_Linux_*.tar.gz)
    - server.crt and server.key (for Nginx) OR server.pfx (will be converted)

EOF
            exit 0
            ;;
        -s|--skip-nginx)
            SKIP_NGINX=true
            shift
            ;;
        -d|--domain)
            SERVER_DOMAIN="$2"
            shift 2
            ;;
        -p|--pfx-password)
            PFX_PASSWORD="$2"
            shift 2
            ;;
        --skip-firewall)
            SKIP_FIREWALL=true
            shift
            ;;
        --skip-updates)
            SKIP_UPDATES=true
            shift
            ;;
        --skip-fail2ban)
            SKIP_FAIL2BAN=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Parse positional argument for PFX password (after all flags)
if [[ $# -gt 0 ]]; then
    PFX_PASSWORD="$1"
    shift
fi

# Function to print status messages
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
}

# Function to check for required files
check_prerequisites() {
    print_section "Checking Prerequisites"
    
    local errors=0
    
    # Check for Tomcat tar.gz
    TOMCAT_TARBALL=$(ls /tmp/apache-tomcat-*.tar.gz 2>/dev/null | head -1 || true)
    if [[ -z "$TOMCAT_TARBALL" ]]; then
        print_error "Tomcat tar.gz not found in /tmp"
        ((errors++))
    else
        print_status "Found Tomcat: $(basename $TOMCAT_TARBALL)"
    fi
    
    # Check for Web Adaptor tar.gz (try multiple naming patterns)
    WEBADAPTOR_TARBALL=$(ls /tmp/Web_Adapter_for_ArcGIS_Linux_*.tar.gz /tmp/ArcGIS_Web_Adaptor_*_Linux_*.tar.gz 2>/dev/null | head -1 || true)
    if [[ -z "$WEBADAPTOR_TARBALL" ]]; then
        print_error "ArcGIS Web Adaptor tar.gz not found in /tmp"
        print_info "Looking for: Web_Adapter_for_ArcGIS_Linux_*.tar.gz or ArcGIS_Web_Adaptor_*_Linux_*.tar.gz"
        print_info "Files in /tmp:"
        ls -la /tmp/*.tar.gz 2>/dev/null || echo "  (no .tar.gz files found)"
        ((errors++))
    else
        print_status "Found Web Adaptor: $(basename $WEBADAPTOR_TARBALL)"
    fi
    
    # Check for SSL certificates if Nginx will be installed
    if [[ "$SKIP_NGINX" == "false" ]]; then
        # Look for PEM format certificates (by extension)
        CERT_FILE=$(ls /tmp/*.crt /tmp/*.pem 2>/dev/null | head -1 || true)
        KEY_FILE=$(ls /tmp/*.key 2>/dev/null | head -1 || true)
        
        if [[ -n "$CERT_FILE" && -n "$KEY_FILE" ]]; then
            print_status "Found SSL certificate files (PEM format): $(basename "$CERT_FILE") and $(basename "$KEY_FILE")"
        else
            # Try to find PFX files
            PFX_FILE=$(ls /tmp/*.p12 /tmp/*.pfx 2>/dev/null | head -1 || true)
            if [[ -n "$PFX_FILE" ]]; then
                print_status "Found PFX certificate: $(basename "$PFX_FILE") - will be converted to PEM format"
            else
                print_error "SSL certificates not found. Need either:"
                print_error "  - Certificate file (.crt or .pem) and private key (.key) in /tmp, OR"
                print_error "  - PFX file (.pfx or .p12) in /tmp (will be converted)"
                print_info "Files in /tmp:"
                ls -la /tmp/*.{crt,pem,key,pfx,p12} 2>/dev/null || echo "  (no certificate files found)"
                ((errors++))
            fi
        fi
    fi
    
    echo ""  # Flush output
    
    if [[ $errors -gt 0 ]]; then
        print_error "Missing $errors required file(s). Please correct and try again."
        exit 1
    fi
    
    print_status "All prerequisites met"
}

# Update system packages
update_system() {
    if [[ "$SKIP_UPDATES" == "true" ]]; then
        print_warning "Skipping system updates"
        return
    fi
    
    print_section "Updating System Packages"
    sudo apt update
    sudo apt upgrade -y
    print_status "System packages updated"
}

# Configure firewall
configure_firewall() {
    if [[ "$SKIP_FIREWALL" == "true" ]]; then
        print_warning "Skipping firewall configuration"
        return
    fi
    
    print_section "Configuring Firewall (UFW)"
    
    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        print_info "UFW not installed, skipping firewall configuration"
        return
    fi
    
    if [[ "$SKIP_NGINX" == "false" ]]; then
        # Production configuration with Nginx
        print_info "Opening ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
        sudo ufw allow 22/tcp comment 'SSH'
        sudo ufw allow 80/tcp comment 'HTTP'
        sudo ufw allow 443/tcp comment 'HTTPS'
        print_warning "Port 8080 (Tomcat) will NOT be exposed - traffic goes through Nginx only"
    else
        # Development configuration without Nginx
        print_info "Opening ports: 22 (SSH), 443 (HTTPS), 8080 (Tomcat)"
        sudo ufw allow 22,443,8080/tcp
        print_warning "Port 8080 exposed for testing - NOT recommended for production"
    fi
    
    sudo ufw --force enable
    print_status "Firewall configured"
}

# Create web services user
create_web_services_user() {
    print_section "Creating Service User"
    
    if id "$WEBSVC_USER" &>/dev/null; then
        print_warning "User $WEBSVC_USER already exists, skipping creation"
    else
        sudo useradd -s /bin/false -m -U "$WEBSVC_USER"
        print_status "Created web-services user"
    fi
}

# Install Java
install_java() {
    print_section "Installing Java Runtime"
    
    sudo apt install openjdk-17-jdk -y
    print_status "OpenJDK 17 installed"
    java -version
}

# Install Tomcat
install_tomcat() {
    print_section "Installing Apache Tomcat"
    
    # Create directory structure
    print_info "Creating FHS-compliant directory structure..."
    sudo mkdir -p "$OPT_WEBSVC"
    sudo mkdir -p "$ETC_WEBSVC"
    sudo mkdir -p "${VAR_WEBSVC}"/{logs,temp,work,webapps}
    
    # Extract Tomcat to /opt/tomcat
    print_info "Extracting Tomcat to $OPT_WEBSVC..."
    sudo tar xf "$TOMCAT_TARBALL" -C "$OPT_WEBSVC" --strip-components=1
    
    # Move configuration files to /etc/opt/tomcat
    print_info "Moving configuration files to $ETC_WEBSVC..."
    sudo mv ${OPT_WEBSVC}/conf/* "$ETC_WEBSVC"/
    sudo rmdir ${OPT_WEBSVC}/conf
    sudo ln -sf "$ETC_WEBSVC" ${OPT_WEBSVC}/conf
    
    # Move variable directories to /var/opt/tomcat and create symlinks
    print_info "Creating symlinks for variable data directories..."
    sudo rm -rf ${OPT_WEBSVC}/logs ${OPT_WEBSVC}/temp ${OPT_WEBSVC}/work ${OPT_WEBSVC}/webapps
    sudo ln -sf ${VAR_WEBSVC}/logs ${OPT_WEBSVC}/logs
    sudo ln -sf ${VAR_WEBSVC}/temp ${OPT_WEBSVC}/temp
    sudo ln -sf ${VAR_WEBSVC}/work ${OPT_WEBSVC}/work
    sudo ln -sf ${VAR_WEBSVC}/webapps ${OPT_WEBSVC}/webapps
    
    # Extract webapps to new location
    print_info "Deploying default web applications..."
    sudo tar xf "$TOMCAT_TARBALL" -C /tmp --strip-components=1 --wildcards "*/webapps/*"
    sudo rm -rf ${VAR_WEBSVC}/webapps/*
    sudo mv /tmp/webapps/* ${VAR_WEBSVC}/webapps/
    sudo rm -rf /tmp/webapps
    
    print_status "Tomcat installed"
}

# Configure Tomcat permissions
configure_tomcat_permissions() {
    print_section "Configuring Tomcat Permissions"
    
    # Binary directory - root owns, web-services can read/execute
    print_info "Setting permissions for $OPT_WEBSVC (binaries)..."
    sudo chown -R root:${WEBSVC_GROUP} "$OPT_WEBSVC"/
    sudo chmod -R 750 "$OPT_WEBSVC"/
    sudo chmod -R u+x ${OPT_WEBSVC}/bin
    
    # Configuration directory - root owns, web-services can read
    print_info "Setting permissions for $ETC_WEBSVC (configuration)..."
    sudo chown -R root:${WEBSVC_GROUP} "$ETC_WEBSVC"/
    sudo chmod -R 750 "$ETC_WEBSVC"/
    
    # Variable data directory - web-services owns (needs write access)
    print_info "Setting permissions for $VAR_WEBSVC (variable data)..."
    sudo chown -R ${WEBSVC_USER}:${WEBSVC_GROUP} "$VAR_WEBSVC"/
    sudo chmod -R 750 "$VAR_WEBSVC"/
    
    print_status "Permissions configured"
}

# Configure Tomcat for reverse proxy
configure_tomcat_server_xml() {
    print_section "Configuring Tomcat Server"
    
    # Backup original server.xml
    sudo cp ${ETC_WEBSVC}/server.xml ${ETC_WEBSVC}/server.xml.bak
    
    if [[ "$SKIP_NGINX" == "false" ]]; then
        print_info "Configuring Tomcat for Nginx reverse proxy (localhost:8080, HTTP only)..."
        
        # Configure HTTP connector on localhost:8080 for proxy
        sudo sed -i '/<Connector port="8080"/,/<\/Connector>/ {
            /<Connector port="8080"/ {
                N
                N
                N
                N
                N
                s|.*|    <!-- HTTP Connector - localhost only, behind Nginx reverse proxy -->\n    <Connector port="8080"\n               protocol="HTTP/1.1"\n               address="127.0.0.1"\n               connectionTimeout="20000"\n               redirectPort="8443"\n               maxThreads="300"\n               maxParameterCount="1000"\n               URIEncoding="UTF-8" />|
            }
        }' ${ETC_WEBSVC}/server.xml
        
        # Add RemoteIpValve for proper client IP logging
        if ! grep -q "RemoteIpValve" ${ETC_WEBSVC}/server.xml; then
            sudo sed -i '/<\/Host>/i \
        <!-- RemoteIpValve for proper client IP logging when behind reverse proxy -->\
        <Valve className="org.apache.catalina.valves.RemoteIpValve"\
               remoteIpHeader="x-forwarded-for"\
               proxiesHeader="x-forwarded-by"\
               protocolHeader="x-forwarded-proto" />' ${ETC_WEBSVC}/server.xml
        fi
        
        # Remove or comment out any SSL/HTTPS connectors on port 443
        sudo sed -i '/<Connector.*port="443"/,/<\/Connector>/d' ${ETC_WEBSVC}/server.xml 2>/dev/null || true
        
        print_status "Tomcat configured for localhost-only access (reverse proxy mode)"
    else
        print_warning "Standalone mode - Tomcat will be directly accessible"
        # Keep default configuration for standalone testing
    fi
}

# Create systemd service file
create_tomcat_service() {
    print_section "Creating Tomcat Systemd Service"
    
    sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description="Apache Tomcat Web Application Server"
After=network.target

[Service]
Type=forking

# Service runs as web-services user
User=${WEBSVC_USER}
Group=${WEBSVC_GROUP}

# Environment variables
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="CATALINA_HOME=${OPT_WEBSVC}"
Environment="CATALINA_BASE=${OPT_WEBSVC}"
Environment="CATALINA_PID=${VAR_WEBSVC}/temp/tomcat.pid"
Environment="CATALINA_TMPDIR=${VAR_WEBSVC}/temp"
Environment="CATALINA_OPTS=-Djava.awt.headless=true -Dorg.apache.catalina.connector.RECYCLE_FACADES=true"

# Startup and shutdown commands
ExecStart=${OPT_WEBSVC}/bin/startup.sh
ExecStop=${OPT_WEBSVC}/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    print_status "Systemd service file created"
}

# Enable remote access for Tomcat manager apps (optional)
enable_remote_access() {
    print_info "Configuring Tomcat manager applications for SSH tunnel access..."
    
    # Keep RemoteAddrValve active (localhost only) - access via SSH tunnel
    # This is the secure default for production
    
    print_warning "Tomcat Manager access is restricted to localhost (SSH tunnel required)"
    print_info "To access Manager, create SSH tunnel: ssh -L 8080:localhost:8080 user@$SERVER_DOMAIN"
}

# Start Tomcat service
start_tomcat() {
    print_section "Starting Tomcat Service"
    
    sudo systemctl daemon-reload
    sudo systemctl start tomcat
    sudo systemctl enable tomcat
    
    # Wait for Tomcat to start
    print_info "Waiting for Tomcat to start..."
    sleep 5
    
    if systemctl is-active --quiet tomcat; then
        print_status "Tomcat service started and enabled"
        
        # Verify Tomcat is listening
        if [[ "$SKIP_NGINX" == "false" ]]; then
            if sudo ss -tlnp | grep -q "127.0.0.1:8080"; then
                print_status "Tomcat listening on localhost:8080 (reverse proxy mode)"
            else
                print_warning "Tomcat may not be listening on expected port"
            fi
        fi
    else
        print_error "Tomcat service failed to start"
        sudo systemctl status tomcat --no-pager
        exit 1
    fi
}

# Install Nginx
install_nginx() {
    if [[ "$SKIP_NGINX" == "true" ]]; then
        print_warning "Skipping Nginx installation"
        return
    fi
    
    print_section "Installing Nginx"
    
    sudo apt install nginx -y
    
    # Create SSL directory
    sudo mkdir -p "$NGINX_SSL_DIR"
    sudo chown root:root "$NGINX_SSL_DIR"
    sudo chmod 700 "$NGINX_SSL_DIR"
    
    print_status "Nginx installed"
}

# Configure SSL certificates
configure_ssl_certificates() {
    if [[ "$SKIP_NGINX" == "true" ]]; then
        return
    fi
    
    print_section "Configuring SSL Certificates"
    
    # Look for PEM format certificates (by extension)
    local cert_file=$(ls /tmp/*.crt /tmp/*.pem 2>/dev/null | head -1 || true)
    local key_file=$(ls /tmp/*.key 2>/dev/null | head -1 || true)
    
    # Check if PEM files exist
    if [[ -n "$cert_file" && -n "$key_file" ]]; then
        print_info "Using PEM certificate files: $(basename "$cert_file") and $(basename "$key_file")..."
        sudo cp "$cert_file" "$NGINX_SSL_DIR/server.crt"
        sudo cp "$key_file" "$NGINX_SSL_DIR/server.key"
    elif [[ -n "${PFX_FILE:-}" && -f "${PFX_FILE}" ]]; then
        print_info "Converting PFX certificate to PEM format..."
        
        # Prompt for PFX password if not provided as parameter
        if [[ -z "${PFX_PASSWORD}" ]]; then
            read -s -p "Enter PFX certificate password: " PFX_PASSWORD
            echo
        else
            print_info "Using PFX password from command line parameter"
        fi
        
        # Extract certificate and private key from PFX
        # Use -legacy flag for OpenSSL 3.x compatibility with older PFX files
        print_info "Extracting certificate and key (using legacy provider for compatibility)..."
        
        if openssl version | grep -q "OpenSSL 3"; then
            # OpenSSL 3.x - use legacy provider for older algorithms
            openssl pkcs12 -in "$PFX_FILE" -clcerts -nokeys -out /tmp/server.crt -passin pass:"$PFX_PASSWORD" -legacy 2>/dev/null || \
                openssl pkcs12 -in "$PFX_FILE" -clcerts -nokeys -out /tmp/server.crt -passin pass:"$PFX_PASSWORD" -provider legacy -provider default
            
            openssl pkcs12 -in "$PFX_FILE" -nocerts -nodes -out /tmp/server.key -passin pass:"$PFX_PASSWORD" -legacy 2>/dev/null || \
                openssl pkcs12 -in "$PFX_FILE" -nocerts -nodes -out /tmp/server.key -passin pass:"$PFX_PASSWORD" -provider legacy -provider default
        else
            # OpenSSL 1.x - no legacy provider needed
            openssl pkcs12 -in "$PFX_FILE" -clcerts -nokeys -out /tmp/server.crt -passin pass:"$PFX_PASSWORD"
            openssl pkcs12 -in "$PFX_FILE" -nocerts -nodes -out /tmp/server.key -passin pass:"$PFX_PASSWORD"
        fi
        
        # Move to Nginx SSL directory
        sudo mv /tmp/server.crt "$NGINX_SSL_DIR/server.crt"
        sudo mv /tmp/server.key "$NGINX_SSL_DIR/server.key"
        
        print_status "PFX certificate converted to PEM format"
    else
        print_error "No SSL certificates found to configure!"
        print_error "This should have been caught in prerequisites check."
        exit 1
    fi
    
    # Set proper permissions
    sudo chmod 600 "$NGINX_SSL_DIR/server.key"
    sudo chmod 644 "$NGINX_SSL_DIR/server.crt"
    
    print_status "SSL certificates configured"
}

# Configure Nginx as reverse proxy
configure_nginx() {
    if [[ "$SKIP_NGINX" == "true" ]]; then
        return
    fi
    
    print_section "Configuring Nginx Reverse Proxy"
    
    # Create Nginx configuration
    print_info "Creating Nginx configuration for ArcGIS Enterprise..."
    
    sudo tee /etc/nginx/sites-available/arcgis-enterprise > /dev/null <<'EOF'
# Rate limiting zone - prevents DDoS attacks
# Adjust rate based on your workload (web mapping generates many concurrent requests)
limit_req_zone $binary_remote_addr zone=arcgis_limit:10m rate=50r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

# Upstream definition for Tomcat
upstream tomcat_backend {
    server 127.0.0.1:8080 fail_timeout=30s max_fails=3;
    keepalive 32;
}

# HTTP Server - redirect all traffic to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name SERVER_DOMAIN_PLACEHOLDER;
    
    # Allow Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS Server - main configuration
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name SERVER_DOMAIN_PLACEHOLDER;
    
    # SSL/TLS Configuration
    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    
    # Modern SSL/TLS configuration (Mozilla Intermediate profile)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    
    # SSL session configuration
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Logging
    access_log /var/log/nginx/arcgis-access.log;
    error_log /var/log/nginx/arcgis-error.log warn;
    
    # Client upload limits (adjust based on your needs)
    client_max_body_size 100M;
    client_body_buffer_size 128k;
    
    # Timeouts
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    send_timeout 300s;
    
    # Apply rate limiting (adjust burst for map tile loading)
    limit_req zone=arcgis_limit burst=100 nodelay;
    limit_conn conn_limit 20;
    
    # Root location - proxy to Tomcat
    location / {
        proxy_pass http://tomcat_backend;
        proxy_http_version 1.1;
        
        # Proxy headers - preserve original request information
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support (required for some ArcGIS Enterprise features)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Buffering configuration
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # Connection reuse
        proxy_set_header Connection "";
    }
    
    # Optional: Serve static content directly from Nginx for better performance
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://tomcat_backend;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # Replace placeholder with actual domain
    sudo sed -i "s/SERVER_DOMAIN_PLACEHOLDER/$SERVER_DOMAIN/g" /etc/nginx/sites-available/arcgis-enterprise
    
    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/arcgis-enterprise /etc/nginx/sites-enabled/
    
    # Remove default site
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Disable version in headers for security
    if ! grep -q "server_tokens off" /etc/nginx/nginx.conf; then
        sudo sed -i '/http {/a \    server_tokens off;' /etc/nginx/nginx.conf
    fi
    
    # Test Nginx configuration
    print_info "Testing Nginx configuration..."
    if sudo nginx -t; then
        print_status "Nginx configuration valid"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
}

# Start Nginx service
start_nginx() {
    if [[ "$SKIP_NGINX" == "true" ]]; then
        return
    fi
    
    print_section "Starting Nginx Service"
    
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    if systemctl is-active --quiet nginx; then
        print_status "Nginx service started and enabled"
    else
        print_error "Nginx service failed to start"
        sudo systemctl status nginx --no-pager
        exit 1
    fi
}

# Install and configure Fail2Ban
install_fail2ban() {
    if [[ "$SKIP_FAIL2BAN" == "true" ]]; then
        print_warning "Skipping Fail2Ban installation"
        return
    fi
    
    if [[ "$SKIP_NGINX" == "true" ]]; then
        print_warning "Skipping Fail2Ban (only useful with Nginx)"
        return
    fi
    
    print_section "Installing Fail2Ban"
    
    # Install Fail2Ban
    print_info "Installing Fail2Ban package..."
    sudo apt install fail2ban -y
    
    # Create jail.local configuration
    print_info "Configuring Fail2Ban jails for Nginx protection..."
    sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
# Whitelist local and private network ranges
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

# Ban duration (10 minutes)
bantime = 600

# Time window to count failures (10 minutes)
findtime = 600

# Number of failures before ban
maxretry = 5

# Nginx jails for ArcGIS Enterprise protection
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/arcgis-error.log
maxretry = 3

[nginx-noscript]
enabled = true
filter = nginx-noscript
logpath = /var/log/nginx/arcgis-access.log

[nginx-badbots]
enabled = true
filter = nginx-badbots
logpath = /var/log/nginx/arcgis-access.log
maxretry = 2

[nginx-noproxy]
enabled = true
filter = nginx-noproxy
logpath = /var/log/nginx/arcgis-access.log
maxretry = 2
EOF
    
    # Restart Fail2Ban to apply configuration
    print_info "Starting Fail2Ban service..."
    sudo systemctl restart fail2ban
    sudo systemctl enable fail2ban
    
    if systemctl is-active --quiet fail2ban; then
        print_status "Fail2Ban installed and configured"
        print_info "Active jails: nginx-http-auth, nginx-noscript, nginx-badbots, nginx-noproxy"
    else
        print_warning "Fail2Ban service failed to start"
        sudo systemctl status fail2ban --no-pager
    fi
}

# Install ArcGIS Web Adaptor
install_web_adaptor() {
    print_section "Installing ArcGIS Web Adaptor"
    
    # Unpack the installer
    print_info "Extracting Web Adaptor installer..."
    rm -rf /tmp/WebAdapter*
    tar xf "$WEBADAPTOR_TARBALL" -C /tmp
    
    # Find the Setup file (directory name may vary)
    SETUP_FILE=$(find /tmp -maxdepth 2 -name "Setup" -type f 2>/dev/null | grep -i webadaptor | head -1)
    if [[ -z "$SETUP_FILE" ]]; then
        print_error "Setup file not found after extracting Web Adaptor tarball"
        exit 1
    fi
    print_info "Found Setup at: $SETUP_FILE"
    
    # Make Setup executable
    chmod +x "$SETUP_FILE"
    
    # Create the installation directory with proper ownership
    sudo mkdir -p ${OPT_ARCGIS}
    sudo chown ${WEBSVC_USER}:${WEBSVC_GROUP} ${OPT_ARCGIS}
    sudo chmod 750 ${OPT_ARCGIS}
    
    # Run the installer as web-services user
    print_info "Running Web Adaptor installer (this may take a few minutes)..."
    sudo -u ${WEBSVC_USER} "$SETUP_FILE" -m silent -l yes -d /opt/arcgis -v

    print_info "Checking installation directory..."
    
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
    
    print_status "Web Adaptor installed"
}

# Deploy Web Adaptor WAR files
deploy_web_adaptor_wars() {
    print_section "Deploying Web Adaptor Applications"
    
    # Create webapps directory for arcgis if it doesn't exist
    sudo mkdir -p ${VAR_WEBSVC}/webapps
    
    # Search for WAR files
    print_info "Searching for Web Adaptor WAR files..."
    
    # Find portal WAR file
    PORTAL_WAR=$(find ${OPT_ARCGIS}/webadaptor* -name "arcgis.war" -path "*/portal/*" 2>/dev/null | head -1)
    SERVER_WAR=$(find ${OPT_ARCGIS}/webadaptor* -name "arcgis.war" -path "*/server/*" 2>/dev/null | head -1)
    
    # If not found with specific paths, just find all arcgis.war files
    if [[ -z "$PORTAL_WAR" ]]; then
        PORTAL_WAR=$(find ${OPT_ARCGIS} -name "arcgis.war" 2>/dev/null | grep -i portal | head -1)
    fi
    if [[ -z "$SERVER_WAR" ]]; then
        SERVER_WAR=$(find ${OPT_ARCGIS} -name "arcgis.war" 2>/dev/null | grep -i server | head -1)
    fi
    
    # Deploy Portal Web Adaptor
    if [[ -n "$PORTAL_WAR" && -f "$PORTAL_WAR" ]]; then
        print_info "Deploying Portal Web Adaptor from: $PORTAL_WAR"
        sudo cp "$PORTAL_WAR" ${VAR_WEBSVC}/webapps/portal.war
        sudo chown ${WEBSVC_USER}:${WEBSVC_GROUP} ${VAR_WEBSVC}/webapps/portal.war
        print_status "Deployed Portal Web Adaptor as portal.war"
    else
        print_warning "Portal Web Adaptor WAR file not found"
        print_info "Expected location: ${OPT_ARCGIS}/webadaptor/portal/war/arcgis.war"
        print_info "Searching for any portal WAR files:"
        find ${OPT_ARCGIS} -name "*.war" 2>/dev/null | grep -i portal || echo "  (none found)"
    fi
    
    # Deploy Server Web Adaptor
    if [[ -n "$SERVER_WAR" && -f "$SERVER_WAR" ]]; then
        print_info "Deploying Server Web Adaptor from: $SERVER_WAR"
        sudo cp "$SERVER_WAR" ${VAR_WEBSVC}/webapps/server.war
        sudo chown ${WEBSVC_USER}:${WEBSVC_GROUP} ${VAR_WEBSVC}/webapps/server.war
        print_status "Deployed Server Web Adaptor as server.war"
    else
        print_warning "Server Web Adaptor WAR file not found"
        print_info "Expected location: ${OPT_ARCGIS}/webadaptor/server/war/arcgis.war"
        print_info "Searching for any server WAR files:"
        find ${OPT_ARCGIS} -name "*.war" 2>/dev/null | grep -i server || echo "  (none found)"
    fi
    
    # Show what was actually deployed
    echo ""
    print_info "Contents of ${VAR_WEBSVC}/webapps:"
    ls -lh ${VAR_WEBSVC}/webapps/*.war 2>/dev/null || echo "  (no WAR files found)"
    
    # Restart Tomcat to deploy WARs
    print_info "Restarting Tomcat to deploy Web Adapters..."
    sudo systemctl restart tomcat
    
    # Wait for deployment
    print_info "Waiting for Web Adapters to deploy (this may take 30-60 seconds)..."
    sleep 30
    
    # Check if webapps are deployed
    if [[ -d "${VAR_WEBSVC}/webapps/portal" ]]; then
        print_status "Portal Web Adaptor deployed successfully"
    fi
    if [[ -d "${VAR_WEBSVC}/webapps/server" ]]; then
        print_status "Server Web Adaptor deployed successfully"
    fi
}

# Display post-installation information
display_summary() {
    print_section "Installation Complete!"
    
    echo ""
    echo -e "${GREEN}✓ Installation Summary:${NC}"
    echo -e "  • Java: $(java -version 2>&1 | head -1)"
    echo -e "  • Tomcat: Installed at $OPT_WEBSVC"
    
    if [[ "$SKIP_NGINX" == "false" ]]; then
        echo -e "  • Nginx: Configured as reverse proxy"
        echo -e "  • SSL/TLS: Certificates installed"
        echo ""
        echo -e "${BLUE}Architecture:${NC}"
        echo -e "  Internet → Nginx (HTTPS:443) → Tomcat (HTTP:8080, localhost) → Web Adapters"
    else
        echo -e "  • Mode: Standalone Tomcat (no Nginx)"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Web Adapters Deployed:${NC}"
    [[ -f "${VAR_WEBSVC}/webapps/portal.war" ]] && echo -e "  • Portal Web Adaptor: portal.war"
    [[ -f "${VAR_WEBSVC}/webapps/server.war" ]] && echo -e "  • Server Web Adaptor: server.war"
    
    echo ""
    echo -e "${YELLOW}⚠ Important Next Steps:${NC}"
    echo ""
    echo -e "1. ${BLUE}Verify Services:${NC}"
    if [[ "$SKIP_NGINX" == "false" ]]; then
        echo -e "   systemctl status nginx"
        echo -e "   systemctl status tomcat"
        echo -e "   curl -I https://$SERVER_DOMAIN"
    else
        echo -e "   systemctl status tomcat"
        echo -e "   curl -I http://localhost:8080"
    fi
    
    echo ""
    echo -e "2. ${BLUE}Access URLs:${NC}"
    if [[ "$SKIP_NGINX" == "false" ]]; then
        echo -e "   Main site:    https://$SERVER_DOMAIN"
        echo -e "   Health check: https://$SERVER_DOMAIN/health"
        echo -e ""
        echo -e "   ${YELLOW}After installing Portal for ArcGIS and ArcGIS Server:${NC}"
        echo -e "   Portal Web Adaptor config: https://$SERVER_DOMAIN/portal/webadaptor"
        echo -e "   Server Web Adaptor config: https://$SERVER_DOMAIN/server/webadaptor"
    else
        echo -e "   Main site: https://localhost:8080"
    fi
    
    echo ""
    echo -e "3. ${BLUE}Tomcat Manager Access (optional):${NC}"
    echo -e "   Create SSH tunnel: ssh -L 8080:localhost:8080 user@$SERVER_DOMAIN"
    echo -e "   Then access: http://localhost:8080/manager/html"
    
    echo ""
    echo -e "4. ${BLUE}Install ArcGIS Components:${NC}"
    echo -e "   • Install Portal for ArcGIS"
    echo -e "   • Install ArcGIS Server"
    echo -e "   ${RED}⚠ Do NOT configure Web Adapters until Portal/Server are installed!${NC}"
    
    echo ""
    echo -e "5. ${BLUE}Monitor Logs:${NC}"
    if [[ "$SKIP_NGINX" == "false" ]]; then
        echo -e "   Nginx:  tail -f /var/log/nginx/arcgis-error.log"
    fi
    echo -e "   Tomcat: tail -f /var/opt/tomcat/logs/catalina.out"
    if [[ "$SKIP_FAIL2BAN" == "false" && "$SKIP_NGINX" == "false" ]]; then
        echo -e "   Fail2Ban: sudo fail2ban-client status nginx-http-auth"
    fi
    
    if [[ "$SKIP_NGINX" == "false" ]]; then
        echo ""
        echo -e "${GREEN}✓ Security Features Enabled:${NC}"
        echo -e "  • SSL/TLS termination at Nginx"
        echo -e "  • Tomcat isolated on localhost (not exposed to internet)"
        echo -e "  • Rate limiting (50 req/s, burst 100)"
        echo -e "  • Connection limiting (20 concurrent per IP)"
        echo -e "  • Security headers (HSTS, X-Frame-Options, etc.)"
        echo -e "  • HTTP to HTTPS redirect"
        
        if [[ "$SKIP_FAIL2BAN" == "false" ]]; then
            echo -e "  • Fail2Ban intrusion prevention (nginx-http-auth, nginx-badbots, nginx-noproxy, nginx-noscript)"
        fi
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
}

# Main installation flow
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    ArcGIS Web Adaptor Installation                            ║
║    Nginx + Tomcat (Production-Ready Architecture)             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    if [[ "$SKIP_NGINX" == "true" ]]; then
        print_warning "Running in STANDALONE mode (Tomcat only - NOT recommended for production)"
    else
        print_info "Architecture: Internet → Nginx (HTTPS:443) → Tomcat (HTTP:8080, localhost)"
    fi
    
    print_info "Server domain: $SERVER_DOMAIN"
    echo ""
    
    # Execute installation steps
    check_prerequisites
    update_system
    configure_firewall
    create_web_services_user
    install_java
    install_tomcat
    configure_tomcat_permissions
    configure_tomcat_server_xml
    create_tomcat_service
    enable_remote_access
    start_tomcat
    install_nginx
    configure_ssl_certificates
    configure_nginx
    start_nginx
    install_fail2ban
    install_web_adaptor
    deploy_web_adaptor_wars
    
    # Display summary
    display_summary
}

# Run main function
main "$@"
