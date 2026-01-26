# Install ArcGIS Portal on Ubuntu

References: 

- [System Requirements](https://enterprise.arcgis.com/en/web-adaptor/latest/install/java-linux/arcgis-web-adaptor-system-requirements.htm)
- [Install ArcGIS Portal on Linux](https://enterprise.arcgis.com/en/web-adaptor/latest/install/java-linux/welcome-arcgis-web-adaptor-install-guide.htm)

## Prerequisites

### Update System Packages

Start by updating your package lists and upgrading existing packages to their latest versions if this has not already been done.

``` bash
sudo apt update
sudo apt upgrade -y
```

### Firewall Configuration

Open the required firewall ports for Portal for ArcGIS.

``` bash
sudo ufw allow 7443
```

### Service User

If you haven't already done so, create the `arcgis` user and group that will own and run Portal for ArcGIS.

``` bash
sudo useradd -s /bin/false -m -U arcgis
```

- `-s /bin/false` — Disables shell login for the user, preventing interactive access
- `-m` — Creates the home directory `/home/arcgis`
- `-U` — Creates a group with the same name as the user
- `arcgis` — The username

### Create the Installation Directories

Create the installation directory for ArcGIS Enterprise software following the [Filesystem Hierarchy Standard](https://refspecs.linuxbase.org/FHS_3.0/fhs-3.0.html#optOptionalApplicationSoftwarePackages) and set ownership and permissions for the `arcgis` user.

Based on FHS, application software should be installed in `/opt`, variable data in `/var/opt`, and configuration files in `/etc/opt`. Following this standard, the directories for Portal will be the following:

- `/opt/arcgis/portal` — Application binaries (read-only)
- `/var/opt/arcgis/portal` — Variable data
- `/var/opt/arcgis/portal/content` — Content directory for Portal data
- `/etc/opt/arcgis/portal` — Configuration files (read-only for non-root users in the `arcgis` group)

``` bash
sudo mkdir -p /opt/arcgis/portal
sudo chown arcgis:arcgis /opt/arcgis/portal
sudo chmod 750 /opt/arcgis/portal
sudo mkdir -p /var/opt/arcgis/portal/content
sudo chown arcgis:arcgis /var/opt/arcgis
sudo chmod 750 /var/opt/arcgis
sudo mkdir -p /etc/opt/arcgis/portal
sudo chown root:arcgis /etc/opt/arcgis
sudo chmod 750 /etc/opt/arcgis
```

#### Extend the Volumes (if necessary)

Check to ensure there is enogh space on the `/opt` volume to install Portal for ArcGIS. If there is not enough space, extend the logical volume and resize the filesystem.

First, check the available space on the `/opt` volume.

``` bash
df -h /opt
```

There needs to be at least 20 GB of free space to install Portal for ArcGIS. If there is not enough space, extend the logical volume. When installing, I discovered only 20GB is allocated by default, so I extended it by an additional 10GB to have enough capacity.

``` bash
sudo lvextend -L +10G /opt --resizefs
```

Since we are going to be using the `/var` volume for Portal data, also check the available space on the `/var` volume.

``` bash
df -h /var
``` 

There should to be at least 50 GB of free space on the `/var` volume to accommodate Portal data. If there is not enough space, extend the logical volume and resize the filesystem.

``` bash
sudo lvextend -L +20G /var --resizefs
```

### Set File Handle Limits

Set the file handle limits for the `arcgis` user to ensure Portal for ArcGIS can handle multiple concurrent connections, REST API requests, and caching operations. Create a dedicated configuration file in `/etc/security/limits.d/` to set these limits:

``` bash
echo -e "arcgis\tsoft\tnofile\t65536\narcgis\thard\tnofile\tunlimited" | sudo tee /etc/security/limits.d/arcgis.conf
```

Alternatively, you can create the file manually:

``` bash
sudo nano /etc/security/limits.d/arcgis.conf
```

Add the following lines:

``` bash
arcgis           soft    nofile          65536
arcgis           hard    nofile          unlimited
```

## Install Portal for ArcGIS

### Copy and Unpack the Installer

Copy the Portal for ArcGIS installer to `/tmp`, and unpack it.

``` bash
cp /mnt/software/120_Final/Portal_for_ArcGIS_Linux_*.tar.gz /tmp
```

Unpack the installer tarball.

``` bash
tar xvf /tmp/Portal_for_ArcGIS_Linux_*.tar.gz -C /tmp
```

### Install Portal for ArcGIS

Run the Portal for ArcGIS installer as the `arcgis` user. Use `sudo -u arcgis` to run the command as the `arcgis` user without changing the shell:

``` bash
sudo -u arcgis /tmp/PortalforArcGIS/Setup -m silent -l yes -d /opt/arcgis/portal -v
```

- `sudo -u arcgis` — Runs the following command as the `arcgis` user
- `-m silent` — Runs the installer in silent mode
- `-l yes` — Accepts the license agreement
- `-d /opt/arcgis/portal` — Specifies the installation directory
- `-v` — Enables verbose output

### Service Configuration

Configure the Portal for ArcGIS service to start automatically when the system boots using `systemd`.

Start by copying the service file provided by the installer to `/etc/systemd/system/`.

``` bash
sudo cp /opt/arcgis/portal/framework/etc/arcgisportal.service /etc/systemd/system/
```

Next, check to ensure the unit file will run as the `arcgis` user. Open the service file in a text editor.

``` bash
sudo nano /etc/systemd/system/arcgisportal.service
```

Ensure the following lines are present in the `[Service]` section:

``` ini
User=arcgis
Group=arcgis
```

Now, set the correct ownership and permissions on the unit file.

``` bash
sudo chown root:root /etc/systemd/system/arcgisportal.service
sudo chmod 644 /etc/systemd/system/arcgisportal.service
```

Reload the systemd daemon to recognize the new service file. Then, enable and start the service.

``` bash
sudo systemctl daemon-reload
sudo systemctl enable arcgisportal.service
sudo systemctl start arcgisportal.service
```

Verify the service is running correctly:

``` bash
sudo systemctl status arcgisportal.service --no-pager
```

The status will either be `active (running)` if everything is functioning properly, or `failed` if there are issues that need to be addressed.

## Create the Portal for ArcGIS Site

This has to be done through the Portal for ArcGIS web interface. There is not a scrip to perform this stop. 

Open a web browser and navigate to `https://<portal_hostname>:7443/portal/webadaptor`. Follow the prompts to create the initial site, making the content directory `/var/opt/arcgis/portal/content`, and setting credentials for the initial administrator account.

## Configure Portal for ArcGIS Web Adaptor

Web Adapter configuration must be done on the web server where the web adaptor is installed. The following steps shall be performed on the web server where the ArcGIS Web Adaptor is installed.

!!! warning "Ensure Portal Web Adaptor is Installed"

    If you have not already done so, install the ArcGIS Web Adaptor following the instructions in the [Install ArcGIS Web Adaptor on Ubuntu](01_install_arcgis_web_adapter_on_ubuntu.md) guide and deploy the WAR file for Portal (`portal.war`).

Since there is no GUI on the Linux server, use the command line interface to configure the web adaptor. Run the following command on the web server where the ArcGIS Web Adaptor is installed, replacing the placeholders with your actual values.

``` bash
/opt/arcgis/webadaptor12.0/java/tools/configurewebadaptor.sh -m portal -w https://<webserver.domain.com>/portal/webadaptor -g portalserver.domain.com -u portaladmin -p P@ssw0rd
```

## Create Portal Site

Next, we need to create the ArcGIS Portal site using the command line interface.

??? tip "User Type IDs"

    The following user type IDs are available in Portal for ArcGIS if available in your license, and can be used for the `-ut` parameter when creating the portal site:

    | User Type | ID |
    |-----------|----|
    | Viewer | viewerUT |
    | Data Editor | dataEditorUT |
    | Creator | creatorUT |
    | GIS Professional | gisProfessionalUT |
    | Publisher | publisherUT |
    | Administrator | administratorUT |

    Getting user types available in your license can be determined by running the following command:

    ``` bash
    /opt/arcgis/portal/tools/listusertypes.sh
    ```

 Run the following command on the Portal server, replacing the placeholders with your actual values. The content directory is set to `/var/opt/arcgis/portal/content` based on the best practices for where the content directory should be located, in `/var/opt` since containing variable data for optional software.

``` bash
/opt/arcgis/portal/tools/createportalsite.sh \
    -fn Admin \
    -ln Hefe \
    -u portaladmin \
    -p P@ssw0rd \
    -e nobody@nowhere.com \
    -qi 1 \
    -qa Metropolis \
    -d /var/opt/arcgis/portal/content \
    -lf /tmp/*.ecp \
    -ut creatorUT \
```

!!! note "Create Site Parameters"

    Parameters for the `createportalsite.sh` script:

    | Parameter | Description |
    |-----------|-------------|
    | `-fn`, `--firstname <arg>` | The first name for an account with administrative privileges using which you want to configure the portal. |
    | `-ln`, `--lastname <arg>` | The last name for an account with administrative privileges using which you want to configure the portal. |
    | `-u`, `--username <arg>` | The user name of an account with administrative rights to the portal. Normally, you will use the primary portal administrator account for creating the portal. |
    | `-p`, `--password <arg>` | The password of the account you specified for the username parameter. Normally, you will use the primary portal administrator account for creating the portal. |
    | `-e`, `--email <arg>` | The email for an account with administrative privileges using which you want to configure the portal. |
    | `-qi`, `--questionIndex <arg>` | The index of the secret question to retrieve a forgotten password. See below for the list of questions. |
    | `-qa`, `--answer <arg>` | The answer to the secret question that you chose for the parameter `qi`. |
    | `-d`, `--contentDirectory <arg>` | The absolute path and the name of the Content Directory for storing data hosted on portal. By default, the portal content directory will be created locally. |
    | `-lf`, `--licenseFile <arg>` | The path to the portal license file. |
    | `-ut`, `--userTypeId <arg>` | The id of the user type for the Initial Administrator. |
    | `-f`, `--file <FILE>` | The properties file for the createportal utility. By default, the `createportal.properties` file can be found at `/<ArcGIS Server installation directory>/tools/createportal`. |
    | `-h`, `--help` | Display this tool help message and exit. |

    **Secret Question Index Values:**

    | Index | Question |
    |-------|----------|
    | 1 | What city were you born in? |
    | 2 | What was your high school mascot? |
    | 3 | What is your mother's maiden name? |
    | 4 | What was the make of your first car? |
    | 5 | What high school did you go to? |
    | 6 | What is the last name of your best friend? |
    | 7 | What is the middle name of your youngest sibling? |
    | 8 | What is the name of the street on which you grew up? |
    | 9 | What is the name of your favorite fictional character? |
    | 10 | What is the name of your favorite pet? |
    | 11 | What is the name of your favorite restaurant? |
    | 12 | What is the title of your favorite book? |
    | 13 | What is your dream job? |
    | 14 | Where did you go on your first date? |

