# Install ArcGIS Web Adapter on Linux

References:

- [System Requirements](https://enterprise.arcgis.com/en/web-adaptor/latest/install/java-linux/arcgis-web-adaptor-system-requirements.htm)
- [Medium: Installing Apache Tomcat on Ubuntu 22.04](https://medium.com/@madhavarajas1997/installing-apache-tomcat-on-ubuntu-22-04-08c8eda52312)

## Install and Configure System Requrements

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

### Create Tomcat User

For security best practices, create a non-root user (`tomcat`) and group (`tomcat`) to run the Tomcat service. 

``` bash
sudo groupadd tomcat
sudo useradd -g tomcat -d /opt/tomcat tomcat
```

!!! note

    It is a best practice to configure the `tomcat` user without login capabilities for security reasons, but for ease of use, we will allow login in this guide. If truly following best practices, use the following command instead to create the `tomcat` user without login capabilities:

    ``` bash
    sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
    ```

Also, although optional, it is useful to set a user password and default shell (`bash`) as well. This enables remote login as the `tomcat` user if needed for troubleshooting or maintenance, and allows you to access the Tomcat installation directory from a remote VS Code session over SSH. This makes editing the configuration files much easier.

``` bash
sudo passwd tomcat
sudo usermod -s /bin/bash tomcat
```

Finally, if you want the same behavior (mostly bash coloring) as the current user (`linux` on Esri ECS instance), copy the current user's bash profile to the `tomcat` user.

``` bash
sudo cp ~/.bashrc /opt/tomcat/
sudo chown tomcat:tomcat /opt/tomcat/.bashrc
```

!!! note "Run as Tomcat User"

    You can switch to the `tomcat` user at any time using the following command:

    ``` bash
    sudo -u tomcat -s
    ```

    You can verify this by using the `whoami` command to ensure you are now working as the `tomcat` user.

### Authbind

To allow Tomcat to bind to ports below 1024 (like 80 and 443) without running as root, install and configure `authbind`.

``` bash
sudo apt install authbind -y
sudo touch /etc/authbind/byport/443
sudo chown tomcat:tomcat /etc/authbind/byport/443
sudo chmod 500 /etc/authbind/byport/443
```

### Tomcat Server

#### Download Apache Tomcat 10.1

Tomcat is not available in the default Ubuntu repositories, so you must download the binary distribution manually. 

1. Navigate to a temporary directory

``` bash
cd /tmp
``` 

2. Visit the official [Apache Tomcat 10 Software Downloads](https://www.google.com/url?sa=i&source=web&rct=j&url=https://tomcat.apache.org/download-10.cgi&ved=2ahUKEwij0qie14mSAxWEmGoFHQRYB84Qy_kOegQIDBAE&opi=89978449&cd&psig=AOvVaw10ehzpfYEwMvNo8KYnvwip&ust=1768433752574000) page to find the latest stable version and get the download link for the `*.tar.gz` file.

3. Use wget to download the package (replace the URL with the current version's link if a newer one is available).

``` bash
wget dlcdn.apache.org
```

4. Create the destination directory and extract the archive.

``` bash
sudo mkdir /opt/tomcat
sudo tar xvf apache-tomcat-*.tar.gz -C /opt/tomcat --strip-components=1
```

#### Configure Permissions

Change the owner and group of the entire `/opt/tomcat/` directory (and contents) to the `tomcat` user and `tomcat` group. This ensures the Tomcat service has proper permissions to read and write files within the installation directory.

``` bash
sudo chown -R tomcat:tomcat /opt/tomcat/
```

Next, set the appropriate permissions for the Tomcat binary files for the owner (user) on all files and directories recursively within `/opt/tomcat/bin`. This allows the Tomcat startup scripts to be executable by the owner user account (`tomcat`).

``` bash
sudo chmod -R u+x /opt/tomcat/bin
```

#### Create `systemd` Service File

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

    User=tomcat
    Group=tomcat

    Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
    Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
    Environment="CATALINA_HOME=/opt/tomcat"

    # Startup using authbind so can use port 443
    ExecStart=/usr/bin/authbind --deep /opt/tomcat/bin/startup.sh
    ExecStop=/opt/tomcat/bin/shutdown.sh

    RestartSec=10
    Restart=always

    [Install]
    WantedBy=multi-user.target
    ```

#### Start and Enable the Tomcat Service

Reload systemd to recognize the new service and start Tomcat.

!!! note

    If you are working as the `tomcat` user, you may have to go back to a user with `sudo` privelages. You can drop out of of the `tomcat` session by simply using the command `exit`.

``` bash
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat
```

Check the status of the service to ensure it is running correctly.

``` bash
sudo systemctl status tomcat
```

#### Adjust Firewall and Access Web Interface

References:

- [Ubuntu Server Documentation: Firewall](https://documentation.ubuntu.com/server/how-to/security/firewalls/)
- [Ubuntu Manuals: UFW8](https://manpages.ubuntu.com/manpages/focal/man8/ufw.8.html)
- [Ubuntu How-To: Firewalls](https://documentation.ubuntu.com/server/how-to/security/firewalls/)
- [Ubuntu Wiki: Uncomplicated Firewall](https://wiki.ubuntu.com/UncomplicatedFirewall)

If you are running a firewall (UFW is common on Ubuntu), allow traffic on port 8080, which is the default Tomcat port.

``` bash
sudo ufw allow 8080
sudo ufw allow 443
sudo ufw enable # if firewall is not already enabled
```

!!! note "Checking UFW Status"

    You can check the status of UFW and see the allowed ports by running:

    ``` bash
    sudo ufw status
    ```

You can now access the default Tomcat web interface by navigating to `http://<your_server>:8080` in your web browser.

![Tomcat Landing Page](../../assets/tomcat_landing_page.png)

#### Install Server Certificates

To install a PFX server certificate on Ubuntu for Tomcat, you need to upload the PFX file to the server and then configure Tomcat's file to point to the certificate file and specify the  keystore type. \[[1], [2]\]  

##### Upload the PFX Certificate to the Ubuntu Server

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


1. Log in to your Ubuntu server via SSH. 
2. Navigate to a secure directory within your Tomcat installation, or create one specifically for storing certificates. For example, you can create a `cert` directory under the Tomcat installation directory.

    ``` bash
    cd /opt/tomcat
    mkdir cert
    cd cert
    ```

3. Use a secure file transfer protocol (SCP or SFTP) client (like WinSCP, or the  command line tool) to upload your PFX file and the associated password file (`keystorePass.txt`, if provided by your CA) from your local machine to the server directory. \[[1]\]

4. If you are doing this as another user other than `tomcat`, change the ownership of the `cert` directory using the following command.

    ``` bash
    sudo chown -R tomcat:tomcat /opt/tomcat/cert
    ```

5. Set permissions for `cert` directory.

    ``` bash
    sudo chmod -R 750 /opt/tomcat/cert
    ```

##### Configure Tomcat for SSL/TLS with the PFX Certificate

Open the Tomcat `server.xml` configuration file in a text editor.

``` bash
sudo nano /opt/tomcat/conf/server.xml
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
               certificateKeystoreFile="cert/tomcat_fullchain.p12"
               certificateKeystoreType="PKCS12"
               certificateKeystorePassword="P@$$w0rd"
          />

     </SSLHostConfig>
     </Connector>
```

#### Enable Remote Access

If accessing the Tomcat web interface from another machine, which is the _only_ way to access it if you are installing on an instance without a graphical user interface, you first need to enable access from a machine other than `localhost` for the docs and admin pages.

In the Tomcat root directory, (`/opt/tomcat/`), installed applications are directories under the `webapps` folder. To enable access to the default installed applications in the directoriese `docs`, `manager` and `host-manager`, locate the configuration files for these applications in the `META-INF` subdirectory of each application. Within each of the `META-INF` directories, there is a `context.xml` file that contains a `<Valve>` element restricting access to `localhost` by default. To allow access from other machines, comment out the `<Valve>` element in both `context.xml` files.

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

Next, you need to set administrator username and password to access these applications. Open the `tomcat-users.xml` file in the `conf` directory.

``` bash
sudo nano /opt/tomcat/conf/tomcat-users.xml
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

Procure the installation files for the ArcGIS Web Adapter for Linux from your Esri software repository or download them from the Esri website.

Unpack the installer tarball. This example uses the version 12.0 installer; adjust the filename as necessary for other versions.

``` bash
tar xvf /tmp/Web_Adapter_for_ArcGIS_Linux_*.tar.gz -C /tmp
```

Run the setup script as the `arcgis` user.

??? note "Add `arcgis` User"

    If you haven't already done so, create the `arcgis` user and group that will own and run ArcGIS Web Adapter. This example creates the `arcgis` user with a home directory of `/opt/arcgis`, so everything related to ArcGIS software is contained within the `/opt/arcgis` directory.

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

Switch to the `arcgis` user and run the Web Adapter setup script in silent mode. Using the `-v` (verbose) flag provides detailed output during the installation process, so you can monitor the installation progress.

``` bash
sudo su - arcgis -s
/tmp/WebAdapter/Setup -m silent -l yes -d /opt/arcgis/webadaptor -v
```

Once installed, the web adapter can be configured to support specific ArcGIS Enterprise components (Portal for ArcGIS and ArcGIS Server) following installation and initial setup of the respective components.