# Install IIS Prerequsites

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