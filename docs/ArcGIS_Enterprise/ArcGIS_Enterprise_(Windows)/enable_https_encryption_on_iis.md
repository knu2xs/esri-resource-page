# Enable HTTPS Encryption on IIS

!!! note "Get Esri Domain Certificate"

    Domain certificates can be secured from the [Create SSL Server Certificates](https://certifactory.esri.com/certs/) internal website.

Start by opening IIS Manager by searching for IIS Manager.

## Install Server Certificate in IIS

- In IIS Manager, select the machine name, and then open Server Certificates.
- Click on import, and import the *.pfx file in the dialog.

![Server Certificates in IIS](../assets/iis_server_certificates.png)

## Bind the Certificate to HTTPS

- In the IIS Connections tree, expand Sites and select Default Web Site.
- Right-click Default Web Site and choose Edit Bindings.
- Click Add.
- Change type to https.
- For SSL Certificate, choose the previously imported certificate.

![Bind HTTPS Certificate](../assets/bind_certificate_to_https.png)