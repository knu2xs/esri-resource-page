# Accessing Esri Software on Ubuntu


## Install CIFS Utilities

Install the CIFS utilities package to enable mounting SMB/CIFS shares.

``` bash
sudo apt install cifs-utils -y
```

## Create Credentials File

Create a file to store your SMB credentials securely.

``` bash
sudo nano /etc/smb-credentials-esri
```

Put the following content in the file, replacing `USERNAME` and `YOUR_AVWORLD_PASSWORD` with your actual credentials:

``` bash
username=USERNAME
password=YOUR_AVWORLD_PASSWORD
domain=AVWORLD
```

## Restrict Credentials File Permissions

Set the permissions on the credentials file to ensure that only the root user can read it.

``` bash
sudo chmod 600 /etc/smb-credentials-esri
```

## Create Mount Point

Create a directory where the network share will be mounted.

``` bash
sudo mkdir /mnt/software
```

## Mount Using CIFS

Mount the Esri software share using the CIFS protocol.

``` bash
sudo mount -t cifs -o credentials=/etc/smb-credentials-esri,vers=2.0 //red-inf-dct-p01.esri.com/software/Esri/Released /mnt/software
```

## Persistence Across Reboots (Optional)

To make the mount persistent across reboots, add an entry to the `/etc/fstab` file.

``` bash
sudo nano /etc/fstab
```

Add the following line to the end of the file:

``` bash
//red-inf-dct-p01.esri.com/software/Esri/Released /mnt/software cifs credentials=/etc/smb-credentials-esri,vers=2.0
```

Save and close the file. The next time you reboot your system, the share will be mounted automatically.
