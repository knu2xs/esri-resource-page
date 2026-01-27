# Esri Software Mount Setup (Kerberos)

This script automates the setup of Kerberos-authenticated mounting of Esri internal software shares on Ubuntu systems. It eliminates the need to store passwords in plain text by using Active Directory Kerberos authentication.

## Features

- ✅ **Secure Authentication**: Uses Kerberos tickets instead of storing passwords
- ✅ **Automatic Mounting**: Configures `/etc/fstab` for mount on boot
- ✅ **Ticket Renewal**: Automatic Kerberos ticket renewal via systemd timer
- ✅ **Multi-user Support**: Allows multiple users to access with their own credentials
- ✅ **SMB 3.0**: Uses modern SMB protocol for better security and performance
- ✅ **Idempotent**: Safe to run multiple times

## Prerequisites

- Ubuntu system on the internal Esri network
- Sudo/root access
- Valid Esri Active Directory (AVWORLD) credentials
- Network connectivity to `red-inf-dct-p01.esri.com`

## Installation

### Quick Start

1. Make the script executable:
   ```bash
   chmod +x setup_esri_mount_kerberos.sh
   ```

2. Run the script with your Esri username:
   ```bash
   sudo ./setup_esri_mount_kerberos.sh --username your_username
   ```

3. Enter your password when prompted for Kerberos authentication

### Advanced Usage

```bash
sudo ./setup_esri_mount_kerberos.sh [OPTIONS]

Options:
  -u, --username USERNAME     Esri username (required)
  -m, --mount-point PATH      Mount point (default: /mnt/software)
  -r, --realm REALM           Kerberos realm (default: AVWORLD.ESRI.COM)
  -s, --server SERVER         SMB server (default: red-inf-dct-p01.esri.com)
  -h, --help                  Display help message
```

### Examples

**Basic setup:**
```bash
sudo ./setup_esri_mount_kerberos.sh --username jdoe
```

**Custom mount point:**
```bash
sudo ./setup_esri_mount_kerberos.sh --username jdoe --mount-point /opt/esri-software
```

**Custom server:**
```bash
sudo ./setup_esri_mount_kerberos.sh --username jdoe --server custom-server.esri.com
```

## What the Script Does

1. **Installs Required Packages**
   - `cifs-utils`: CIFS/SMB filesystem utilities
   - `krb5-user`: Kerberos authentication tools
   - `keyutils`: Key management utilities

2. **Configures Kerberos**
   - Creates `/etc/krb5.conf` with AVWORLD realm settings
   - Configures ticket lifetime and renewal options

3. **Creates Mount Point**
   - Creates directory at `/mnt/software` (or custom path)

4. **Configures Automatic Mounting**
   - Adds entry to `/etc/fstab` for mount on boot
   - Uses `sec=krb5` for Kerberos authentication
   - Uses `multiuser` option for multi-user access

5. **Sets Up Automatic Ticket Renewal**
   - Creates systemd service: `kerberos-renew.service`
   - Creates systemd timer: `kerberos-renew.timer`
   - Renews ticket every 6 hours automatically

6. **Obtains Initial Kerberos Ticket**
   - Prompts for password and obtains ticket via `kinit`

7. **Mounts the Share**
   - Mounts share using Kerberos authentication

8. **Verifies Setup**
   - Checks mount status
   - Verifies fstab configuration
   - Confirms systemd timer is active
   - Validates Kerberos ticket

## Post-Installation

### Verify Mount

```bash
# Check if mounted
df -h | grep software

# List contents
ls /mnt/software
```

### Check Kerberos Ticket

```bash
# View current ticket
klist

# Renew ticket manually if needed
kinit -R
```

### Check Systemd Timer

```bash
# Check timer status
sudo systemctl status kerberos-renew.timer

# View timer logs
sudo journalctl -u kerberos-renew.service
```

### Test After Reboot

```bash
# Reboot system
sudo reboot

# After reboot, verify mount
df -h | grep software
```

## Troubleshooting

### Mount Fails

**Check network connectivity:**
```bash
ping red-inf-dct-p01.esri.com
```

**Check Kerberos ticket:**
```bash
klist
# If expired or missing:
kinit your_username@AVWORLD.ESRI.COM
```

**Try manual mount:**
```bash
sudo mount -t cifs -o sec=krb5,vers=3.0,multiuser //red-inf-dct-p01.esri.com/software/Esri/Released /mnt/software
```

### Ticket Renewal Issues

**Check service status:**
```bash
sudo systemctl status kerberos-renew.timer
sudo systemctl status kerberos-renew.service
```

**Restart timer:**
```bash
sudo systemctl restart kerberos-renew.timer
```

**View logs:**
```bash
sudo journalctl -u kerberos-renew.service -f
```

### Permission Denied

Ensure your user has access to the share:
```bash
# Check if mounted with multiuser option
mount | grep software

# Try accessing as your user
ls /mnt/software
```

## Uninstallation

To remove the setup:

```bash
# Unmount share
sudo umount /mnt/software

# Stop and disable timer
sudo systemctl stop kerberos-renew.timer
sudo systemctl disable kerberos-renew.timer

# Remove systemd files
sudo rm /etc/systemd/system/kerberos-renew.service
sudo rm /etc/systemd/system/kerberos-renew.timer

# Remove fstab entry
sudo nano /etc/fstab
# (manually remove the line containing the share)

# Reload systemd
sudo systemctl daemon-reload

# Remove mount point (optional)
sudo rmdir /mnt/software
```

## Security Notes

- **No Password Storage**: Passwords are never stored on disk
- **Kerberos Authentication**: Uses secure ticket-based authentication
- **Automatic Renewal**: Tickets are renewed before expiration
- **Multi-user**: Each user authenticates with their own credentials
- **SMB 3.0**: Uses modern protocol with encryption support

## Support

For issues or questions:
- Check the [documentation](../docs/ArcGIS_Enterprise_Installation/ArcGIS_Enterprise_on_Ubuntu/accessing_esri_software_ubuntu.md)
- Contact your Esri IT support team
- Verify network connectivity and Active Directory access
