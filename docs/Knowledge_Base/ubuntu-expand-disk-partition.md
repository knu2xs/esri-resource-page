# Expanding Disk Partitions in Ubuntu VMs

## Overview

When you increase the disk size of a virtual machine (e.g., in VMware, Azure, AWS, or other hypervisors), the underlying storage is expanded but the partition table and filesystem don't automatically grow. This guide covers how to expand partitions and filesystems in Ubuntu to use the newly allocated space.

## Check Current Disk Usage

First, verify the current disk space and partition layout:

```bash
# Check filesystem usage
df -h

# Check block devices and partitions
lsblk

# Check partition details
sudo fdisk -l
```

You'll typically see that the disk size (e.g., `/dev/sda`) is larger than the partition size (e.g., `/dev/sda1`).

## Method 1: Using growpart and resize2fs (Recommended)

This is the simplest method, especially for cloud VMs.

### Step 1: Install cloud-guest-utils (if not present)

```bash
sudo apt update
sudo apt install cloud-guest-utils
```

### Step 2: Grow the partition

```bash
# Syntax: growpart <device> <partition-number>
sudo growpart /dev/sda 1

# For NVMe drives, use:
sudo growpart /dev/nvme0n1 1
```

### Step 3: Resize the filesystem

For **ext4** filesystems:
```bash
sudo resize2fs /dev/sda1

# For NVMe:
sudo resize2fs /dev/nvme0n1p1
```

For **xfs** filesystems:
```bash
sudo xfs_growfs /
```

### Step 4: Verify the changes

```bash
df -h
lsblk
```

## Method 2: Using parted (Alternative)

If `growpart` is not available, you can use `parted`:

### Step 1: Launch parted

```bash
sudo parted /dev/sda
```

### Step 2: Resize the partition

```
(parted) print free
(parted) resizepart 1 100%
(parted) quit
```

### Step 3: Resize the filesystem

```bash
sudo resize2fs /dev/sda1
```

## Method 3: Using fdisk (Manual Method)

**Warning**: This method requires deleting and recreating the partition. The data is preserved if done correctly, but proceed with caution.

### Step 1: Launch fdisk

```bash
sudo fdisk /dev/sda
```

### Step 2: Delete and recreate the partition

```
Command (m for help): p    # Print partition table (note start sector)
Command (m for help): d    # Delete partition
Partition number: 1

Command (m for help): n    # Create new partition
Partition type: p          # Primary
Partition number: 1
First sector: <press Enter to use default - must match old start sector>
Last sector: <press Enter to use all available space>

Command (m for help): p    # Verify the new partition
Command (m for help): w    # Write changes
```

### Step 3: Reboot or inform the kernel

```bash
# Option 1: Reboot
sudo reboot

# Option 2: Inform kernel without reboot
sudo partprobe /dev/sda
```

### Step 4: Resize the filesystem

```bash
sudo resize2fs /dev/sda1
```

## LVM (Logical Volume Manager) Partitions

If your Ubuntu installation uses LVM (common in server installations):

### Step 1: Grow the partition (if needed)

```bash
sudo growpart /dev/sda 3  # Typically partition 3 for LVM
```

### Step 2: Resize the physical volume

```bash
sudo pvresize /dev/sda3
```

### Step 3: Extend the logical volume

```bash
# Check volume group and logical volume names
sudo vgdisplay
sudo lvdisplay

# Extend the logical volume (example names)
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv

# Or specify a size
sudo lvextend -L +50G /dev/ubuntu-vg/ubuntu-lv
```

### Step 4: Resize the filesystem

```bash
# For ext4
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv

# For xfs
sudo xfs_growfs /
```

## Troubleshooting

### Partition still shows old size after resize

Reboot the system or run:
```bash
sudo partprobe /dev/sda
```

### "The partition is being used" error with parted

The partition is mounted. You'll need to:
1. Boot from a live USB/CD, or
2. Use `growpart` or `fdisk` method which work on mounted partitions

### Verify filesystem type

```bash
df -T
# or
lsblk -f
```

### Check for errors after resize

```bash
sudo e2fsck -f /dev/sda1  # For ext4 (must be unmounted)
sudo xfs_repair /dev/sda1  # For xfs (must be unmounted)
```

## Common Scenarios

### Azure VMs
1. Expand disk in Azure Portal
2. Wait for the operation to complete
3. SSH into the VM
4. Run `growpart` and `resize2fs`

### VMware VMs
1. Power off the VM
2. Expand disk in VMware settings
3. Power on the VM
4. Run `growpart` and `resize2fs`

### AWS EC2 Instances
1. Modify volume in EC2 Console
2. Wait for the volume to show "optimizing"
3. SSH into the instance
4. Run `growpart` and `resize2fs`

## Best Practices

- **Always backup** before resizing partitions
- Take a VM snapshot before making changes
- Verify free space with `df -h` before and after
- Check for errors after resizing
- Plan for downtime if a reboot is required

## Related Commands Reference

```bash
# Disk and partition information
lsblk -f              # List block devices with filesystem
df -h                 # Disk space usage
sudo fdisk -l         # List all partitions
sudo parted -l        # List partition tables

# LVM commands
sudo pvdisplay        # Physical volumes
sudo vgdisplay        # Volume groups
sudo lvdisplay        # Logical volumes

# Filesystem utilities
sudo resize2fs        # Resize ext2/ext3/ext4
sudo xfs_growfs       # Resize xfs
sudo e2fsck           # Check ext filesystems
```

## References

- [Ubuntu Community Help - Resizing Partitions](https://help.ubuntu.com/community/ResizePartition)
- [AWS EC2 - Extend a Linux file system](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/recognize-expanded-volume-linux.html)
- [Azure - Expand virtual hard disks on a Linux VM](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/expand-disks)
