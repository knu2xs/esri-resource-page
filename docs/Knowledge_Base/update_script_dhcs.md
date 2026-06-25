# Portal + Datastore Update

!!! danger "Crowdstrike"  
	It is absolutey imperative Crowdstrike is disabled on the ArcGIS Portal instance (`dhitsgolwebip30`) for this upgrade to be successful.

Please ensure the following resources are downloaded and in `D:\Temp`.

-   Portal for ArcGIS 12.1 Installation Files
    -   `Portal_for_ArcGIS_Windows_121_200161.exe`
    -   `Portal_for_ArcGIS_Windows_121_200161.exe.001`
-   License File (`*.json`)
-   ArcGIS Datastore 12.1 Installation Files
    -   `ArcGIS_DataStore_Windows_121_200164.exe`
    -   `ArcGIS_DataStore_Windows_121_200164.exe.001`
-   Survey123
    -   `ArcGIS_Survey123_Website_3_25_0_200187.exe`

## Portal

-   Verify `D:\arcgisportal`
    -   `.\config-store`
    -   `.\config-store\site.json`
    -   `.\config-store\security-config.json`

### Create Backup

* Create a directory for the backup `D:\arcgisbackup`.
* Create a zipped archive of `D:\arcgisportal`, `D:\arcgisbackup\arcgisportal_20260624`.

### Install Portal

!!! warning "Validate Portal for ArcGIS Security 2026 Update 1 Patch D"
	Prior to upgrading, verify Portal for ArcGIS Security 2026 Update 1 Patch D is installed.
	Reference: [Upgrade from ArcGIS Enterprise 11.5 to versions 12.0 or 12.1 fails when the Portal for ArcGIS 11.5 Security 2026 Update 1 Patch is installed on Windows](https://support.esri.com/en-us/knowledge-base/upgrade-from-arcgis-enterprise-11-5-to-12-1-security-up-000042062)

1.  Double click `D:\Temp\Portal_for_ArcGIS_Windows_121_200161.exe` and extract to `D:\Temp`, but **do not** install at end of extract wizard.

2.  Run `Setup.exe` as administrator
	
	!!! note 
		This should take 40 minutes to an hour or so.

3.  Run the portal update wizard at `https://dhitsgolwebip30.intra.dhs.ca.gov:7443/arcgis/home/createadmin.html` (should open automatically).

4. Monitor progress in the logs, `D:\arcgisportal\logs\server`.

5. On the web adapter instance register with the `portal` Web Adapter at...

```
https://dhitsgolwebip31.intra.dhs.ca.gov/portal/webadapter/portal
```

6. Validate access at the following url and through the Entra chilcklet.

```
https://dhitsgolwebip31.intra.dhs.ca.gov/portal
```

## Datastore

!!! bug "Remove ArcGIS Datastore 11.5 Reliablity Patch"  
	The ArcGIS Datastore 11.5 Reliablity Patch **must** be removed, or this upgrade **will fail**.
	
	* Control Panel > Programs and Features
	* View Installed Updates
	* Uninstall **ArcGIS Datastore 11.5 Reliablity Patch**


1. Double click `D:\Temp\ArcGIS_DataStore_Windows_121_200164.exe` and extract to `D:\Temp`, but **do not** install at end of extract wizard.

2. Run `Setup.exe` as administrator.

3. Run the datastore update wizard (`https://localhost:2443/arcgis/datastore/upgrade`).

	* hosting server
	```
	https://dhitsgolwebip31.intra.dhs.ca.gov:6443/arcgis
	```

	* username
	```
	gisadmin
	```

4. Monitor logs in `D:\arcgisdatastore\logs`.

	* `server` logs to see if different data store types can start
	* `database` logs to see if there are issues with the PostgreSQL instance

5. Ensure portal is correctly recognizing the hosting server in Portal.

	```
	https://dhitsgolwebip31.intra.dhs.ca.gov/portal
	```
	
    * Organization > Settings > Servers

## Survey123

Survey123 follows the same general install/update pattern as the sections above.

1. Double click `D:\Temp\ArcGIS_Survey123_Website_3_25_0_200187.exe` and extract the files to `D:\Temp`, but **do not** complete the installation at the end of the extract wizard.

2. On `DHITSGOLWEBIP31`, remove the existing 11.5 web adapter instance for `/survey` before reinstalling it as 12.1.

	* Open Programs and Features or the ArcGIS Web Adaptor installer maintenance screen.
	* Choose **Remove** for the current `/survey` web adapter.
	* Confirm the `/survey` virtual directory is cleared before reinstalling.

3. Run `Setup.exe` as administrator.

4. Complete the survey123 setup/update wizard and point it at the existing Portal or organization when prompted.

5. Reinstall the 12.1 web adapter to the `/survey` route on `DHITSGOLWEBIP31` and register it back to the portal.

6. Open the survey123 website through the 12.1 web adapter on `DHITSGOLWEBIP31` at `https://dhitsgolwebip31.intra.dhs.ca.gov/survey` and verify it loads and signs in successfully.

7. If the installer reports an error, review the Survey123 installer logs before retrying.