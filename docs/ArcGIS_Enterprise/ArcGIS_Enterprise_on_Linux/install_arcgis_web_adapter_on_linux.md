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

### Tomcat Server

#### Create Tomcat User

For security best practices, create a non-root user and group to run the Tomcat service. 

``` bash
sudo groupadd tomcat
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
```

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
sudo tar xvf apache-tomcat-10.1.37.tar.gz -C /opt/tomcat --strip-components=1
```

#### Configure Permissions

Grant the newly created tomcat user ownership of the installation directory so it can access the files. 

``` bash
sudo chown -R tomcat:tomcat /opt/tomcat/
sudo chmod -R u+x /opt/tomcat/bin
```

#### Create systemd Service File

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
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
```

#### Start and Enable the Tomcat Service

Reload systemd to recognize the new service and start Tomcat.

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
sudo ufw allow 8080/tcp
sudo ufw enable # if firewall is not already enabled
```

You can now access the default Tomcat web interface by navigating to `http://<your_server>:8080` in your web browser.

![Tomcat Landing Page](../assets/tomcat_landing_page.png)

#### Install Server Certificates

??? note "Esri Internal Certificates"

    For machines on the Esri internal network, you can get certificates for your machine name (`servername.esri.com`) and the domain (`esri.com`) root certificate from [https://certifactory.esri.com/certs/](https://certifactory.esri.com/certs/). If on a terminal linux machine (likely), you can [get the certificate through a REST request](https://certifactory.esri.com/api/), which is even easier, because then you have the certificate right on the machine.

    The GET request structure for this is the following:

        - Single PFX: `https://certifactory.esri.com/api/servername.pfx?password=P@$$w0rd`
        - CA (domain) Certificate: `https://certifactory.esri.com/api/caroot.crt`

To install a PFX server certificate on Ubuntu for Tomcat, you need to upload the PFX file to the server and then configure Tomcat's  file to point to the certificate file and specify the  keystore type. [1, 2]  

##### Upload the PFX Certificate to the Ubuntu Server 

1. Log in to your Ubuntu server via SSH. 
2. Navigate to a secure directory within your Tomcat installation, for example, the  directory, or create a new  folder.

``` bash
cd /opt/tomcat # (or wherever your Tomcat is installed)
mkdir cert
cd cert
```

3. Use a secure file transfer protocol (SCP or SFTP) client (like WinSCP, or the  command line tool) to upload your PFX file and the associated password file (, if provided by your CA) from your local machine to the server directory. [1]  

##### Configure the Tomcat  File 

1. Locate the `server.xml` configuration file, which is typically in the `conf` directory of your Tomcat installation (e.g., `opt/tomcat/conf/server.xml`). 
2. Open the file for editing using a text editor like `nano`.

``` bash
nano /opt/tomcat/conf/server.xml
```

3. Find the existing SSL/TLS  entry (usually commented out and configured for port 8443 or 443). Uncomment it if necessary. 
4. Modify the connector attributes to use your PFX file and specify the  keystore type. Ensure the  attribute points to the correct path of your PFX file and  is the correct password. 

``` xml
<Connector 
    protocol="org.apache.coyote.http11.Http11NioProtocol"
    port="443" 
    maxThreads="200"
    scheme="https" 
    secure="true" 
    SSLEnabled="true"
    keystoreFile="/opt/tomcat/cert/your_certificate.pfx"
    keystorePass="your_pfx_password"
    keystoreType="PKCS12"
    clientAuth="false" 
    sslProtocol="TLS"
/>
```

5. Example configuration: 

	• `port`: Change from 8443 to 443 for standard HTTPS traffic (requires root privileges or appropriate system configuration). 
	• `keystoreFile`: The absolute path to your PFX file. 
	• `keystorePass`: The password for your PFX file (found in the  file or the one you set during creation). 
	• `keystoreType`: MUST be set to . 

6. Save the changes to  and exit the editor. [1, 2, 3, 4, 5]  

##### Restart Tomcat 

1. Navigate to the  directory of your Tomcat installation. 
2. Shut down the Tomcat service. 
3. Start the Tomcat service again to apply the changes. [1, 6, 7, 8]  

##### Verify the Installation 

Open a web browser and access your website using `https://server.domain.com` (port 443 is used by default if accessing via https). You should see the site load securely with your new SSL certificate. [9, 10, 11, 12]

[1] https://docs.byteplus.com/en/docs/byteplus-certificate-center/docs-install-pfx-certificate-on-tomcat
[2] https://stackoverflow.com/questions/23271327/installing-updated-pfx-wildcard-into-tomcat-keystore
[3] https://docs.byteplus.com/zh-CN/docs/byteplus-certificate-center/docs-install-pfx-certificate-on-tomcat
[4] https://docs.rclapp.com/installations/apache-tomcat.html
[5] https://knowledge.digicert.com/tutorials/tomcat-create-csr-install-ssl-tls-certificate
[6] https://docs.byteplus.com/en/docs/byteplus-certificate-center/docs-install-jks-certificate-on-tomcat
[7] https://support.huawei.com/enterprise/en/doc/EDOC1100467681/814bc119/installing-an-ssl-certificate
[8] https://medium.com/@imageadhikari/static-site-hosting-with-tomcat-a-step-by-step-guide-463d24d7b55e
[9] https://www.tencentcloud.com/document/product/1007/30956
[10] https://certpanel.com/resources/how-to-install-an-ssl-certificate-on-nginx-ubuntu-manually-or-automatically/
[11] https://docs.safe.com/fme/2021.1/html/FME_Server_Documentation/AdminGuide/configuring_for_https.htm
[12] https://upcloud.com/resources/tutorials/install-lets-encrypt-nginx/

#### Allow Remote Access

If accessing the Tomcat web interface from another machine, which is the _only_ way to access it if you are installing on an instance without a graphical user interface, you first need to enable access from a machine other than `localhost`. This is accomplished by editing the `context.xml` file. If installed according to the instructions above, this is located in 