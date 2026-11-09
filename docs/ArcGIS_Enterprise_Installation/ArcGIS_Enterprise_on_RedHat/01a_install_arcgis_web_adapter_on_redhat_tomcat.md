# Install ArcGIS Web Adaptor 11.5 on Red Hat Enterprise Linux with Tomcat

These instructions cover the Java platform deployment of ArcGIS Web Adaptor 11.5 on Red Hat Enterprise Linux (RHEL) with Apache Tomcat. They assume a single Tomcat instance and a Web Adaptor that terminates HTTPS on port 443.

The ArcGIS Web Adaptor version must match the ArcGIS Enterprise version it connects to. Before installing, verify that the exact RHEL update, Java version, and Tomcat release you plan to use are supported by the 11.5 system-requirements page. The requirements page lists RHEL Server 9 Update 5 and RHEL Server 8 Update 10 as tested, Apache Tomcat 9.0.x and 10.1.x, and Java 8, 11, and 17. Later RHEL updates are supported subject to the operating system and application-server vendors' support.

## References

- [ArcGIS Web Adaptor 11.5 for Java on Linux: installation](https://enterprise.arcgis.com/en/web-adaptor/11.5/install/java-linux/install-arcgis-web-adaptor.htm)
- [ArcGIS Web Adaptor 11.5 system requirements](https://enterprise.arcgis.com/en/web-adaptor/11.5/install/java-linux/arcgis-web-adaptor-system-requirements.htm)
- [Red Hat Enterprise Linux 9: firewalld](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_firewalls_and_packet_filters/index)
- [Red Hat Enterprise Linux 9: SELinux](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_selinux/index)
- [Filesystem Hierarchy Standard](https://refspecs.linuxbase.org/FHS_3.0/fhs-3.0.html)
- [systemd service execution settings](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html)
- [Apache Tomcat 10.1 documentation](https://tomcat.apache.org/tomcat-10.1-doc/)

## 1. Prepare the RHEL host

Schedule operating-system updates through your normal maintenance process. Updating a production host can change Java, Tomcat, or other dependencies; confirm compatibility and take backups before applying updates.

```bash
sudo dnf check-update
```

Install the Java release selected from the ArcGIS Web Adaptor 11.5 compatibility requirements. This example installs OpenJDK 17; use the corresponding package if your supported Tomcat configuration requires Java 8 or 11.

```bash
sudo dnf install java-17-openjdk-headless tar gzip curl policycoreutils-python-utils
java -version
```

Create a dedicated, non-interactive Tomcat account with a writable home directory. ArcGIS Web Adaptor configuration may be written to the deploying user's home directory.

```bash
sudo useradd --system --user-group --create-home \
  --home-dir /var/lib/web-services --shell /sbin/nologin web-services
sudo chmod 0750 /var/lib/web-services
```

## 2. Configure the firewall

Use the active firewalld zone for the host's network interface. Esri's installation prerequisites call for a website on HTTP port 80 and HTTPS port 443. Provide both ports according to your web-server architecture; this Tomcat example configures HTTPS on 443, while HTTP/80 may be handled by a front-end web server or a separately configured Tomcat connector. Open HTTPS for Web Adaptor traffic and HTTP only if your site requires it. Do not expose Tomcat's default port 8080 to the public network; use it for local testing or restrict it to a trusted management network.

```bash
sudo firewall-cmd --get-active-zones
```

Replace `public` below if the active interface uses a different zone:

```bash
sudo firewall-cmd --permanent --zone=public --add-service=https
# Optional: enable only if HTTP is intentionally served or redirected.
sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --reload
sudo firewall-cmd --zone=public --list-all
```

Do not enable or replace the host firewall policy as part of this procedure. Add only the inbound services required by the deployment, and coordinate any network firewall or load-balancer rules separately.

## 3. Install Apache Tomcat

Choose a Tomcat patch release supported by ArcGIS Web Adaptor 11.5 and compatible with the selected Java version. Download the binary archive and its checksum from the official [Apache Tomcat downloads](https://tomcat.apache.org/download-10.cgi) page. Verify the archive using the checksum published by Apache before extracting it.

This example uses Tomcat 10.1. Replace `<version>` with the exact supported patch version. For Tomcat 9.0.x, use the corresponding Apache Tomcat 9 download location instead.

```bash
cd /tmp
curl -fLO "https://dlcdn.apache.org/tomcat/tomcat-10/v<version>/bin/apache-tomcat-<version>.tar.gz"
# Download the matching checksum file from Apache and verify it before continuing.
sha512sum apache-tomcat-<version>.tar.gz
```

Use the FHS-oriented locations below: application binaries under `/opt`, configuration under `/etc/opt`, runtime files under `/var/opt`, and logs under `/var/log`.

```bash
sudo install -d -o root -g web-services -m 0750 /opt/tomcat /etc/opt
sudo install -d -o web-services -g web-services -m 0750 /var/opt
sudo install -d -o web-services -g web-services -m 0750 /var/log

sudo tar -xzf /tmp/apache-tomcat-<version>.tar.gz \
  -C /opt/tomcat --strip-components=1

sudo mv /opt/tomcat/conf /etc/opt/tomcat
sudo ln -s /etc/opt/tomcat /opt/tomcat/conf

sudo install -d -o web-services -g web-services -m 0750 /var/opt/tomcat
sudo mv /opt/tomcat/temp /var/opt/tomcat/temp
sudo mv /opt/tomcat/work /var/opt/tomcat/work
sudo mv /opt/tomcat/webapps /var/opt/tomcat/webapps
sudo mv /opt/tomcat/logs /var/log/tomcat

sudo ln -s /var/opt/tomcat/temp /opt/tomcat/temp
sudo ln -s /var/opt/tomcat/work /opt/tomcat/work
sudo ln -s /var/opt/tomcat/webapps /opt/tomcat/webapps
sudo ln -s /var/log/tomcat /opt/tomcat/logs

sudo chown -R root:web-services /opt/tomcat /etc/opt/tomcat
sudo chown -R web-services:web-services /var/opt/tomcat /var/log/tomcat
sudo chmod -R o-rwx /etc/opt/tomcat
```

Check that the `java` executable resolves to the intended Java installation. Use the resulting directory as `JAVA_HOME` in the systemd unit below:

```bash
JAVA_BIN=$(readlink -f "$(command -v java)")
dirname "$(dirname "$JAVA_BIN")"
```

### Create the Tomcat systemd service

Create `/etc/systemd/system/tomcat.service` with root ownership. Set `JAVA_HOME` to the path reported in the previous step.

```ini
[Unit]
Description=Apache Tomcat Web Application Server
After=network.target

[Service]
Type=simple
User=web-services
Group=web-services
Environment="HOME=/var/lib/web-services"
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_TMPDIR=/var/opt/tomcat/temp"
WorkingDirectory=/opt/tomcat
UMask=0027
NoNewPrivileges=true
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
ExecStart=/opt/tomcat/bin/catalina.sh run
ExecStop=/opt/tomcat/bin/catalina.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Replace the example `JAVA_HOME` with the actual path. Install and start the service:

```bash
sudo chown root:root /etc/systemd/system/tomcat.service
sudo chmod 0644 /etc/systemd/system/tomcat.service
sudo systemctl daemon-reload
sudo systemctl enable --now tomcat
sudo systemctl status tomcat --no-pager
```

Tomcat runs as the unprivileged `web-services` account. `CAP_NET_BIND_SERVICE` allows the service to bind to port 443 without running as root. Keep SELinux in enforcing mode. If SELinux denies Tomcat access to the configured certificate, port, or runtime directories, review the denial and apply an administrator-approved policy adjustment; do not disable SELinux or apply a broad permissive rule. An alternative is to terminate HTTPS in a supported front-end web server and proxy to Tomcat on a private interface.

Confirm Tomcat responds locally before adding the Web Adaptor:

```bash
curl -kI https://localhost/
sudo journalctl -u tomcat -b --no-pager
```

## 4. Configure HTTPS for Tomcat

Use a certificate whose subject names match the public Web Adaptor host name and whose chain is trusted by clients. Transfer the PKCS#12/PFX certificate to the host using a secure method. Protect it as a private key.

```bash
sudo install -d -o root -g web-services -m 0750 /etc/opt/tomcat/cert
sudo install -o root -g web-services -m 0640 /secure/upload/tomcat.p12 \
  /etc/opt/tomcat/cert/tomcat.p12
```

Edit `/etc/opt/tomcat/server.xml`. Configure the HTTPS connector for port 443 with your certificate path and keystore password. Do not put the password in shell history or a publicly readable file.

```xml
<Connector port="443"
           protocol="org.apache.coyote.http11.Http11NioProtocol"
           address="0.0.0.0"
           scheme="https"
           secure="true"
           SSLEnabled="true">
  <SSLHostConfig protocols="TLSv1.2,TLSv1.3">
    <Certificate
        certificateKeystoreFile="/etc/opt/tomcat/cert/tomcat.p12"
        certificateKeystoreType="PKCS12"
        certificateKeystorePassword="REPLACE_WITH_KEYSTORE_PASSWORD" />
  </SSLHostConfig>
</Connector>
```

Keep the Tomcat HTTP connector on port 8080 closed to public traffic. Validate the XML and restart Tomcat:

```bash
sudo dnf install libxml2
sudo xmllint --noout /etc/opt/tomcat/server.xml
sudo systemctl restart tomcat
sudo systemctl status tomcat --no-pager
```

If Tomcat cannot bind port 443 under SELinux, inspect the AVC denial and the current port labeling before changing policy. Do not relabel a port already used by another service without assessing the impact.

## 5. Install ArcGIS Web Adaptor 11.5

Download the Linux Java-platform Web Adaptor 11.5 installer from your authorized Esri software download location. Save the downloaded archive as `/tmp/web-adaptor-11.5-installer.tar.gz`, then extract it to a dedicated temporary directory.

```bash
sudo install -d -o root -g root -m 0755 /opt/arcgis
mkdir -p /tmp/web-adaptor-11.5
tar -xzf /tmp/web-adaptor-11.5-installer.tar.gz \
  -C /tmp/web-adaptor-11.5
```

Run the Linux setup program with administrative privileges. The installer may provide the executable as `Setup` or `Setup.sh`; use the name present in the extracted media. For a silent installation:

```bash
cd /tmp/web-adaptor-11.5
sudo ./Setup -m silent -l yes -d /opt/arcgis
```

If the setup executable is named `Setup.sh`, run `sudo ./Setup.sh` with the same options. Consult the installer's help or the Esri installation page if the media's command-line options differ.

## 6. Deploy Portal and Server Web Adaptor instances

Use the WAR file that matches your Tomcat major version:

| Tomcat version | Web Adaptor WAR file |
|---|---|
| Tomcat 10.1.x | `arcgis_tomcat10.war` |
| Tomcat 9.0.x | `arcgis.war` |

Find the WAR file under the Web Adaptor installation directory. For Tomcat 10.1.x, for example:

```bash
sudo find /opt/arcgis -type f -name 'arcgis_tomcat10.war' -print
```

Deploy one instance for Portal for ArcGIS and a separately named instance for ArcGIS Server. The context names below (`portal` and `server`) must be unique on this Tomcat host. Replace the source path with the path returned by `find`.

```bash
WAR=/opt/arcgis/webadaptor11.5/java/arcgis_tomcat10.war
sudo install -o web-services -g web-services -m 0640 "$WAR" \
  /var/opt/tomcat/webapps/portal.war
sudo install -o web-services -g web-services -m 0640 "$WAR" \
  /var/opt/tomcat/webapps/server.war
sudo systemctl restart tomcat
sudo journalctl -u tomcat -b --no-pager
```

For Tomcat 9.0.x, use `arcgis.war` in the `WAR` path instead. Confirm the deployment in the Tomcat log and test the contexts over HTTPS:

```bash
curl -kI https://localhost/portal/
curl -kI https://localhost/server/
```

Do not configure the Web Adaptor until its target Portal for ArcGIS or ArcGIS Server site is installed, running, and reachable. Then open the Web Adaptor configuration page for each context and register it with the corresponding component. One Web Adaptor can be configured with only one Portal or Server site; use separate uniquely named instances when configuring both.

The Esri `configurewebadaptor.sh` utility is an alternative to the browser-based configuration. Esri requires the Web Adaptor and Tomcat to be on the same machine when using that utility. Follow the 11.5 installation documentation for its exact invocation and permission requirements.

## Troubleshooting

- **Tomcat does not start:** Check `sudo systemctl status tomcat --no-pager` and `sudo journalctl -u tomcat -b`. Verify `JAVA_HOME`, file ownership, and `server.xml` syntax.
- **Port 443 is unavailable:** Check `sudo ss -ltnp | grep ':443'`, firewalld rules, and SELinux AVC denials. Ensure no other service already owns the port.
- **Web Adaptor WAR fails to deploy:** Confirm the WAR matches the Tomcat major version, check the Tomcat log, and verify that the service account can read the WAR and write to the Tomcat work and webapps directories.
- **Configuration page is unreachable:** Confirm the Portal or Server component is running, the Web Adaptor context deployed successfully, and inbound HTTPS is permitted through both the host and network firewalls.

After confirming registration and operation, remove the installer archive and extracted setup files from temporary storage. Continue with the remaining ArcGIS Enterprise 11.5 installation and configuration steps.
