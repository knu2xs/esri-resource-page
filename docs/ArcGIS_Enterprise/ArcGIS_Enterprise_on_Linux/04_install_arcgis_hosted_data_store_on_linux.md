# Install ArcGIS Hosted Data Store on Linux

## Open Required Firewall Ports

Ensure that the necessary firewall ports are open for ArcGIS Server to function properly. The following opens ports 6443 for ArcGIS Server and 22 for SSH access.

``` bash
sudo ufw allow 22
sudo ufw allow 2443
sudo ufw allow 9820
sudo ufw allow 9840
sudo ufw allow 9876
sudo ufw allow 25672
sudo ufw allow 44369
sudo ufw allow 45671
sudo ufw allow 45672
sudo ufw allow 50432
sudo ufw enable
sudo ufw status
```

Reference: [Ports used by ArcGIS Data Store](https://enterprise.arcgis.com/en/data-store/latest/install/windows/ports-used-by-arcgis-data-store.htm)

## Create ArcGIS User and Group

If you haven't already done so, create the `arcgis` user and group that will own and run ArcGIS Server. This example creates the `arcgis` user with a home directory of `/opt/arcgis`, so everything related to ArcGIS software is contained within the `/opt/arcgis` directory.

``` bash
sudo groupadd arcgis
sudo useradd -g arcgis -d /opt/arcgis arcgis
sudo mkdir /opt/arcgis
sudo chown arcgis:arcgis /opt/arcgis
sudo chmod 755 /opt/arcgis
```

Optionally, copy the bash profile to the new user's home directory.

``` bash
sudo cp ~/.bashrc /opt/arcgis/.bashrc
sudo chown arcgis:arcgis /opt/arcgis/.bashrc
```

## Set File Handle Limits

Set the lower file handle limits for the `arcgis` user by editing the `/etc/security/limits.conf` file.

``` bash
sudo nano /etc/security/limits.conf
```

Add the following lines to the end of the file:

``` bash
arcgis           soft    nofile          65536
arcgis           hard    nofile          unlimited
```

## Set `vm.swappiness` Value

Set the `vm.swappiness` value to 1 to reduce swapping on the server. This can be done by running the following command.

``` bash
sudo sysctl -w vm.swappiness=1
```

## Copy and Unpack Installation Files

Copy the ArcGIS Server installer from the mounted Esri software share to a local directory, such as `/tmp`, and unpack it.

``` bash
cp /mnt/software/120_Final/ArcGIS_DataStore_Linux_120_*.tar.gz /tmp
tar xvf /tmp/ArcGIS_DataStore_Linux_120*.tar.gz -C /tmp
```

## Extend the `/var` Volume (if necessary)

Check to ensure there is enough space on the `/var` volume to install ArcGIS Server. If there is not enough space, extend the logical volume and resize the filesystem.

First, check the available space on the `/var` volume.

``` bash
df -h /var
```

Only 20 GB is allocated in this example, so the volume needs to be extended. If there is not enough space, extend the logical volume. This example extends the `/var` volume by an additional 10 GB.

``` bash
sudo lvextend -L +10G /dev/vg_os/lv_var --resizefs
```

## Fix Hosts File

Ensure that the `/etc/hosts` file contains an entry for the server's hostname and IP address. Start by opening the `/etc/hosts` file in a text editor.

``` bash
sudo nano /etc/hosts
```

Next, search for a line similar to the following. In this case, my server's hostname is `PS029505.esri.com`.

``` bash
127.0.0.1 PS029505.esri.com PS029505 localhost
```

If you have a similar line, you can either update it to match your server's hostname or comment it out by adding a `#` at the beginning of the line, and add another line with just the localhost loopback entry as shown below.

``` bash
# 127.0.0.1 PS029505.esri.com PS029505 localhost
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
```

## Install ArcGIS Data Store

Reference: [Install ArcGIS Data Store](https://enterprise.arcgis.com/en/data-store/latest/install/linux/install-data-store.htm#GUID-3A9EDD7D-98B4-42EF-BAE2-29C9FC0FDC10)

Run the installer as the `arcgis` user.

``` bash
sudo -u arcgis /tmp/ArcGISDataStore_Linux/Setup -m silent -l yes -d /opt -f Relational,Object -v
```

## Configure ArcGIS Data Store to Start at Boot

Reference: [Post-Installation Configuration](https://enterprise.arcgis.com/en/server/latest/install/linux/silently-install-arcgis-server.htm#ESRI_SECTION1_4B96E01A8AA344E3AD5E68A2DDBA8CA1)

Configure the ArcGIS Server service to start automatically when the system boots using systemd by copying the service file and enabling the service.

``` bash
sudo cp /opt/arcgis/datastore/framework/etc/scripts/arcgisdatastore.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/arcgisdatastore.service
sudo chmod 755 /etc/systemd/system/arcgisdatastore.service
sudo systemctl enable arcgisdatastore.service
sudo systemctl stop arcgisdatastore.service
sudo systemctl start arcgisdatastore.service
sudo systemctl status arcgisdatastore.service --no-pager
```