# SSH File Transfer Methods: Mac/Windows to Linux

## Overview

Transferring files from Mac or Windows computers to Linux servers is a common task in enterprise environments. SSH-based file transfer methods provide secure, encrypted connections for copying files between systems. This guide covers various methods, their use cases, and best practices for efficient file transfers.

---

## Transfer Methods Comparison

| Method | Platform Support | Best For | Complexity | Speed | Resume Support |
|--------|-----------------|----------|------------|-------|----------------|
| **rsync over SSH** | Mac, Linux | Large/incremental transfers | Medium | Fast | ✓ |
| **scp** | Mac, Windows, Linux | Simple one-time transfers | Low | Fast | ✗ |
| **sftp** | Mac, Windows, Linux | Interactive browsing | Medium | Fast | ✓ |
| **GUI Tools** | Mac, Windows | Non-technical users | Low | Medium | ✓ |

---

## Method 1: rsync over SSH (Recommended)

**Best for**: Large files, directories, incremental backups, repeated transfers

### Why rsync is Preferred

- **Incremental transfers**: Only copies changed portions of files
- **Resume capability**: Can restart interrupted transfers
- **Bandwidth efficiency**: Delta-transfer algorithm minimizes data sent
- **Preserve attributes**: Maintains permissions, timestamps, ownership
- **Progress display**: Shows transfer progress and estimated time
- **Compression**: Built-in compression for faster transfers over slow links
- **Exclude patterns**: Skip specific files or directories

### Basic Usage

**From Mac/Linux to Remote Linux Server**:

```bash
# Copy single file
rsync -avz /local/path/file.txt user@remote-host:/remote/path/

# Copy entire directory
rsync -avz /local/path/directory/ user@remote-host:/remote/path/

# Copy multiple files
rsync -avz /local/path/*.txt user@remote-host:/remote/path/
```

**Common Options**:

- `-a` (archive): Preserves permissions, timestamps, symlinks
- `-v` (verbose): Shows files being transferred
- `-z` (compress): Compresses data during transfer
- `-P` (progress): Shows progress and enables resume
- `--delete`: Removes files from destination that don't exist in source
- `--exclude`: Exclude specific files or patterns

### Advanced Examples

**Sync directory with progress and exclusions**:

```bash
rsync -avzP --exclude='*.log' --exclude='node_modules/' \
    /local/projects/ user@remote-host:/remote/projects/
```

**Dry run to see what would be transferred**:

```bash
rsync -avzn /local/path/ user@remote-host:/remote/path/
```

**Resume interrupted transfer**:

```bash
rsync -avzP /local/large-file.zip user@remote-host:/remote/path/
```

**Mirror directory (delete files not in source)**:

```bash
rsync -avz --delete /local/path/ user@remote-host:/remote/path/
```

### Performance Tuning

**Faster transfers with reduced compression**:

```bash
rsync -av --compress-level=1 /local/path/ user@remote-host:/remote/path/
```

**Parallel transfers for multiple files (using GNU parallel)**:

```bash
find /local/path -type f | parallel -j 4 rsync -avz {} user@remote-host:/remote/path/
```

### Best Practices

- Always use trailing slashes consistently: `/source/` vs `/source` affects behavior
- Test with `--dry-run` (`-n`) before running destructive operations
- Use `--exclude` to skip unnecessary files (.git, node_modules, etc.)
- Enable compression (`-z`) for slow network connections
- Use `-P` for large transfers to see progress and enable resume

---

## Method 2: scp (Secure Copy)

**Best for**: Simple one-time file transfers, scripting, quick copies

### Basic Usage

**Copy file to remote server**:

```bash
scp /local/path/file.txt user@remote-host:/remote/path/
```

**Copy file from remote server**:

```bash
scp user@remote-host:/remote/path/file.txt /local/path/
```

**Copy entire directory (recursive)**:

```bash
scp -r /local/directory/ user@remote-host:/remote/path/
```

**Copy multiple files**:

```bash
scp file1.txt file2.txt file3.txt user@remote-host:/remote/path/
```

