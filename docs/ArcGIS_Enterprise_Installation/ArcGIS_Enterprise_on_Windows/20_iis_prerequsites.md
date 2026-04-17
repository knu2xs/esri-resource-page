# IIS Prerequsites

For **ArcGIS Web Adaptor (IIS)** to install successfully, **IIS must be enabled with specific role services/components**. Below is the **minimum required IIS configuration**.

## Required IIS Components for ArcGIS Web Adaptor

### 1\. Web Server (IIS)

The **Web Server (IIS)** role must be installed before running the Web Adaptor installer. [\[enterprise…arcgis.com\]](https://enterprise.arcgis.com/en/web-adaptor/latest/install/iis/install-arcgis-web-adaptor.htm)

---

### 2\. Web Server → Common HTTP Features

These support basic web hosting and content delivery.

-   ✅ **Default Document**
-   ✅ **Static Content**

[\[distgis.aep.com\]](https://distgis.aep.com/portal/portalhelp/en/web-adaptor/latest/install/iis/enable-iis-10-components-server.htm), [\[mygis.iid.com\]](https://mygis.iid.com/portal/portalhelp/en/web-adaptor/latest/install/iis/enable-iis-2019-components-server.htm)

---

### 3\. Web Server → Application Development Features

Required for [ASP.NET](http://ASP.NET) and request handling used by the Web Adaptor.

-   ✅ **.NET Extensibility 4.5**
-   ✅ **[ASP.NET](http://ASP.NET) 4.5**
-   ✅ **ISAPI Extensions**
-   ✅ **ISAPI Filters**
-   ✅ **WebSocket Protocol**

[\[distgis.aep.com\]](https://distgis.aep.com/portal/portalhelp/en/web-adaptor/latest/install/iis/enable-iis-10-components-server.htm), [\[mygis.iid.com\]](https://mygis.iid.com/portal/portalhelp/en/web-adaptor/latest/install/iis/enable-iis-2019-components-server.htm)

> ⚠️ ArcGIS Web Adaptor **will not install** if [ASP.NET](http://ASP.NET) or .NET Extensibility are missing.

---

### 4\. Web Server → Security

Required for authentication with ArcGIS Enterprise and Portal.

-   ✅ **Request Filtering**
-   ✅ **Basic Authentication**
-   ✅ **Windows Authentication**

[\[distgis.aep.com\]](https://distgis.aep.com/portal/portalhelp/en/web-adaptor/latest/install/iis/enable-iis-10-components-server.htm), [\[mygis.iid.com\]](https://mygis.iid.com/portal/portalhelp/en/web-adaptor/latest/install/iis/enable-iis-2019-components-server.htm)

> 💡 Even if you plan to use only PKI or federation, these **must still be enabled**.

---

### 5\. Web Server → Management Tools

Required for IIS site configuration and compatibility with the Web Adaptor installer.

-   ✅ **IIS Management Console**
-   ✅ **IIS Management Scripts and Tools**
-   ✅ **IIS Management Service**
-   ✅ **IIS 6 Management Compatibility**
    -   ✅ IIS Metabase and IIS 6 configuration compatibility

[\[distgis.aep.com\]](https://distgis.aep.com/portal/portalhelp/en/web-adaptor/latest/install/iis/enable-iis-10-components-server.htm), [\[mygis.iid.com\]](https://mygis.iid.com/portal/portalhelp/en/web-adaptor/latest/install/iis/enable-iis-2019-components-server.htm)

> This is one of the **most commonly missed** dependencies and a frequent cause of installer failure.

---

## Additional (Non-IIS) Prerequisites (Still Required)

While not IIS components, these are mandatory for a successful install:

-   ✅ **Microsoft Web Deploy 4.0**
-   ✅ **[ASP.NET](http://ASP.NET) Core Runtime – Windows Hosting Bundle (8.x)**

[\[enterprise…arcgis.com\]](https://enterprise.arcgis.com/en/web-adaptor/latest/install/iis/install-arcgis-web-adaptor.htm)

---

## Ports & Site Requirements

-   ✅ A website running on **HTTP (port 80)**
-   ✅ HTTPS enabled on **port 443**

[\[enterprise…arcgis.com\]](https://enterprise.arcgis.com/en/web-adaptor/latest/install/iis/install-arcgis-web-adaptor.htm)

---

## Practical Notes (Based on Field Experience)

-   The **`.exe` installer can auto-enable IIS components**, but the `.msi` installer **cannot** [\[community.esri.com\]](https://community.esri.com/t5/arcgis-enterprise-questions/specific-iis-components-are-required-for-iis-7-0/td-p/1144232)
-   On **Windows Server 2019 / Azure VMs**, IIS installs often **omit required role services by default**
-   Enabling *extra IIS features is safe*—Esri only enforces a minimum set

---

## Recommended Validation Approach

Before installing Web Adaptor:

1.  Verify IIS role services in **Server Manager → Roles → Web Server (IIS)**
2.  Confirm **[ASP.NET](http://ASP.NET) 4.5** and **IIS 6 Management Compatibility**
3.  Verify the **Hosting Bundle** is installed *after* IIS is enabled

```ps
#region Configuration
$WebDeployMsiUrl = "https://download.microsoft.com/download/0/1/2/0125C8B0-4EFA-4DB3-8C46-1F0F7C47F6D1/WebDeploy_amd64_en-US.msi"
$TempDir = "C:\Temp"
$WebDeployMsi = Join-Path $TempDir "WebDeploy_amd64_en-US.msi"
#endregion

Write-Host "=== ArcGIS Web Adaptor Gold Image Build Starting ===" -ForegroundColor Cyan

#region 1. Install IIS + required features
Write-Host "Installing IIS and required role services..." -ForegroundColor Yellow

Import-Module ServerManager

$iisFeatures = @(
    # IIS Core
    "Web-Server",

    # Common HTTP Features
    "Web-Default-Doc",
    "Web-Static-Content",

    # Application Development
    "Web-Asp-Net45",
    "Web-Net-Ext45",
    "Web-ISAPI-Ext",
    "Web-ISAPI-Filter",
    "Web-WebSockets",

    # Security
    "Web-Filtering",
    "Web-Basic-Auth",
    "Web-Windows-Auth",

    # Management Tools
    "Web-Mgmt-Console",
    "Web-Mgmt-Service",
    "Web-Mgmt-Tools",

    # IIS 6 Compatibility (required by ArcGIS Web Adaptor)
    "Web-Mgmt-Compat",
    "Web-Metabase"
)

Install-WindowsFeature -Name $iisFeatures -IncludeManagementTools -Verbose

#endregion

#region 2. Install ASP.NET Core Hosting Bundle 8.x
Write-Host "Installing ASP.NET Core Hosting Bundle 8.x..." -ForegroundColor Yellow

if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install `
        --id Microsoft.DotNet.HostingBundle.8 `
        -e `
        --accept-package-agreements `
        --accept-source-agreements
}
else {
    Write-Warning "winget not found. Install ASP.NET Core Hosting Bundle 8.x manually."
}

#endregion

#region 3. Install Web Deploy 4.0
Write-Host "Installing Web Deploy 4.0..." -ForegroundColor Yellow

if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

if (-not (Get-Command msdeploy.exe -ErrorAction SilentlyContinue)) {
    Invoke-WebRequest -Uri $WebDeployMsiUrl -OutFile $WebDeployMsi

    Start-Process msiexec.exe `
        -ArgumentList "/i `"$WebDeployMsi`" /quiet /norestart ADDLOCAL=ALL" `
        -Wait
}
else {
    Write-Host "Web Deploy already installed."
}

#endregion

#region 4. Validation Summary
Write-Host "`n=== Validation Summary ===" -ForegroundColor Cyan

Write-Host "`nInstalled IIS Features:"
Get-WindowsFeature Web-* | Where-Object { $_.InstallState -eq "Installed" } |
    Select Name, DisplayName

Write-Host "`nASP.NET Core Hosting Bundle:"
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\ASP.NET Core\Shared Framework" -ErrorAction SilentlyContinue

Write-Host "`nWeb Deploy:"
Get-Command msdeploy.exe -ErrorAction SilentlyContinue

#endregion

Write-Host "`n=== Gold Image Build Complete ===" -ForegroundColor Green
```