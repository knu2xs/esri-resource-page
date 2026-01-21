# Install ArcGIS Portal on Linux

## Set File Handle Limits

Set the lower file handle limits for the `arcgis` user by editing the `/etc/security/limits.conf` file.

``` bash
sudo nano /etc/security/limits.conf
```

Add the following lines to the end of the file:

``` bash
arcgis soft nofile 65535
```

## Create the `arcgis` User and Group

If you haven't already done so, create the `arcgis` user and group that will own and run Portal for ArcGIS. This example creates the `arcgis` user with a home directory of `/opt/arcgis`, so everything related to ArcGIS software is contained within the `/opt/arcgis` directory.

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

## Copy and Unpack the Installer

Copy the Portal for ArcGIS installer from the mounted Esri software share to a local directory, such as `/tmp`, and unpack it.

``` bash
cp /mnt/software/120_Final/Portal_for_ArcGIS_Linux_120_197821.tar.gz /tmp
```

Unpack the installer tarball. This example uses the version 12.0 installer; adjust the filename as necessary for other versions.

``` bash
tar xvf /tmp/Portal_for_ArcGIS_Linux_120_197821.tar.gz -C /tmp
```

``` bash
./Setup -m console -l yes -d /opt/arcgis/portal -v
```