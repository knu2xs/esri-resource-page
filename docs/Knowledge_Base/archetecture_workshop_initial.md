Please run the tools below against your ArcGIS Enterprise site. Both tools will generate excel files which may be too large to email. Please upload them to a OneDrive folder I’ll share with you. You’ll receive a separate email with the access link.  You can also upload the files to your OneDrive folder and share it with me if it’s easier or if you have issues accessing our OneDrive.

Let me know if you have any questions. I can also hop on a call with one of you next week to run the tools.

The GIS Enterprise Reporter can be downloaded from https://github.com/EsriPS/gisenterprisereporter
https://github.com/Esri/SystemLogParser. We recommend running it from a machine which can access the ArcGIS Portal machine using the 7443 port.  Additional information is available at https://community.esri.com/t5/implementing-arcgis-blog/running-gis-enterprise-reporter-tips-amp-tricks/ba-p/1170460.
Please use the ArcGIS Server option to run the tool against any un-federated or stand-alone ArcGIS Server machines using the 6443 port.

Image


The System Log Parser can be downloaded from https://github.com/Esri/SystemLogParser.  Please run it against each ArcGIS Server machine when you have at least 5 business days' worth of logs with log level set to FINE by using the ArcGIS Server (FS) option. Choose Complete for Analysis Type and Spreadsheet for Report Type. Using the Complete option can be memory intensive so please execute this from a client machine which can access the ArcGIS Server folder system instead of directly on the server.
image.png

Also execute the System Log Parser tool on your IIS logs on the Web Adaptor machine for the same time period with Analysis Type set to optimized:
image.png