# Install ArcGIS Server on Ubuntu

## Prerequisites

### Update System Packages

Start by updating your package lists and upgrading existing packages to their latest versions if this has not already been done.

``` bash
sudo apt update
sudo apt upgrade -y
```

### Firewall Configuration

Ensure that the necessary firewall ports are open for ArcGIS Server to function properly. The following opens ports 6443 for ArcGIS Server and 22 for SSH access.

``` bash
sudo ufw allow 22,6443/tcp
sudo ufw enable
sudo ufw status
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

- `/opt/arcgis/server` — Application binaries (read-only)
- `/var/opt/arcgis/server` — Variable data
- `/etc/opt/arcgis/server` — Configuration files (read-only for non-root users in the `arcgis` group)

``` bash
sudo mkdir -p /opt/arcgis/server
sudo chown arcgis:arcgis /opt/arcgis/server
sudo chmod 750 /opt/arcgis/server
sudo mkdir -p /var/opt/arcgis/server
sudo chown arcgis:arcgis /var/opt/arcgis
sudo chmod 750 /var/opt/arcgis
sudo mkdir -p /etc/opt/arcgis/server
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

### Localhost Hostname Resolution

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

!!! note "Why ArcGIS Server Needs This"

    ArcGIS Server uses the machine’s hostname when binding services, generating service URLs, validating tokens, and for inter‑node calls in a site. If your hostname resolves to loopback or the wrong NIC, you’ll see start‑up warnings, registration/federation issues, and health‑check failures.

## Install ArcGIS Server

### Copy and Unpack Installation Files

Copy the ArcGIS Server installer from the mounted Esri software share to a local directory, such as `/tmp`, and unpack it.

``` bash
cp /mnt/software/120_Final/ArcGIS_Server_Linux_*.tar.gz /tmp
tar xvf /tmp/ArcGIS_Server_Linux_*.tar.gz -C /tmp
```

Also, copy the license file to the local temporary directory.

``` bash
cp /mnt/software/Authorization_Files/Version12.0/ArcGIS_Server/Advanced/Server_Ent_Adv_AllExt.ecp /tmp
```

### Install ArcGIS Server

Now, run the ArcGIS Server installer as the `arcgis` user.

!!! note "Install as `arcgis`"

    If not the `arcgis` user, use `sudo -u arcgis -s` to switch to the `arcgis` user before running the installer.

``` bash
/tmp/ArcGISServer/Setup -m silent -l yes -a /tmp/Server_Ent_Adv_AllExt.ecp -d /opt -v
```

!!! note "Install Path"

    The install path, `/opt`, is the parent directory where ArcGIS Server will be installed. The actual installation directory will be `/opt/arcgis/server` since the installer automatically creates the `arcgis` and `server` subdirectories.

### Software Authorization

