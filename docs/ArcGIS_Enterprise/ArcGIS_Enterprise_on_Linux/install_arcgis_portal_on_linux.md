# Install ArcGIS Portal on Linux

## Set File Handle Limits

Set the lower file handle limits for the `arcgis` user by editing the `/etc/security/limits.conf` file.

``` bash
sudo nano /etc/security/limits.conf
```

Add the following lines to the end of the file:

``` bash
arcgis           soft    nofile          65535
arcgis           hard    nofile          unlimited
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

## Extend the `/opt` Volume (if necessary)

Check to ensure there is enogh space on the `/opt` volume to install Portal for ArcGIS. If there is not enough space, extend the logical volume and resize the filesystem.

First, check the available space on the `/opt` volume.

``` bash
df -h /opt
```

There needs to be at least 20 GB of free space to install Portal for ArcGIS. If there is not enough space, extend the logical volume.

``` bash
sudo lvextend -L +10G /dev/vg_os/lv_opt --resizefs
```

## Install Portal for ArcGIS

Now, run the Portal for ArcGIS installer as the `arcgis` user.

!!! warning

    If not the `arcgis` user, use `sudo su - arcgis` to switch to the `arcgis` user before running the installer.

``` bash
./Setup -m silent -l yes -d /opt/arcgis/portal -v
```

## Open Required Firewall Ports

Open the required firewall ports for Portal for ArcGIS.

``` bash
sudo ufw allow 7443
```

## Create Portal for ArcGIS Data Directory

Create the Portal for ArcGIS data directory and set the appropriate ownership and permissions.

``` bash
sudo mkdir -p /var/opt/arcgis/portal
sudo chown -R arcgis:arcgis /var/opt/arcgis
sudo chmod -R 755 /var/opt/arcgis
```

## Configure Portal for ArcGIS to Start at Boot

Configure the Portal for ArcGIS service to start automatically when the system boots using systemd by copying the service file and enabling the service.

``` bash
sudo cp /opt/arcgis/portal/framework/etc/arcgisportal.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/arcgisportal.service
sudo chmod 640 /etc/systemd/system/arcgisportal.service
sudo systemctl enable arcgisportal.service
sudo systemctl stop arcgisportal.service
sudo systemctl start arcgisportal.service
sudo systemctl status arcgisportal.service
```

## Create a Portal for ArcGIS Site

This has to be done through the Portal for ArcGIS web interface. Open a web browser and navigate to `https://<portal_hostname>:7443/portal/webadaptor`. Follow the prompts to create the initial site, specifying the data directory created in the previous step, making the content directory `/var/opt/arcgis/portal/content`, and setting the initial administrator account.

## Configure Portal for ArcGIS Web Adaptor

Web Adapter configuration must be done on the web server where the web adaptor is installed. The following steps shall be performed on the web server where the ArcGIS Web Adaptor is installed.

Move the `arcgis.war` file to the Tomcat webapps directory, and rename it to `portal.war`. When Tomcat restarts, it will deploy the web adaptor for Portal for ArcGIS as `https://<webserver.domain.com>/portal`.

``` bash
sudo mv /opt/tomcat/webapps/arcgis.war /opt/tomcat/webapps/portal.war
sudo chown tomcat:tomcat /opt/tomcat/webapps/portal.war
```

Restart the Tomcat service to deploy the web adaptor.

``` bash
sudo systemctl restart tomcat
```

Since there is no GUI on the Linux server, use the command line interface to configure the web adaptor. Run the following command, replacing the placeholders with your actual values.

``` bash
/opt/arcgis/webadaptor12.0/java/tools/configurewebadaptor.sh -m portal -w https://<webserver.domain.com>/portal/webadaptor -g portalserver.domain.com -u portaladmin -p P@ssw0rd
```

## Verify the Installation

Now, you are ready to access the Portal for ArcGIS site. Open a web browser and navigate to `https://<webserver.domain.com>/portal`. Log in using the administrator account you created earlier to verify that the installation was successful.