#!/bin/bash

# Script to set up Kerberos-authenticated mounting of Esri software share on Ubuntu
# This script must be run with sudo privileges

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
REALM="AVWORLD.ESRI.COM"
DOMAIN="esri.com"
SMB_SERVER="red-inf-dct-p01.esri.com"
SMB_SHARE="software/Esri/Released"
MOUNT_POINT="/mnt/software"
USERNAME=""

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to prompt for username
get_username() {
    if [[ -z "$USERNAME" ]]; then
        read -p "Enter your Esri username: " USERNAME
        if [[ -z "$USERNAME" ]]; then
            print_error "Username cannot be empty"
            exit 1
        fi
    fi
}

# Function to install required packages
install_packages() {
    print_info "Installing required packages..."
    apt update
    apt install -y cifs-utils krb5-user keyutils
    print_info "Packages installed successfully"
}

# Function to configure Kerberos
configure_kerberos() {
    print_info "Configuring Kerberos..."
    
    cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    ${REALM} = {
        kdc = ${REALM}
        admin_server = ${REALM}
    }

[domain_realm]
    .${DOMAIN} = ${REALM}
    ${DOMAIN} = ${REALM}
EOF
    
    print_info "Kerberos configuration complete"
}

# Function to create mount point
create_mount_point() {
    print_info "Creating mount point at ${MOUNT_POINT}..."
    mkdir -p "${MOUNT_POINT}"
    print_info "Mount point created"
}

# Function to configure fstab
configure_fstab() {
    print_info "Configuring /etc/fstab for automatic mounting..."
    
    # Check if entry already exists
    if grep -q "${SMB_SERVER}/${SMB_SHARE}" /etc/fstab; then
        print_warning "Entry already exists in /etc/fstab. Skipping..."
        return
    fi
    
    # Add entry to fstab
    echo "//${SMB_SERVER}/${SMB_SHARE} ${MOUNT_POINT} cifs sec=krb5,vers=3.0,multiuser,_netdev 0 0" >> /etc/fstab
    
    print_info "/etc/fstab configured"
}

# Function to create Kerberos renewal systemd service
create_kerberos_service() {
    print_info "Creating Kerberos ticket renewal service..."
    
    cat > /etc/systemd/system/kerberos-renew.service <<EOF
[Unit]
Description=Kerberos Ticket Renewal
After=network-online.target

[Service]
Type=simple
User=${USERNAME}
ExecStart=/usr/bin/kinit -R
Restart=on-failure
RestartSec=3600

[Install]
WantedBy=multi-user.target
EOF
    
    print_info "Kerberos service created"
}

# Function to create Kerberos renewal timer
create_kerberos_timer() {
    print_info "Creating Kerberos ticket renewal timer..."
    
    cat > /etc/systemd/system/kerberos-renew.timer <<EOF
[Unit]
Description=Kerberos Ticket Renewal Timer

[Timer]
OnBootSec=15min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF
    
    print_info "Kerberos timer created"
}

# Function to enable systemd services
enable_services() {
    print_info "Enabling Kerberos renewal timer..."
    systemctl daemon-reload
    systemctl enable kerberos-renew.timer
    systemctl start kerberos-renew.timer
    print_info "Kerberos renewal timer enabled and started"
}

# Function to obtain initial Kerberos ticket
obtain_ticket() {
    print_info "Obtaining Kerberos ticket for ${USERNAME}@${REALM}..."
    print_warning "You will be prompted for your password"
    
    su - "${USERNAME}" -c "kinit ${USERNAME}@${REALM}"
    
    if su - "${USERNAME}" -c "klist" > /dev/null 2>&1; then
        print_info "Kerberos ticket obtained successfully"
        su - "${USERNAME}" -c "klist"
    else
        print_error "Failed to obtain Kerberos ticket"
        exit 1
    fi
}

# Function to mount the share
mount_share() {
    print_info "Mounting share..."
    
    if mount | grep -q "${MOUNT_POINT}"; then
        print_warning "Share is already mounted. Unmounting..."
        umount "${MOUNT_POINT}"
    fi
    
    mount -t cifs -o sec=krb5,vers=3.0,multiuser "//${SMB_SERVER}/${SMB_SHARE}" "${MOUNT_POINT}"
    
    if mount | grep -q "${MOUNT_POINT}"; then
        print_info "Share mounted successfully at ${MOUNT_POINT}"
    else
        print_error "Failed to mount share"
        exit 1
    fi
}

# Function to verify setup
verify_setup() {
    print_info "Verifying setup..."
    
    # Check mount
    if mount | grep -q "${MOUNT_POINT}"; then
        print_info "✓ Share is mounted"
        df -h | grep "${MOUNT_POINT}"
    else
        print_warning "✗ Share is not mounted"
    fi
    
    # Check fstab
    if grep -q "${SMB_SERVER}/${SMB_SHARE}" /etc/fstab; then
        print_info "✓ fstab entry exists"
    else
        print_warning "✗ fstab entry missing"
    fi
    
    # Check systemd timer
    if systemctl is-active --quiet kerberos-renew.timer; then
        print_info "✓ Kerberos renewal timer is active"
    else
        print_warning "✗ Kerberos renewal timer is not active"
    fi
    
    # Check Kerberos ticket
    if su - "${USERNAME}" -c "klist" > /dev/null 2>&1; then
        print_info "✓ Kerberos ticket is valid"
    else
        print_warning "✗ No valid Kerberos ticket found"
    fi
}

# Function to display usage
usage() {
    cat <<EOF
Usage: sudo $0 [OPTIONS]

Options:
    -u, --username USERNAME     Esri username (required)
    -m, --mount-point PATH      Mount point (default: /mnt/software)
    -r, --realm REALM           Kerberos realm (default: AVWORLD.ESRI.COM)
    -s, --server SERVER         SMB server (default: red-inf-dct-p01.esri.com)
    -h, --help                  Display this help message

Example:
    sudo $0 --username jdoe

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -m|--mount-point)
            MOUNT_POINT="$2"
            shift 2
            ;;
        -r|--realm)
            REALM="$2"
            shift 2
            ;;
        -s|--server)
            SMB_SERVER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "======================================"
    echo "Esri Software Mount Setup (Kerberos)"
    echo "======================================"
    echo ""
    
    check_root
    get_username
    
    print_info "Configuration:"
    echo "  Username:    ${USERNAME}"
    echo "  Realm:       ${REALM}"
    echo "  Mount Point: ${MOUNT_POINT}"
    echo "  SMB Server:  ${SMB_SERVER}"
    echo "  SMB Share:   ${SMB_SHARE}"
    echo ""
    
    read -p "Proceed with installation? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Installation cancelled"
        exit 0
    fi
    
    install_packages
    configure_kerberos
    create_mount_point
    configure_fstab
    create_kerberos_service
    create_kerberos_timer
    enable_services
    obtain_ticket
    mount_share
    
    echo ""
    echo "======================================"
    print_info "Setup complete!"
    echo "======================================"
    echo ""
    
    verify_setup
    
    echo ""
    print_info "The share will be automatically mounted on boot."
    print_info "Kerberos tickets will be automatically renewed every 6 hours."
    print_info "Access the Esri software at: ${MOUNT_POINT}"
}

# Run main function
main