Reference: [Authorize ArcGIS Server Silently](https://enterprise.arcgis.com/en/server/latest/install/linux/silently-install-arcgis-server.htm#ESRI_SECTION1_49ED6300B7144B35BFF3AB749743EB5F)

The `-a` parameter used when installing above specifies the path to the authorization file copied earlier. If included in the installation command, the software will be authorized automatically during installation. 

However, if you need to authorize the software later, you can do so using the `authorizeSoftware` command after installation. This also works if you need to update the authorization later.

### Create ArcGIS Server Site

Reference: [Createsite Command Line Utility](https://enterprise.arcgis.com/en/server/latest/install/linux/silently-install-arcgis-server.htm#ESRI_SECTION1_EDF7ACDDAD2842B2BA61BEBF712D3EB8)

Use the `createsite` command to create the ArcGIS Server site.

``` bash
sudo -u arcgis /opt/arcgis/server/tools/createsite/createsite.sh -d /var/opt/arcgis/server -c /opt/arcgis/server/usr/config-store -u serveradmin -p P@ssw0rd
```

### Service Configuration

Reference: [Post-Installation Configuration](https://enterprise.arcgis.com/en/server/latest/install/linux/silently-install-arcgis-server.htm#ESRI_SECTION1_4B96E01A8AA344E3AD5E68A2DDBA8CA1)

Configure the ArcGIS Server service to start automatically when the system boots using systemd by copying the service file and enabling the service.

``` bash
sudo cp /opt/arcgis/server/framework/etc/scripts/arcgisserver.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/arcgisserver.service
sudo chmod 755 /etc/systemd/system/arcgisserver.service
sudo systemctl enable arcgisserver.service
sudo systemctl stop arcgisserver.service
sudo systemctl start arcgisserver.service
sudo systemctl status arcgisserver.service --no-pager
```

Now, you should be able to access the ArcGIS Server Manager at `https://server.domain.com:6443/arcgis/manager` using the `serveradmin` account created earlier.

## Install Certificates on ArcGIS Server (Optional)

Although optional, it is recommended to install SSL/TLS certificates on ArcGIS Server to secure communications. This involves obtaining a certificate from a trusted Certificate Authority (CA) and configuring ArcGIS Server to use it.

??? note "Get Esri Internal Domain Certificates"

    Domain certificates for internal Esri can be created and downloaded from [Esri CertiFactory](https://certifactory.esri.com/) either manually or automatically through the REST API.

    ### Download Certificates Using CURL

    Before getting the certificates, it is a lot easier to tell the current machine to trust the Esri internal PKI. You can do this by downloading and installing the Esri Root CA certificate.

    ``` bash
    sudo curl -L http://certifactory.esri.com/certs/esriroot.crt --output /usr/local/share/ca-certificates/esri_root_ca.crt
    sudo curl -L http://certifactory.esri.com/certs/caroot.crt --output /usr/local/share/ca-certificates/esri_issuing_ca.crt
    sudo update-ca-certificates
    ```

    Now, you can download the required certificates.

    - Server PFX
    
    ``` bash
    curl -o server.pfx https://certifactory.esri.com/api/servername.pfx?password=P@$$w0rd
    ```
  
    - CA (domain) Certificate

    ``` bash
    curl -o caroot.crt https://certifactory.esri.com/api/caroot.crt
    ```

Next, login to ArcGIS Server Admin (https://server.domain.com:6443/arcgis/admin) and click on `machines`. Select the name of the server you just configured. Then click on `sslcertificates`.

On this page, upload both the CA certificate and the server certificate. The name of the server certificate does not matter. Just make sure you remember it for the next step.

After uploading the certificates, go back to the machine page and click on `edit`. In the form, type the name of the server certificate you uploaded in the previous step into the `Web server SSL Certificate` field. In the example below, I named my certificate `server-cert` when uploading in the previous step, so this is the name used here as well.

![ArcGIS Server Web Server SSL Certificate](../../assets/arcgis_server_web_server_ssl_cert.png)

Click `Save and Restart` to apply the changes. ArcGIS Server will restart, and the new SSL/TLS certificate will be used for secure communications.

!!! note

    Typically, for the browser to recognize the certificate, the browser needs to be closed and reopened. Hence, close the current browser window and open a new one to access the ArcGIS Server Manager using the secure URL: `https://server.domain.com:6443/arcgis/manager`, and it should now show as secure.

## Configure ArcGIS Server Web Adaptor

Web Adapter configuration must be done on the web server where the web adaptor is installed. The following steps shall be performed on the web server where the ArcGIS Web Adaptor is installed.

!!! warning "Ensure Server Web Adaptor is Installed"

    If you have not already done so, install the ArcGIS Web Adaptor following the instructions in the [Install ArcGIS Web Adaptor on Ubuntu](01_install_arcgis_web_adapter_on_ubuntu.md) guide and deploy the WAR file for Server (`server.war`).

Since there is no GUI on the Linux server, use the command line interface to configure the web adaptor. Run the following command, replacing the placeholders with your actual values.

``` bash
/opt/arcgis/webadaptor12.0/java/tools/configurewebadaptor.sh -m server -w https://<webadapter.domain.com>/server/webadaptor -g arcgisserver.domain.com -u serveradmin -p P@ssw0rd
```

Reference: [Configure the ArcGIS Web Adaptor from the Command Line](https://enterprise.arcgis.com/en/web-adaptor/11.4/install/java-linux/configure-arcgis-web-adaptor-server.htm#GUID-5742E0C3-1C8D-4DA8-85AB-0385FB7C9E71)

## Verify the Installation

Now, you are ready to access the Server site. Open a web browser and navigate to `https://<webadapter.domain.com>/server`. Log in using the administrator account you created earlier to verify that the installation was successful.

## Federate the Server with Portal for ArcGIS

Reference: [Federate ArcGIS Server with Portal for ArcGIS](https://enterprise.arcgis.com/en/portal/latest/administer/windows/federate-arcgis-server-with-portal-for-arcgis.htm)

1. Log into the ArcGIS Portal (https://portal.domain.com/portal) using the administrator account created during the Portal installation. 

2. Navigate to `Organization` > `Settings` > `Servers` tab. Click on `Add Server` and select `ArcGIS Server`.

3. In the `Add ArcGIS Server` dialog, provide the following information follwing these patterns.
    
    - Service URL: `https://webadaptor.domain.com/server` (web adaptor URL)
    - Administration URL: `https://server.domain.com:6443/arcgis` (direct server URL)
    - Provide the `serveradmin` username and password created during the ArcGIS Server installation.

!!! note "Server Role"

    The server role cannot be set up yet, since the server has not been configured with a hosting data store. This will be done later after installing and configuring the ArcGIS Data Store.

