# Ubuntu Conventions and Best Practices for ArcGIS Enterprise

In general, I have tried to follow best practices for installing ArcGIS Enterprise on Linux and Ubuntu and take into account the unique requirements needed by ArcGIS Enterprise. Since Ubuntu, any generic software is managed using the `apt` package manager. Linux best practices explicitly applied include using a deny-by-default firewall, dedicated service users, and following Linux Filesystem Hierarchy Standard (FHS) conventions. Also, a unique consideration for ArcGIS Enterprise applied on all instances is ensuring file handle limits are set appropriately so that ArcGIS Enterprise components can function properly under load.

!!! note "Ubuntu Focal Fossa"

    The installation instructions for Ubuntu are based on Ubuntu 20.04 LTS (Focal Fossa).

## Package Management

Ubuntu uses the `apt` package manager to handle software installation, updates, and removal. The `apt` command simplifies package management by resolving dependencies and providing a user-friendly interface.

### Common `apt` Commands

| Command | Description |
|---------|-------------|
| `sudo apt update` | Update the package index to get the latest information about available packages |
| `sudo apt upgrade` | Upgrade all installed packages to their latest versions |
| `sudo apt install <package>` | Install a specific package |
| `sudo apt remove <package>` | Remove a specific package |
| `sudo apt autoremove` | Remove unnecessary packages that were automatically installed as dependencies |
| `sudo apt search <package>` | Search for a package in the repositories |
| `sudo apt show <package>` | Display detailed information about a specific package |

Commonly, I start by updating the package index and upgrading installed packages to ensure the system is up to date.

``` bash
sudo apt update
sudo apt upgrade -y
```

## Firewall Configuration

