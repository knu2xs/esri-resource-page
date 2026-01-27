# Accessing Esri Software from Ubuntu (Internal Esri Network)

## Install Required Packages

Install CIFS utilities and Kerberos packages to enable secure mounting of SMB/CIFS shares using Active Directory authentication.

``` bash
sudo apt install cifs-utils krb5-user keyutils -y
```

During the Kerberos installation, you will be prompted to configure the realm:

- **Default Kerberos realm**: `AVWORLD.ESRI.COM`
- **Kerberos servers for realm**: `AVWORLD.ESRI.COM`
- **Administrative server for realm**: `AVWORLD.ESRI.COM`

## Configure Kerberos (if needed)

If you need to manually configure Kerberos after installation, edit the configuration file:

``` bash
sudo nano /etc/krb5.conf
```

Ensure it includes the following configuration:

``` ini
[libdefaults]
    default_realm = AVWORLD.ESRI.COM
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    AVWORLD.ESRI.COM = {
        kdc = AVWORLD.ESRI.COM
        admin_server = AVWORLD.ESRI.COM
    }

[domain_realm]
    .esri.com = AVWORLD.ESRI.COM
    esri.com = AVWORLD.ESRI.COM
```

## Create Mount Point

Create a directory where the network share will be mounted.

``` bash
sudo mkdir -p /mnt/software
```

## Obtain Kerberos Ticket

Get a Kerberos ticket for your user (replace `USERNAME` with your Esri username):

``` bash
kinit USERNAME@AVWORLD.ESRI.COM
```

You will be prompted for your password. Verify the ticket:

``` bash
klist
```

## Mount Using Kerberos Authentication

Mount the Esri software share using Kerberos authentication (no password storage required):

``` bash
sudo mount -t cifs -o sec=krb5,vers=3.0,multiuser //red-inf-dct-p01.esri.com/software/Esri/Released /mnt/software
```

## Automatic Mount on Boot

To make the mount persistent across reboots with Kerberos authentication, add an entry to `/etc/fstab`:

``` bash
sudo nano /etc/fstab
```

Add the following line:

``` bash
//red-inf-dct-p01.esri.com/software/Esri/Released /mnt/software cifs sec=krb5,vers=3.0,multiuser,_netdev 0 0
```

The `_netdev` option ensures the mount waits for network availability before attempting to mount.

## Automatic Kerberos Ticket Renewal

To automatically renew your Kerberos ticket and keep the mount accessible, create a systemd service:

``` bash
sudo nano /etc/systemd/system/kerberos-renew.service
```

Add the following content (replace `USERNAME` with your Esri username):

``` ini
[Unit]
Description=Kerberos Ticket Renewal
After=network-online.target

[Service]
Type=simple
User=USERNAME
ExecStart=/usr/bin/kinit -R
Restart=on-failure
RestartSec=3600

[Install]
WantedBy=multi-user.target
```

Create a timer to run the renewal:

``` bash
sudo nano /etc/systemd/system/kerberos-renew.timer
```

Add the following:

``` ini
[Unit]
Description=Kerberos Ticket Renewal Timer

[Timer]
OnBootSec=15min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
```

Enable and start the timer:

``` bash
sudo systemctl enable kerberos-renew.timer
sudo systemctl start kerberos-renew.timer
```

## Verification

After reboot, verify the mount is working:

``` bash
df -h | grep software
ls /mnt/software
```
