# Esri Software Share Mount Setup

This script provides a simple way to mount Esri internal software shares on Ubuntu systems using password authentication. It's designed for quick, temporary access to retrieve software without complex configuration.

## Features

- ✅ **Simple Setup**: Minimal configuration required
- ✅ **Password Prompt**: Securely prompts for password at runtime (no plain text storage)
- ✅ **Quick Access**: Mount share, get software, unmount
- ✅ **Flexible**: Supports parameter input or interactive prompts
- ✅ **No Background Services**: Clean, straightforward mounting

## Prerequisites

- Ubuntu system on the internal Esri network
- Sudo/root access
- Valid Esri Active Directory credentials
- Network connectivity to `RED-INF-DCT-P05.esri.com`

## Installation

### Quick Start

1. Make the script executable:
   ```bash
   chmod +x setup_esri_mount_kerberos.sh
   ```

2. Run the script (you'll be prompted for username and password):
   ```bash
   sudo ./setup_esri_mount_kerberos.sh
   ```

3. Or provide username as parameter (still prompts for password):
   ```bash
   sudo ./setup_esri_mount_kerberos.sh --username your_username
   ```

### Advanced Usage

```bash
sudo ./setup_esri_mount_kerberos.sh [OPTIONS]

Options:
  -u, --username USERNAME     Esri username (without @esri.com)
  -p, --password PASSWORD     Password (if not provided, you'll be prompted)
  -m, --mount-point PATH      Mount point (default: /mnt/software)
  -s, --server SERVER         SMB server (default: RED-INF-DCT-P05.esri.com)
  --share SHARE               SMB share path (default: software/Esri/Released)
  -h, --help                  Display help message
```

### Examples

**Interactive mode (recommended - prompts for both username and password):**
```bash
sudo ./setup_esri_mount_kerberos.sh
```

**Provide username (prompts for password):**
```bash
sudo ./setup_esri_mount_kerberos.sh --username jdoe
```

**Custom mount point:**
```bash
sudo ./setup_esri_mount_kerberos.sh --username jdoe --mount-point /mnt/esri
```

**Provide password as parameter (less secure - visible in process list):**
```bash
sudo ./setup_esri_mount_kerberos.sh --username jdoe --password mypassword
```

## What the Script Does

1. **Checks for Root Access**
   - Ensures script is run with sudo privileges

2. **Prompts for Credentials**
   - Asks for username (if not provided)
   - Securely prompts for password (hidden input)

3. **Installs Required Package**
   - Installs `cifs-utils` if not already present

4. **Creates Mount Point**
   - Creates directory at `/mnt/software` (or custom path)
   - Unmounts any existing mount at that location

5. **Mounts the Share**
   - Mounts share using username/password authentication
   - Verifies mount is accessible

## Post-Installation

### Verify Mount

```bash
# Check if mounted
df -h | grep software

# List contents
ls /mnt/software

# Access your software
cd /mnt/software
```

### Unmount When Finished

```bash
# Unmount the share
sudo umount /mnt/software
```

**Note:** The mount is temporary and will not persist after reboot. This is intentional for security - no passwords are saved.

## Troubleshooting

### Mount Fails

**Check network connectivity:**
```bash
ping RED-INF-DCT-P05.esri.com
```

**Verify credentials:**
- Ensure username is correct (without @esri.com)
- Verify password is correct
- Confirm you have access to the share

**Try manual mount:**
```bash
sudo mount -t cifs //RED-INF-DCT-P05.esri.com/software/Esri/Released /mnt/software -o username=YOUR_USERNAME,domain=ESRI
# You'll be prompted for password
```

### Permission Denied

- Verify your AD account has access to the software share
- Try accessing from a Windows machine first to confirm permissions
- Check with IT if you should have access

### Mount Already Exists

If you get an error about the mount already existing:
```bash
# Unmount first
sudo umount /mnt/software

# Then run the script again
sudo ./setup_esri_mount_kerberos.sh
```

## Cleanup

To unmount and clean up:

```bash
# Unmount share
sudo umount /mnt/software

# Remove mount point (optional)
sudo rmdir /mnt/software
```

## Security Notes

- **No Password Storage**: Passwords are prompted at runtime and never saved to disk
- **Temporary Mount**: Mount does not persist after reboot
- **Secure Input**: Password input is hidden when typing
- **Limited Scope**: Designed for temporary access to retrieve needed software

## Use Case

This script is ideal for:
- Quickly retrieving software installations
- One-time access to internal shares
- Development environments where you need occasional access
- Situations where you don't need persistent mounts

## Support

For issues or questions:
- Check the [accessing software documentation](../docs/ArcGIS_Enterprise_Installation/ArcGIS_Enterprise_on_Ubuntu/accessing_esri_software_ubuntu.md)
- Contact your Esri IT support team
- Verify network connectivity and Active Directory access
