# Install ArcGIS Web Adapter on Ubuntu with Tomcat

Reference: [System Requirements](https://enterprise.arcgis.com/en/web-adaptor/latest/install/java-linux/arcgis-web-adaptor-system-requirements.htm)

## Automated Installation Script

An automated installation script is available in the `scripts` directory that performs all the steps outlined in this guide. The script handles:

- System package updates
- Firewall configuration
- Java and Authbind installation
- Tomcat installation and configuration
- SSL/TLS certificate setup
- ArcGIS Web Adaptor installation
- WAR file deployment

### Prerequisites

Before running the script, ensure the following files are in `/tmp`:

- Tomcat tarball: `apache-tomcat-*.tar.gz`
- Web Adaptor tarball: `Web_Adapter_for_ArcGIS_Linux_*.tar.gz` or `ArcGIS_Web_Adaptor_*_Linux_*.tar.gz`
- PFX certificate: `*.p12` or `*.pfx`

### Usage

``` bash
# Run with password as argument
./install_web_adaptor.sh "your_pfx_password"

# Or run and be prompted for password
./install_web_adaptor.sh

# Or create config file
echo "PFX_PASSWORD=your_password_here" > /tmp/config.ini
./install_web_adaptor.sh
```

## Manual Installation Steps

The following sections provide step-by-step manual installation instructions.

## Update System Packages

Start by updating your package lists and upgrading existing packages to their latest versions if this has not already been done.

``` bash
sudo apt update
sudo apt upgrade -y
```

## Firewall Configuration

If UFW (Uncomplicated Firewall) is enabled on your Ubuntu system, you need to allow traffic on the ports that Tomcat will use. By default, Tomcat uses port 8080 for HTTP and port 443 will be configured for HTTPS to use with the ArcGIS Web Adaptor.

``` bash
sudo ufw allow 22,443,8080/tcp
sudo ufw enable
```

## Service User

Create a user and group named `web-services` that will own and run the Tomcat service.

``` bash
sudo useradd -s /bin/false -m -U web-services
```

## Install and Configure System Requirements

Reference: [ArcGIS Web Adaptor System Requirements](https://enterprise.arcgis.com/en/web-adaptor/latest/install/java-linux/arcgis-web-adaptor-system-requirements.htm)

### Java

- Install

Open your terminal and run the following commands to update your system's package list and install OpenJDK, the default Java development kit for Ubuntu.

``` bash
sudo apt update
sudo apt install openjdk-17-jdk -y
```

Verify the Java installation.

``` bash
java -version
```

### Authbind

To allow Tomcat to bind to ports below 1024 (like 80 and 443) without running as root, install and configure `authbind`.

``` bash
sudo apt install authbind -y
sudo touch /etc/authbind/byport/443
sudo chown web-services:web-services /etc/authbind/byport/443
sudo chmod 500 /etc/authbind/byport/443
```

### Tomcat Server

- [Medium: Installing Apache Tomcat on Ubuntu 22.04](https://medium.com/@madhavarajas1997/installing-apache-tomcat-on-ubuntu-22-04-08c8eda52312)

#### Download Apache Tomcat 10.1

Tomcat is not available in the default Ubuntu repositories, so you must download the binary distribution manually. 

1. Navigate to a temporary directory

``` bash
cd /tmp
``` 

2. Visit the official [Apache Tomcat 10 Software Downloads](https://tomcat.apache.org/download-10.cgi) page to find the latest stable version and get the download link for the `*.tar.gz` file.

3. Use wget to download the package (replace the URL with the current version's link).

``` bash
wget //dlcdn.apache.org/tomcat/tomcat-10/v<version>/bin/apache-tomcat-<version>.tar.gz
```

4. Create the destination directories and extract the archive. We use a FHS-compliant layout:
    - `/opt/tomcat` - Application binaries (read-only)
    - `/etc/opt/tomcat` - Configuration files
    - `/var/opt/tomcat` - Variable data (temp, work, webapps)
    - `/var/log/tomcat` - Log files (more in line with FHS standards than keeping logs in /var/opt)

``` bash
# Create directory structure
sudo mkdir -p /opt/tomcat
sudo mkdir -p /etc/opt/tomcat
sudo mkdir -p /var/opt/tomcat/{temp,work,webapps}
sudo mkdir -p /var/log/tomcat

# Extract Tomcat to /opt/tomcat
sudo tar xvf apache-tomcat-*.tar.gz -C /opt/tomcat --strip-components=1

# Move configuration files to /etc/opt/tomcat and create symlink
sudo rsync -av --remove-source-files /opt/tomcat/conf/ /etc/opt/tomcat/
sudo rmdir /opt/tomcat/conf
sudo ln -s /etc/opt/tomcat /opt/tomcat/conf

# Move any logfiles to /var/log/tomcat and create symlink
sudo rsync -av --remove-source-files /opt/tomcat/logs/ /var/log/tomcat/
sudo rmdir /opt/tomcat/logs
sudo ln -s /var/log/tomcat /opt/tomcat/logs

# move variable data directories to /var/opt/tomcat and create symlinks
sudo rsync -av --remove-source-files /opt/tomcat/temp/ /var/opt/tomcat/temp/
sudo rm -rf /opt/tomcat/temp
sudo ln -s /var/opt/tomcat/temp /opt/tomcat/temp

sudo rsync -av --remove-source-files /opt/tomcat/work/ /var/opt/tomcat/work/
sudo rm -rf /opt/tomcat/work
sudo ln -s /var/opt/tomcat/work /opt/tomcat/work

sudo rsync -av --remove-source-files /opt/tomcat/webapps/ /var/opt/tomcat/webapps/
sudo rm -rf /opt/tomcat/webapps
sudo ln -s /var/opt/tomcat/webapps /opt/tomcat/webapps
```

#### Configure Permissions

Set ownership and permissions for each directory according to its purpose:

- `/opt/tomcat` - Owned by root, readable by web-services (binaries should be read-only)
- `/etc/opt/tomcat` - Owned by root, readable by web-services (config files)
- `/var/opt/tomcat` - Owned by web-services (writable for logs, temp files, etc.)

``` bash
# Binary directory - root owns, web-services can read/execute
sudo chown -R root:web-services /opt/tomcat/
sudo chmod -R 750 /opt/tomcat/
sudo chmod -R u+x /opt/tomcat/bin

# Configuration directory - root owns, web-services can read
sudo chown -R root:web-services /etc/opt/tomcat/
sudo chmod -R 750 /etc/opt/tomcat/

# Variable data directory - web-services owns (needs write access)
sudo chown -R web-services:web-services /var/opt/tomcat/
sudo chmod -R 750 /var/opt/tomcat/

# Log directory - root owns and web-services can write; users can read but cannot modify logs
sudo chown -R root:web-services /var/log/tomcat/
sudo chmod -R 775 /var/log/tomcat/
```

#### Service Configuration

##### Create Systemd Unit File

To run Tomcat as a service that can be started and stopped easily, create a systemd unit file.

1. Create the service file using a text editor (like `nano`)

    ``` bash
    sudo nano /etc/systemd/system/tomcat.service
    ```

2. Populate the configuration file with the following.

    ``` ini
    [Unit]
    Description="Apache Tomcat Web Application Server"
    After=network.target

    [Service]
    Type=forking

    # although the service is started as root, it runs as the web-services user
    User=web-services
    Group=web-services

    # environment variables, where to find Java and Tomcat
    Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
    Environment="CATALINA_HOME=/opt/tomcat"
    Environment="CATALINA_BASE=/opt/tomcat"
    Environment="CATALINA_PID=/var/opt/tomcat/temp/tomcat.pid"
    Environment="CATALINA_TMPDIR=/var/opt/tomcat/temp"

    # Startup using authbind so can use port 443
    ExecStart=/usr/bin/authbind --deep /opt/tomcat/bin/startup.sh
    ExecStop=/opt/tomcat/bin/shutdown.sh

    RestartSec=10
    Restart=always

    [Install]
    WantedBy=multi-user.target
    ```

##### Start and Enable the Tomcat Service

Reload systemd to recognize the new service and start Tomcat.

``` bash
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat
```

Check the status of the service to ensure it is running correctly.

``` bash
sudo systemctl status tomcat --no-pager
```

You can now access the default Tomcat web interface by navigating to `http://<your_server>:8080` in your web browser.

![Tomcat Landing Page](../../assets/tomcat_landing_page.png)

#### Configure Tomcat for HTTPS with PFX Certificate

##### Create Certificate Directory

Create a directory and set permissions to store your SSL/TLS certificate files.

``` bash
sudo mkdir /etc/opt/tomcat/cert
sudo chown -R web-services:web-services /etc/opt/tomcat/cert
sudo chmod -R 750 /etc/opt/tomcat/cert
```

##### Move Your PFX Certificate to the Server

??? note "Esri Internal Certificates"

    For machines on the Esri internal network, you can get certificates for your machine name (`servername.esri.com`) and the domain (`esri.com`) root certificate from [https://certifactory.esri.com/certs/](https://certifactory.esri.com/certs/). If on a terminal linux machine (likely), you can [get the certificate through a REST request](https://certifactory.esri.com/api/), which is even easier, because then you have the certificate right on the machine.

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

    - Intermediate Certificate
    
    ``` bash
    curl -o esri_intermediate.crt http://esri_pki.esri.com/crl/Esri%20Issuing%20CA.crt
    ```

    - CA (domain) Certificate
    
    ``` bash
    curl -o caroot.crt https://certifactory.esri.com/api/caroot.crt
    ```

    Now, these need to be combined into a single PFX file.

    1. Extract server certificate and private key from the PFX:
    
        ``` bash
        openssl pkcs12 -in server.pfx -clcerts -nokeys -out server.crt
        openssl pkcs12 -in server.pfx -nocerts -nodes  -out server.key
        ```
    2. Normalize the intermediate and root certificates:
    
        ``` bash
        openssl x509 -inform DER -in esri_intermediate.crt -out esri_intermediate.pem 2>/dev/null \
        || cp esri_intermediate.crt esri_intermediate.pem


        openssl x509 -inform DER -in caroot.crt -out esri_root.pem 2>/dev/null \
        || cp caroot.crt esri_root.pem
        ```

    3. Build the Full Chain Bundle:
    
        ``` bash
        cat server.crt esri_intermediate.pem esri_root.pem > fullchain.crt
        ```

    4. Create the new PFX file:
    
        ``` bash
        openssl pkcs12 -export \
            -inkey server.key \
            -in server.crt \
            -certfile esri_intermediate.pem \
            -certfile esri_root.pem \
            -name tomcat \
            -out tomcat_fullchain.p12
        ```

    This creates a proper full-chain PFX file named `tomcat_fullchain.p12` that can be used directly in Tomcat.

Use a secure file transfer protocol (SCP or SFTP) client (like WinSCP, or the command line tool) to upload your PFX file from your local machine to `/tmp` on the server. Then move it to the certificate directory:

``` bash
sudo mv /tmp/tomcat_fullchain.p12 /etc/opt/tomcat/cert/
sudo chown root:web-services /etc/opt/tomcat/cert/tomcat_fullchain.p12
sudo chmod 640 /etc/opt/tomcat/cert/tomcat_fullchain.p12
```

#### Configure Tomcat for SSL/TLS with the PFX Certificate

Open the Tomcat `server.xml` configuration file in a text editor such as `nano`.

``` bash
sudo nano /etc/opt/tomcat/server.xml
```

Locate the existing `<Connector>` element for port 8443 (commented out by default) and modify it to use port 443 and the PFX keystore. Replace the existing `<Connector>` element with the following configuration, making sure to update the `certificateKeystorePassword` attribute with the actual password for your PFX file.

``` xml
     <Connector port="443"
               protocol="org.apache.coyote.http11.Http11NioProtocol"
               address="0.0.0.0"
               maxThreads="300"
               scheme="https"
               secure="true"
               SSLEnabled="true">

     <SSLHostConfig protocols="TLSv1.2,TLSv1.3"
                    honorCipherOrder="true">

          <Certificate
               certificateKeystoreFile="/etc/opt/tomcat/cert/tomcat_fullchain.p12"
               certificateKeystoreType="PKCS12"
               certificateKeystorePassword="P@$$w0rd"
          />

     </SSLHostConfig>
     </Connector>
```

### Enable Remote Access

If accessing the Tomcat web interface from another machine, which is the _only_ way to access it if you are installing on an instance without a graphical user interface, you first need to enable access from a machine other than `localhost` for the docs and admin pages.

Installed applications are directories under `/var/opt/tomcat/webapps`. To enable access to the default installed applications in the directories `docs`, `manager` and `host-manager`, locate the configuration files for these applications in the `META-INF` subdirectory of each application. 

Within each of the `META-INF` directories, there is a `context.xml` file that contains a `<Valve>` element restricting access to `localhost` by default. To allow access from other machines, comment out the `<Valve>` element in both `context.xml` files.

``` xml
<Valve className="org.apache.catalina.valves.RemoteAddrValve"
    allow="127\.\d+\.\d+\.\d+|::1|0:1"/>
```

Enclose this line in comment tags, like so:

``` xml
<!--
<Valve className="org.apache.catalina.valves.RemoteAddrValve"
    allow="127\.\d+\.\d+\.\d+|::1|0:1"/>
-->
```

Next, you need to set administrator username and password to access these applications. Open the `tomcat-users.xml` file in the configuration directory for editing using `nano`.

``` bash
sudo nano /etc/opt/tomcat/tomcat-users.xml
```

In this file locate the line with the comment `<!-- Define users and roles here -->` and add the following lines just below it, replacing `admin` and `password` with your desired username and password.

``` xml
<role rolename="manager-gui"/>
<role rolename="admin-gui"/>
<user username="admin" password="password" roles="manager-gui,admin-gui"/>
```

Restart the Tomcat service to apply the changes.

``` bash
sudo systemctl restart tomcat
```

Now, you can access the Tomcat Manager and Host Manager applications by navigating to the following URLs in your web browser:
- Manager App: `https://<your_server>/manager/html`
- Host Manager App: `https://<your_server>/host-manager/html`

When prompted, enter the administrator username and password you configured in the `tomcat-users.xml` file, and you should now have access to the Tomcat web interface over HTTPS.

## Install Web Adapter

Reference: [ArcGIS Web Adaptor Installation Guide](https://enterprise.arcgis.com/en/web-adaptor/latest/install/java-linux/welcome-arcgis-web-adaptor-install-guide.htm)

Procure the installation files for the ArcGIS Web Adapter for Linux from the Esri software repository or download them from the Esri customer care website. Place the file in `/tmp`.

``` bash
cp /mnt/software/120_Final/ArcGIS_Web_Adaptor_*_Linux_*.tar.gz /tmp
```

### Unpack the Installer

Unpack the installer tarball. This works with multiple file naming conventions.

``` bash
# Clean up any existing extraction
rm -rf /tmp/WebAdapter*

# Extract the tarball
tar xvf /tmp/*Web*Adaptor*Linux*.tar.gz -C /tmp
```

### Create the Installation Directory

Create the parent installation directory for ArcGIS products with proper ownership.

``` bash
sudo mkdir -p /opt/arcgis
sudo chown web-services:web-services /opt/arcgis
sudo chmod 750 /opt/arcgis
```

### Run the Installer

Run the setup script as the `web-services` user. The Setup file location may vary depending on the tarball structure.

!!! note "`web-services` User"

    The ArcGIS Web Adaptor for Java requires a Java application server to run, and will be copied from this location to the Tomcat web applications directory. In this installation, we are using Apache Tomcat, which we have configured to run under the `web-services` user. Therefore, we install the Web Adapter as the `web-services` user to ensure proper permissions and integration with the Tomcat server when deploying the Web Adapter application to Tomcat.

``` bash
# make Setup executable
chmod +x /tmp/WebAdaptor/Setup

# Run installer
sudo -u web-services /tmp/WebAdaptor/Setup -m silent -l yes -d /opt/arcgis -v
```

The installer places the Web Adapter files in a versioned directory (e.g., `/opt/arcgis/webadaptor12.0` for version 12.0). Create a symlink to make the installation directory consistent:

```bash
sudo -u web-services ln -sf $(sudo find /opt/arcgis -maxdepth 1 -type d -name 'webadaptor[0-9]*' | sort -V | tail -1) /opt/arcgis/webadaptor
```

Once installed, the web adapter can be configured to support specific ArcGIS Enterprise components (Portal for ArcGIS and ArcGIS Server) following installation as part of the configuration process for the necessary components.

## Install Portal and Server Web Adapters

Although we cannot configure them until the respective components are installed, we can install both the Portal for ArcGIS Web Adapter and the ArcGIS Server Web Adapter now. All we need to do is deploy the respective WAR files to the Tomcat web applications directory, and restart Tomcat.

``` bash
# Find and store the WAR file path
WAR_FILE=$(find /opt/arcgis/webadaptor -name "*.war" -type f | head -1)

# Deploy Portal and Server Web Adaptor WAR files
sudo mkdir -p /var/opt/tomcat/webapps/portal
sudo cp "$WAR_FILE" /var/opt/tomcat/webapps/portal.war

sudo mkdir -p /var/opt/tomcat/webapps/server
sudo cp "$WAR_FILE" /var/opt/tomcat/webapps/server.war

# Set proper ownership
sudo chown -R web-services:web-services /var/opt/tomcat/webapps/
```

Once the WAR files are copied, Tomcat will automatically deploy them. You can check the Tomcat logs to confirm successful deployment. The logs will indicate when the WAR files are deployed and if there are any issues during deployment.

``` bash
sudo tail -f /var/log/tomcat/catalina.out
```

!!! warning "Do Not Configure Web Adapters Yet"

    Do not attempt to configure the Web Adapters for Portal for ArcGIS or ArcGIS Server until those components are installed and running. The Web Adapter configuration process requires communication with the respective component, which will fail if the component is not yet installed. Attempting to configure the Web Adapters before installing Portal for ArcGIS and ArcGIS Server will result in errors and unsuccessful configuration.

## Conclusion

You have successfully installed and configured the ArcGIS Web Adapter on your Ubuntu system using Apache Tomcat as the application server. You can now proceed to install and configure Portal for ArcGIS and ArcGIS Server. When configuring these components, remember to configure the respective Web Adapters to ensure proper integration and functionality within your ArcGIS Enterprise deployment.