### Advanced Options

**With progress display**:

```bash
scp -v /local/file.txt user@remote-host:/remote/path/
```

**Specify different SSH port**:

```bash
scp -P 2222 /local/file.txt user@remote-host:/remote/path/
```

**Preserve file attributes**:

```bash
scp -p /local/file.txt user@remote-host:/remote/path/
```

**Limit bandwidth (in Kbit/s)**:

```bash
scp -l 8000 /local/large-file.zip user@remote-host:/remote/path/
```

**Use compression**:

```bash
scp -C /local/file.txt user@remote-host:/remote/path/
```

### Limitations

- No incremental transfer capability (always copies entire file)
- Cannot resume interrupted transfers
- Less efficient for large directories with many files
- No built-in progress bar (use `-v` for verbose output)

### When to Use scp

- Quick one-time file copies
- Simple scripting scenarios
- When rsync is not available
- Transferring small numbers of files

---

## Method 3: sftp (Interactive)

**Best for**: Interactive browsing, batch operations, Windows users

### Basic Usage

**Connect to remote server**:

```bash
sftp user@remote-host
```

**Common Interactive Commands**:

```bash
# List local directory
lls

# List remote directory
ls

# Change local directory
lcd /local/path

# Change remote directory
cd /remote/path

# Upload file
put local-file.txt

# Upload directory recursively
put -r local-directory/

# Download file
get remote-file.txt

# Download directory recursively
get -r remote-directory/

# Upload multiple files
mput *.txt

# Download multiple files
mget *.log

# Create remote directory
mkdir new-directory

# Delete remote file
rm file.txt

# Exit
exit
```

### Batch Mode (Non-Interactive)

**Using batch file**:

```bash
# Create batch file: transfer-commands.txt
lcd /local/path
cd /remote/path
put file1.txt
put file2.txt
mkdir new-folder
cd new-folder
put -r directory/
exit

# Execute batch
sftp -b transfer-commands.txt user@remote-host
```

**Using heredoc for scripting**:

```bash
sftp user@remote-host << EOF
cd /remote/path
put /local/file.txt
exit
EOF
```

### Best Practices

- Use batch mode for scripting and automation
- Interactive mode is useful for exploring remote filesystem
- Supports resume with `reget` and `reput` commands
- Use `-P` flag to specify non-standard SSH port

---

## Method 4: GUI Tools

**Best for**: Non-technical users, visual file browsing, Windows users

### Mac GUI Tools

#### 1. **Cyberduck** (Free, Recommended)

