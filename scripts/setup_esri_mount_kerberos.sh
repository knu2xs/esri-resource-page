#!/bin/bash

# Script to mount Esri software share on Ubuntu
# This script must be run with sudo privileges

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DOMAIN="ESRI"
SMB_SERVER="RED-INF-DCT-P05.esri.com"
SMB_SHARE="software/Esri/Released"
MOUNT_POINT="/mnt/software"
USERNAME=""
PASSWORD=""

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
        echo -n "Enter your Esri username (without @esri.com): "
        read USERNAME 0</dev/tty
        if [[ -z "$USERNAME" ]]; then
            print_error "Username cannot be empty"
            exit 1
        fi
    fi
    
    # Clean username if it contains @ symbol
    if [[ "$USERNAME" == *@* ]]; then
        USERNAME="${USERNAME%%@*}"
        print_info "Using username: ${USERNAME}"
    fi
}

# Function to prompt for password
get_password() {
    if [[ -z "$PASSWORD" ]]; then
        echo -n "Enter your password: "
        read -s PASSWORD 0</dev/tty
        echo ""
        if [[ -z "$PASSWORD" ]]; then
            print_error "Password cannot be empty"
            exit 1
        fi
    fi
}

# Function to install required packages
install_packages() {
    print_info "Checking for required packages..."
    
    if dpkg -l | grep -q "^ii  cifs-utils "; then
        print_info "cifs-utils is already installed"
        return
    fi
    
    print_info "Installing cifs-utils..."
    apt update
    apt install -y cifs-utils
    print_info "Package installed successfully"
}

# Function to create mount point
create_mount_point() {
    print_info "Creating mount point at ${MOUNT_POINT}..."
    
    # Unmount if already mounted
    if mount | grep -q " ${MOUNT_POINT} "; then
        print_info "Found existing mount, unmounting..."
        umount "${MOUNT_POINT}" 2>/dev/null || umount -l "${MOUNT_POINT}" 2>/dev/null || true
    fi
    
    # Create the mount point if it doesn't exist
    if [[ ! -d "${MOUNT_POINT}" ]]; then
        mkdir -p "${MOUNT_POINT}"
    fi
    
    print_info "Mount point ready"
}

# Function to mount the share
mount_share() {
    print_info "Mounting share..."
    
    # Mount with username and password
    print_info "Executing mount command..."
    if mount -t cifs "//${SMB_SERVER}/${SMB_SHARE}" "${MOUNT_POINT}" \
        -o username="${USERNAME}",password="${PASSWORD}",domain="${DOMAIN}"; then
        print_info "✓ Share mounted successfully at ${MOUNT_POINT}"
        
        # Verify the mount
        if ls "${MOUNT_POINT}" > /dev/null 2>&1; then
            print_info "✓ Mount verified and accessible"
            print_info "You can now access files at: ${MOUNT_POINT}"
        else
            print_warning "Mount appears successful but directory is not accessible"
        fi
    else
        print_error "Failed to mount share"
        print_error "Please verify:"
        print_error "  - Your username and password are correct"
        print_error "  - You have access to the network share"
        print_error "  - The server is reachable: ${SMB_SERVER}"
        exit 1
    fi
}

# Function to display usage
usage() {
    cat <<EOF
Usage: sudo $0 [OPTIONS]

Simple script for mounting Esri software share on Ubuntu with password authentication.

Options:
    -u, --username USERNAME     Esri username (without @esri.com)
    -p, --password PASSWORD     Password (if not provided, you'll be prompted)
    -m, --mount-point PATH      Mount point (default: /mnt/software)
    -s, --server SERVER         SMB server (default: RED-INF-DCT-P05.esri.com)
    --share SHARE               SMB share path (default: software/Esri/Released)
    -h, --help                  Display this help message

Examples:
    # Basic usage (will prompt for password)
    sudo $0 --username jdoe

    # Provide password as parameter (less secure, visible in process list)
    sudo $0 --username jdoe --password mypassword

    # Custom mount point
    sudo $0 --username jdoe --mount-point /mnt/esri

To unmount when finished:
    sudo umount ${MOUNT_POINT}

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -m|--mount-point)
            MOUNT_POINT="$2"
            shift 2
            ;;
        -s|--server)
            SMB_SERVER="$2"
            shift 2
            ;;
        --share)
            SMB_SHARE="$2"
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
    echo "==========================================="
    echo "Esri Software Share Mount"
    echo "==========================================="
    echo ""
    
    check_root
    get_username
    get_password
    
    print_info "Configuration:"
    echo "  Username:    ${USERNAME}"
    echo "  Mount Point: ${MOUNT_POINT}"
    echo "  SMB Server:  ${SMB_SERVER}"
    echo "  SMB Share:   ${SMB_SHARE}"
    echo ""
    
    install_packages
    create_mount_point
    mount_share
    
    echo ""
    echo "==========================================="
    print_info "Setup complete!"
    echo "==========================================="
    echo ""
    print_info "The share is now mounted at: ${MOUNT_POINT}"
    print_info "To unmount when finished: sudo umount ${MOUNT_POINT}"
}

# Run main function
main