Reference: [UFW - Uncomplicated Firewall](https://help.ubuntu.com/community/UFW)

Ubuntu uses UFW (Uncomplicated Firewall) to manage firewall rules. UFW is deny-by-default, so only the ports explicitly allowed will be open.

During the installation process, I start by configuring UFW to allow SSH (for terminal access) andthe necessary ports for ArcGIS Enterprise components installed on the instance to communicate. For all instances, this starts with port 22 for SSH access, since this is how I log into the machines. Additional ports vary based on the requirements of the installed compoenets for ArcGIS Enterprise.

- ArcGIS Web Adaptor: 443 (8080 initially to ensure Tomcat is working)
- Portal for ArcGIS: 7443
- ArcGIS Server: 6443
- ArcGIS Data Store: 2443, 9820, 9840, 9876, 25672, 44369, 45671, 45672, 50432

### UFW Commands

Although there are a lot more commands, here are the basic UFW commands I use to manage the firewall on Ubuntu.

#### Allow

Add a port to the allowed list. For example, allow port 8080 for Tomcat.

``` bash
sudo ufw allow 8080
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

## Service Users

Reference: [systemd.exec - User/Group Execution](https://man7.org/linux/man-pages/man5/systemd.exec.5.html#USER/GROUP_IDENTITY)

Setting up dedicated users for running applications as services (**service users**) enhances security and ensures proper file permissions. Services run as dedicated user accounts, limiting access to only the necessary files and directories used by the applications.

Two user accounts are used in the installation of ArcGIS Enterprise on Ubuntu: `tomcat` and `arcgis`. Tomcat assets are owned by the `tomcat` user and group. The `tomcat` user is used to run the Tomcat service. Similarly, ArcGIS Enterprise assets are owned by the `arcgis` user and group, and all ArcGIS Enterprise services run as the `arcgis` user.

### Creating Users

Setting up a user and group for running applications is straightforward using the `useradd` command. For example, here is the commands to create the `arcgis` user and group.

!!! note "Disable Shell Access"

    For security reasons, it is a best practice to disable shell access for service users. Therefore, the `arcgis` user is created with the shell set to `/bin/false`, which prevents interactive login.

``` bash
sudo useradd -s /bin/false -m -U arcgis
```

- `-s /bin/false` — Disables shell login for the user, preventing interactive access
- `-m` — Creates the home directory `/home/arcgis`
- `-U` — Creates a group with the same name as the user
- `arcgis` — The username

### Running Commands as Service Users

There are times when it is necessary to run commands as these users for troubleshooting or maintenance purposes. In such cases, if you simply want to run a command, such as checking a log file in a directory only the service user has permissions to, you can use `sudo -u` to run the command as the respective user without changing the shell. 

This is generally safer and preferred for one-off commands. For example, to view an ArcGIS Server log file as the `arcgis` user.

``` bash
sudo -u arcgis cat /var/opt/arcgis/server/logs/arcgisserver/system/2024-01-01T12-00-00_123456.log
```

- `sudo -u arcgis` — Runs the following command as the `arcgis` user
- `cat` — Outputs the contents of a file to the terminal

### Bash Access for Service Users

If bash access is needed for troubleshooting, you can temporarily change the shell to the user, and revert it back when done. For example, to switch to the `arcgis` user.

``` bash
sudo -u arcgis -s
```

When finished, exit the user's shell back to the original user.

``` bash
exit
```

??? note "Enabling User Shell Access"

    It can be useful to allow bash access for a user, especially for connecting via VS Code for remote file editing. In this case, you can set the shell to `/bin/bash` when creating the user, or change it later using the `usermod` command. For example, to allow bash access for the `arcgis` user.

    ``` bash
    sudo usermod -s /bin/bash arcgis
    ```

    The user will need a password set to log in.

    ``` bash
    sudo passwd arcgis
    ```

    You may also want to copy the current user's bash profile to the new user's home directory for a better user experience.

    ``` bash
    sudo cp ~/.bashrc /home/arcgis/.bashrc
    sudo chown arcgis:arcgis /home/arcgis/.bashrc
    ```

    Once finished, for security reasons, it is recommended to revert the shell back to `/bin/false` to disable bash access.

    ``` bash
    sudo usermod -s /bin/false arcgis
    ```

    Also, for the sake of throughness, you can also remove the password to prevent login.

    ``` bash
    sudo passwd -d arcgis
    ```

## File System Locations

Reference: [Filesystem Hierarchy Standard](https://refspecs.linuxbase.org/FHS_3.0/fhs-3.0.html)

If being completely neuritic, I would break out the where to store resources in the file system into more categories, but for simplicity, I organize installation resources into these three primary locations, optional software, variable data and configuration files.

### Optional Software: `/opt`

Reference: [Filesystem Hierarchy Standard - /opt](https://refspecs.linuxbase.org/FHS_3.0/fhs-3.0.html#OPT)

Optional software such as ArcGIS Enterprise components are installed in the `/opt` directory. This keeps them separate from the base operating system files and allows for easier management and upgrades. Tomcat is installed in `/opt/tomcat`. As a secondary heirarchy, all installed Esri software is located in `/opt/arcgis`. Hence, ArcGIS Server is installed in `/opt/arcgis/server`, Portal for ArcGIS in `/opt/arcgis/portal`, and ArcGIS Data Store in `/opt/arcgis/datastore`.

### Variable Data for Optional Software: `/var/opt`

Reference: [Filesystem Hierarchy Standard - /var/opt](https://refspecs.linuxbase.org/FHS_3.0/fhs-3.0.html#varoptVariableDataForOpt)

Variable data, such as logs, caches, and other runtime data for the ArcGIS Enterprise components, are stored in the `/var/opt` directory. This ensures that variable data is kept separate from the application binaries and configuration files. Similar to the installation pattern, all Esri software is located in `/var/opt/arcgis`. For example, ArcGIS Server's variable data is located in `/var/opt/arcgis/server`, Portal for ArcGIS in `/var/opt/arcgis/portal`, and ArcGIS Data Store in `/var/opt/arcgis/datastore`.

### Configuration Files for Optional Software: `/etc/opt`

Reference: [Filesystem Hierarchy Standard - /etc/opt](https://refspecs.linuxbase.org/FHS_3.0/fhs-3.0.html#etcoptConfigurationFilesForOpt)

Configuration files for the ArcGIS Enterprise components are stored in the `/etc/opt` directory. This allows for easy management and backup of configuration settings. Similar to the above, all ArcGIS Enterprise software configuration files are located in `/etc/opt/arcgis`. For instance, ArcGIS Server's configuration files are in `/etc/opt/arcgis/server`, Portal for ArcGIS in `/etc/opt/arcgis/portal`, and ArcGIS Data Store in `/etc/opt/arcgis/datastore`.

### Creating Directories and Setting Permissions

When creating these directories, ensure they are owned by the appropriate user and group, with restricted permissions to enhance security. For example, to create the installation directory for ArcGIS Server and set the correct ownership and permissions, you can use the following commands:

``` bash
sudo mkdir -p /opt/arcgis/server
sudo chown -R arcgis:arcgis /opt/arcgis
sudo chmod -R 755 /opt/arcgis
```

- `mkdir -p` — Creates the directory and any necessary parent directories
- `chown -R arcgis:arcgis` — Recursively sets the owner and group to `arcgis`
- `chmod -R 755` — Recursively sets permissions (owner: read/write/execute, group and others: read/execute)

Similarly, create the variable data and configuration directories with the appropriate ownership and permissions.

``` bash
sudo mkdir -p /var/opt/arcgis/server
sudo chown -R arcgis:arcgis /var/opt/arcgis
sudo chmod -R 755 /var/opt/arcgis
sudo mkdir -p /etc/opt/arcgis/server
sudo chown -R arcgis:arcgis /etc/opt/arcgis
sudo chmod -R 755 /etc/opt/arcgis
```

## Service Configuration

Ubuntu uses `systemd` as its init system to manage services, processes, and system state. Services are defined using unit files, which describe how a service should behave, including dependencies, execution order, and restart policies. `systemd` provides a standardized way to start, stop, restart, and monitor services on the system using commands.

### Key Concepts

- **Unit Files**: Configuration files that define how a service operates. They specify the executable, user context, environment variables, and dependencies.
- **Service States**: Services can be `active`, `inactive`, `failed`, or `activating`. Use `systemctl status` to check the current state.
- **Boot Integration**: Services can be `enabled` to start automatically at boot or `disabled` to require manual startup.

### Unit Files

Service unit files are located in `/etc/systemd/system`. Tomcat and the respective ArcGIS Enterprise components are all configured to start at boot as `systemd` services. The service files are either explicitly created (Tomcat) or copied from installation resources (ArcGIS Enterprise components), and subsequently enabled during a manual step in the installation process.

#### User Context

Each service is configured to run under its respective user account. This ensures services have the appropriate permissions to access the necessary files and directories while maintaining security isolation by not running as the root user. 

For instance, Tomcat is configured to run under the `tomcat` user and group. Similarly, each ArcGIS service is configured to run under the `arcgis` user and group.

This is specified in the service unit files using the `User=` and `Group=` directives. For example, here is a snippet from a hypothetical ArcGIS Server service file (the real file is _much_ longer and more complex).

``` ini
[Service]
User=arcgis
Group=arcgis
ExecStart=/opt/arcgis/server/start-server.sh
ExecStop=/opt/arcgis/server/stop-server.sh
Restart=on-failure
```

Files located in `/etc/systemd/system` must be owned by the root user and have appropriate permissions to ensure system security. Files should typically have `644` permissions (readable by all users, writable only by root) to prevent unauthorized modifications. These files can be managed using the `systemctl` command. 

For example, this is how the ArcGIS Server service file can be copied with correct ownership and permissions set to create the `arcgisserver.service` service.

``` bash
sudo cp /opt/arcgis/server/framework/etc/scripts/arcgisserver.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/arcgisserver.service
sudo chmod 644 /etc/systemd/system/arcgisserver.service
```

### Common `systemctl` Commands

Once a service file is in place, the following `systemctl` commands are used to manage services.

| Command | Description |
|---------|-------------|
| `sudo systemctl start <service>` | Start a service |
| `sudo systemctl stop <service>` | Stop a service |
| `sudo systemctl restart <service>` | Restart a service |
| `sudo systemctl status <service>` | Check service status |
| `sudo systemctl enable <service>` | Enable service to start at boot |
| `sudo systemctl disable <service>` | Disable service from starting at boot |
| `sudo systemctl daemon-reload` | Reload unit files after changes |

After copying the service file for ArcGIS Server, you would enable and start the service with the following commands.

``` bash
sudo systemctl daemon-reload
sudo systemctl enable arcgisserver.service
sudo systemctl start arcgisserver.service
```

Funally, check the status of the service to ensure it is running correctly.

``` bash
sudo systemctl status arcgisserver.service --no-pager
```

The status will either be `active (running)` if everything is functioning properly, or `failed` if there are issues that need to be addressed. Service states can be one of the following: `active`, `inactive`, `failed`, or `activating`.

## File Handle Limits

File handle limits define the maximum number of files, sockets, and other I/O resources that a process can have open simultaneously.

**Resources that consume file handles:**

- **Network connections** - Each client connection to ArcGIS services uses a file handle
- **Log files** - Server logs, access logs, and diagnostic files require open handles
- **Database connections** - Connections to geodatabases and data stores consume handles
- **Cached files** - Map tiles, scene layers, and other cached content need file handles

**Why this matters for the arcgis user** - The primary service account running ArcGIS Enterprise  components requires elevated limits to handle multiple concurrent service requests, data connections, and caching operations detailed below.

**Consequences of insufficient limits:**

- "Too many open files" errors
- Failed service requests
- Database connection failures
- Degraded system performance under load
- Service instability and crashes

### Why File Handle Limits Matter for ArcGIS Enterprise
File handle limits (also known as file descriptor limits) define the maximum number of files, sockets, and other I/O resources that a process can have open simultaneously. Each network connection, log file, database connection, and cached file consumes a file handle.

**Why ArcGIS Enterprise components require increased limits:**

**Portal for ArcGIS:**

- Maintains numerous concurrent connections for user sessions
- Handles multiple REST API requests simultaneously
- Manages connections to federated servers and data stores
- Requires handles for content indexing and caching operations

**ArcGIS Server:**

- Opens connections for each map service request
- Maintains database connections for geodatabase access
- Handles concurrent client connections (web, desktop, mobile)
- Manages log files, SOC processes, and temporary data files

**ArcGIS Data Store:**

- Manages persistent database connections for relational/tile cache stores
- Handles replication connections between primary and standby machines
- Maintains connections for spatiotemporal big data store nodes
- Requires handles for data indexing and backup operations

### Recommended File Handle Limits

Default system limits (typically 1024) are often insufficient for production deployments, leading to "too many open files" errors, failed connections, and service instability. For Portal for ArcGIS, ArcGIS Server, and ArcGIS Data Store, it is recommended to set the file handle limits for the `arcgis` user to at least 65,535 to ensure optimal performance. This can be done by editing the `/etc/security/limits.conf` file and adding the following lines:

``` bash
arcgis           soft    nofile          65536
arcgis           hard    nofile          unlimited
```

It also is possible to set the file handle limits using a separate file in the `/etc/security/limits.d/` directory. For example, create a file named `arcgis.conf` with the following content:

``` bash
sudo nano /etc/security/limits.d/arcgis.conf
```
``` bash
arcgis           soft    nofile          65536
arcgis           hard    nofile          unlimited
```

This can be done with a one-liner command as well:

``` bash
echo -e "arcgis\tsoft\tnofile\t65536\narcgis\thard\tnofile\tunlimited" | sudo tee /etc/security/limits.d/arcgis.conf
```

## Summary

All the above considerations help ensure a secure, stable, and efficient installation of ArcGIS Enterprise on Ubuntu. By following best practices for firewall configuration, service user management, file system organization, service configuration with `systemd`, and setting appropriate file handle limits, you can create a robust environment for running ArcGIS Enterprise components effectively.

Each of the successive documentation files in this series will build upon these foundational practices to guide you through the installation and configuration of each ArcGIS Enterprise component on Ubuntu.
