# Install ArcGIS Web Adapter on Linux

References:

- [System Requirements](https://enterprise.arcgis.com/en/web-adaptor/latest/install/java-linux/arcgis-web-adaptor-system-requirements.htm)
- 

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

You can now access the default Tomcat web interface by navigating to `http://<your_server_IP_address>:8080` in your web browser.