- Download: [https://cyberduck.io](https://cyberduck.io)
- Simple drag-and-drop interface
- Bookmark management
- Supports SFTP, SCP, and many other protocols
- Resume interrupted transfers
- Free and open source

**Setup**:

1. Click "Open Connection"
2. Select "SFTP (SSH File Transfer Protocol)"
3. Enter hostname, username, and password/SSH key
4. Click "Connect"

#### 2. **FileZilla** (Free)

- Download: [https://filezilla-project.org](https://filezilla-project.org)
- Popular cross-platform client
- Queue management
- Transfer speed limits
- Site manager for saved connections

#### 3. **Transmit** (Paid)

- Mac App Store or [https://panic.com/transmit](https://panic.com/transmit)
- Native Mac interface
- Very fast transfers
- Excellent file browsing
- $45 one-time purchase

### Windows GUI Tools

#### 1. **WinSCP** (Free, Recommended for Windows)

- Download: [https://winscp.net](https://winscp.net)
- Most popular Windows SFTP client
- Dual-pane interface
- Scripting support
- Integration with PuTTY
- Resume interrupted transfers
- Free and open source

**Setup**:

1. Launch WinSCP
2. Click "New Site"
3. File protocol: SFTP
4. Enter hostname, username, and password/SSH key
5. Click "Login"

#### 2. **FileZilla** (Free)

- Same as Mac version
- Cross-platform consistency

#### 3. **MobaXterm** (Free/Paid)

- Download: [https://mobaxterm.mobatek.net](https://mobaxterm.mobatek.net)
- All-in-one tool (SSH + SFTP + X11)
- Integrated terminal and file browser
- Session management
- Free version available

### GUI Tool Best Practices

- Save connection profiles with SSH keys for security
- Use bookmarks for frequently accessed directories
- Enable transfer queue to monitor multiple operations
- Configure automatic resume for large files
- Set bandwidth limits if needed

---

## SSH Key Authentication Setup

For password-less authentication and improved security, use SSH keys.

### Generate SSH Key Pair (Mac/Linux)

```bash
# Generate RSA key (4096-bit recommended)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Or generate Ed25519 key (more modern, faster)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Save to default location: ~/.ssh/id_rsa or ~/.ssh/id_ed25519
# Set a passphrase for additional security (optional but recommended)
```

### Copy Public Key to Remote Server

**Using ssh-copy-id (easiest)**:

```bash
ssh-copy-id user@remote-host
```

**Manual method**:

```bash
# Display your public key
cat ~/.ssh/id_rsa.pub

# SSH to remote server and add key
ssh user@remote-host
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "your-public-key-content" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit
```

### Generate SSH Key on Windows

**Using PuTTYgen (for WinSCP/PuTTY)**:

1. Download and launch PuTTYgen
2. Click "Generate" and move mouse for randomness
3. Save private key (.ppk format)
4. Copy public key text
5. Add public key to remote server's `~/.ssh/authorized_keys`

**Using Windows OpenSSH**:

```powershell
# In PowerShell
ssh-keygen -t rsa -b 4096
```

### Test SSH Key Authentication

```bash
ssh user@remote-host
# Should connect without password prompt
```

---

## Choosing the Right Method

### Use **rsync** when:

- Transferring large directories or datasets
- Need incremental/delta transfers
- Performing repeated syncs (backups, deployments)
- Want to resume interrupted transfers
- Need to preserve file attributes precisely
- Have slow or unreliable network connections

### Use **scp** when:

- Quick one-time file copy needed
- Scripting simple transfers
- Transferring small files
- rsync is not available
- Don't need resume capability

### Use **sftp** when:

- Need interactive browsing of remote filesystem
- Want to explore directories before transferring
- Performing batch operations via script
- Need resume capability but rsync unavailable

### Use **GUI tools** when:

- Non-technical users need to transfer files
- Prefer visual interface
- Need bookmark management
- Want drag-and-drop functionality
- Managing multiple concurrent transfers

---

## Performance Optimization Tips

### 1. **Enable Compression for Slow Connections**

```bash
# rsync with compression
rsync -avz /local/path/ user@remote-host:/remote/path/

# scp with compression
scp -C /local/file.txt user@remote-host:/remote/path/
```

### 2. **Disable Compression for Fast Networks**

```bash
# rsync without compression (faster on fast networks)
rsync -av /local/path/ user@remote-host:/remote/path/

# Or use minimal compression
rsync -av --compress-level=1 /local/path/ user@remote-host:/remote/path/
```

### 3. **Use SSH Connection Multiplexing**

Add to `~/.ssh/config`:

```
Host remote-host
    HostName remote-host.example.com
    User username
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
```

Create socket directory:

```bash
mkdir -p ~/.ssh/sockets
```

Benefits: Reuses existing SSH connection, faster for multiple transfers

### 4. **Increase SSH Cipher Speed**

Use faster (but still secure) ciphers in `~/.ssh/config`:

```
Host remote-host
    Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
```

### 5. **Parallel Transfers**

For multiple independent files:

```bash
# Using GNU parallel with rsync
find /local/path -type f | parallel -j 4 rsync -avz {} user@remote-host:/remote/path/

# Or split large transfer into parallel rsync jobs
```

---

## Common Issues and Solutions

### Issue: Connection Timeout

**Solution**: Check firewall, verify SSH port (default 22), test basic SSH connection:

```bash
ssh -v user@remote-host
```

### Issue: Permission Denied (publickey)

**Solution**: Verify SSH key is added to remote server's authorized_keys:

```bash
ssh-copy-id user@remote-host
# Or manually add public key to ~/.ssh/authorized_keys on remote server
```

### Issue: Slow Transfer Speed

**Solutions**:

- Enable compression for slow links: `-z` flag
- Disable compression for fast links
- Use SSH connection multiplexing
- Check network bandwidth with `iperf3`
- Use faster SSH ciphers

### Issue: Transfer Interrupted

**Solution**: Use rsync with `-P` flag to resume:

```bash
rsync -avzP /local/file.zip user@remote-host:/remote/path/
```

### Issue: Too Many Files (scp very slow)

**Solution**: Switch to rsync for better performance:

```bash
# Instead of: scp -r /large-directory/ user@remote-host:/path/
# Use:
rsync -avz /large-directory/ user@remote-host:/path/
```

---

## Security Best Practices

1. **Always use SSH keys instead of passwords**
    - More secure
    - Enable automation
    - Can be passphrase-protected

2. **Use strong SSH key types**
    - Ed25519 (recommended): `ssh-keygen -t ed25519`
    - RSA 4096-bit minimum: `ssh-keygen -t rsa -b 4096`

3. **Protect private keys**
    - Set proper permissions: `chmod 600 ~/.ssh/id_rsa`
    - Never share private keys
    - Use passphrase protection

4. **Disable password authentication on server**
    - Edit `/etc/ssh/sshd_config`: `PasswordAuthentication no`
    - Forces key-based authentication

5. **Use SSH config for convenience and consistency**
    - Create `~/.ssh/config` with host aliases
    - Specify ports, users, keys per host
    - Enable connection multiplexing

6. **Verify host fingerprints**
    - Check fingerprint on first connection
    - Avoid automatic "yes" to unknown hosts

---

## Scripting Examples

### Automated Backup Script (rsync)

```bash
#!/bin/bash

# Configuration
SOURCE_DIR="/local/data"
DEST_HOST="backup-server"
DEST_PATH="/backup/data"
LOG_FILE="/var/log/backup.log"
EXCLUDE_FILE="/etc/backup-exclude.txt"

# Create exclude file if needed
cat > "$EXCLUDE_FILE" << EOF
*.log
*.tmp
.DS_Store
node_modules/
EOF

# Perform backup
echo "$(date): Starting backup..." >> "$LOG_FILE"

rsync -avz \
    --delete \
    --exclude-from="$EXCLUDE_FILE" \
    --log-file="$LOG_FILE" \
    "$SOURCE_DIR/" \
    "$DEST_HOST:$DEST_PATH/"

if [ $? -eq 0 ]; then
    echo "$(date): Backup completed successfully" >> "$LOG_FILE"
else
    echo "$(date): Backup failed!" >> "$LOG_FILE"
    exit 1
fi
```

### Batch Upload Script (sftp)

```bash
#!/bin/bash

HOST="remote-host"
USER="username"
REMOTE_DIR="/remote/uploads"
LOCAL_DIR="/local/files"

# Create batch commands
sftp "$USER@$HOST" << EOF
cd $REMOTE_DIR
lcd $LOCAL_DIR
put *.txt
put *.pdf
mkdir reports
cd reports
put -r ./reports/*
bye
EOF
```

### Progress Monitoring Script

```bash
#!/bin/bash

# Function to transfer with progress
transfer_with_progress() {
    local source="$1"
    local dest="$2"
    
    rsync -avzP \
        --stats \
        "$source" \
        "$dest" | tee /tmp/rsync-progress.log
}

# Usage
transfer_with_progress "/local/large-file.zip" "user@remote-host:/remote/path/"
```

---

## Additional Resources

- [rsync Manual](https://linux.die.net/man/1/rsync)
- [OpenSSH Documentation](https://www.openssh.com/manual.html)
- [WinSCP Documentation](https://winscp.net/eng/docs/start)
- [SSH Config File Examples](https://www.ssh.com/academy/ssh/config)

---

## Related KB Articles

- [Visual Studio Code Remote SSH](visual_studio_code_remote_ssh.md)
