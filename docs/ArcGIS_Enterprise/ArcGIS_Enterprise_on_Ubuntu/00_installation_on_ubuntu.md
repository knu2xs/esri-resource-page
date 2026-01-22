# Installation on Ubuntu

The installation instructions for Ubuntu I have tested are based on Ubuntu 20.04 LTS (Focal Fossa). In general, I have tried to follow best practices for installing ArcGIS Enterprise on Linux. These include file system locations, user and group management, constrained permissions, and service configuration.

## Firewall Configuration

Ubuntu uses UFW (Uncomplicated Firewall) to manage firewall rules. During the installation process, I have configure UFW to allow the necessary ports for ArcGIS Enterprise components to communicate. For all instances, this starts with port 22 for SSH access, since this is how I log into the machines. Additional ports vary based on the requirements of the installed compoenets for ArcGIS Enterprise.

- ArcGIS Web Adaptor: 443 (8080 initially to ensure Tomcat is working)
- Portal for ArcGIS: 7443
- ArcGIS Server: 6443
- ArcGIS Data Store: 2443, 9820, 9840, 9876, 25672, 44369, 45671, 45672, 50432

### UFW Commands

Although there are a lot more commands, here are the basic UFW commands I use to manage the firewall on Ubuntu.

#### Allow

Add a port to the allowed list. For example, allow port 8080 for Tomcat.

``` bash
sudo ufw allow 22
```

#### Delete

Remove a port from the allowed list. For example, remove port 8080 after Tomcat is configured to use HTTPS on port 443.

``` bash
sudo ufw delete allow 8080
```

#### Enable

Initially, Ubuntu has UFW disabled. After configuring the necessary rules, enable UFW with the following command.

``` bash
sudo ufw enable
```

#### Status

Check the current status of UFW and the allowed ports.

``` bash
sudo ufw status
```

## Users, Groups and Permissions

Each ArcGIS Enterprise component runs under its own dedicated user and group. This enhances security by isolating each component and limiting access to only the necessary files and directories. Tomcat assets are owned by the `tomcat` user and group. All ArcGIS Enterprise components are owned by the `arcgis` user and group. This user is created during the installation process and is used to run the services for ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store.

Additionally, the installation directories for Tomcat and ArcGIS Enterprise components have restricted permissions to ensure only the respective users and groups have access. For example, the `/opt/tomcat` directory is owned by the `tomcat` user and group, while the `/opt/arcgis`, `/var/opt/arcgis`, and `/etc/opt/arcgis` directories are owned by the `arcgis` user and group. This ensures sensitive data and configuration files are protected from unauthorized access.

A common workflow for creating a new user and group for ArcGIS Enterprise, `arcgis` user and `arcgis` group. The following commands create the group, user, home directory, and set the appropriate ownership and permissions. The home directory is set to `/opt/arcgis` to keep all ArcGIS-related files in one location. I'm not sure if this is an antipattern, but for keeping the installation tidy, it works well.

``` bash
sudo groupadd arcgis
sudo useradd -s /bin/false -g arcgis -d /opt/arcgis arcgis
sudo mkdir /opt/arcgis
sudo chown arcgis:arcgis /opt/arcgis
sudo chmod 755 /opt/arcgis
```

### Bash Access

A best practice is to not allow direct bash access to service users. Therefore, both the `tomcat` and `arcgis` users are created without bash access. This can be done by specifying `/bin/false` as the shell when creating the user. 

If bash access is needed for troubleshooting, you can temporarily change the shell to the user, and revert it back when done. For example, to switch to the `arcgis` user.

``` bash
sudo -u arcgis -s
```

When finished, exit the user's shell back to the original user.

``` bash
exit
```

Also, if you simply want to run a command, such as checking a log file, you can use `sudo -u` to run the command as the respective user without changing the shell.

``` bash
sudo -u arcgis cat /var/opt/arcgis/server/logs/arcgisserver/system/2024-01-01T12-00-00_123456.log
```

## File System Locations

If being completely neuritic, I would break out the file system into more categories, but for simplicity, I organize installation resources into these three primary locations, optional software, variable data and configuration files.

### Optional Software: `/opt`

Optional software such as ArcGIS Enterprise components are installed in the `/opt` directory. This keeps them separate from the base operating system files and allows for easier management and upgrades. Tomcat is installed in `/opt/tomcat`. As a secondary heirarchy, all installed Esri software is located in `/opt/arcgis`. Hence, ArcGIS Server is installed in `/opt/arcgis/server`, Portal for ArcGIS in `/opt/arcgis/portal`, and ArcGIS Data Store in `/opt/arcgis/datastore`.

### Variable Data for Optional Software: `/var/opt`

Variable data, such as logs, caches, and other runtime data for the ArcGIS Enterprise components, are stored in the `/var/opt` directory. This ensures that variable data is kept separate from the application binaries and configuration files. Similar to the installation pattern, all Esri software is located in `/var/opt/arcgis`. For example, ArcGIS Server's variable data is located in `/var/opt/arcgis/server`, Portal for ArcGIS in `/var/opt/arcgis/portal`, and ArcGIS Data Store in `/var/opt/arcgis/datastore`.

### Configuration Files for Optional Software: `/etc/opt`

Configuration files for the ArcGIS Enterprise components are stored in the `/etc/opt` directory. This allows for easy management and backup of configuration settings. Similar to the above, all ArcGIS Enterprise software configuration files are located in `/etc/opt/arcgis`. For instance, ArcGIS Server's configuration files are in `/etc/opt/arcgis/server`, Portal for ArcGIS in `/etc/opt/arcgis/portal`, and ArcGIS Data Store in `/etc/opt/arcgis/datastore`.

## Service Configuration

Ubuntu uses `systemd` to manage services. Tomcat and the respective ArcGIS Enterprise components are all configured to start at boot as a `systemd` service. The service files are created during the installation process and are located in the `/etc/systemd/system` directory. Tomcat is configured to run under the `tomcat` user and group. Similarly, each ArcGIS service is configured to run under the `arcgis` user and group,. This ensures the respective services have the appropriate permissions to access the necessary files and directories.