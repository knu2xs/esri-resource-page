# ⚡ ArcGIS Portal – Fast Rebuild Checklist

## ✅ Preconditions / sanity checks

* [ ] Confirm you truly need a rebuild (not just password recovery)
* [ ] Backup if needed (`webgisdr` or snapshot)
* [ ] Confirm Portal service account credentials available
* [ ] Confirm install media + license file ready

***

# 🔧 Phase 1 — Stop Portal

```cmd
net stop Portal for ArcGIS
```

* [ ] Verify service stopped
* [ ] Close any open file handles (Explorer windows, etc.)

***

# 🚀 Phase 2 — Fast delete content directory (KEY STEP)

> This is where you save the most time.

## Option A — Standard fast delete

```cmd
del /f /s /q D:\arcgisportal\*.* > nul
rmdir /s /q D:\arcgisportal
```

## Option B — Ultra-fast (large deployments)

```cmd
mkdir D:\empty
robocopy D:\empty D:\arcgisportal /MIR
rmdir /s /q D:\empty
rmdir /s /q D:\arcgisportal
```

* [ ] Verify `D:\arcgisportal` is gone
* [ ] Double-check path before deletion (critical)

***

# 🔧 Phase 3 — Restart Portal (no reinstall yet)

```cmd
net start Portal for ArcGIS
```

* [ ] Wait \~1–2 minutes for startup
* [ ] Verify Portal is accessible:

```
https://<host>:7443/arcgis/home
```

✅ Expected result:

* Portal prompts **“Create New Portal”**

***

# 🏗️ Phase 4 — Recreate Portal site

* [ ] Navigate to:
  ```
  https://<host>:7443/arcgis/home
  ```
* [ ] Click **Create New Portal**
* [ ] Set:
  * Admin username/password
  * Content directory:
    ```
    D:\arcgisportal
    ```

***

# ⚙️ Phase 5 — Initial configuration

* [ ] Wait for site creation (index + DB build)
* [ ] Log in as admin
* [ ] Set:
  * Organization name
  * Security settings
* [ ] Verify Portal loads cleanly

***

# 🔗 Phase 6 — Reconnect Enterprise components

If applicable:

* [ ] Federate ArcGIS Server
* [ ] Configure Hosting Server
* [ ] Validate:
  * Server health
  * Data Store registration
  * Hosted layers

***

# ✅ Phase 7 — Cleanup / validation

* [ ] Confirm logs are healthy
* [ ] Confirm no “upgrade mode” or DB errors
* [ ] Remove temp admin accounts (if used)
* [ ] Re-enable antivirus (if disabled)

***

# ⚡ Performance boosts (highly recommended)

* [ ] Content dir on **dedicated SSD/NVMe (D:)**
* [ ] Disable indexing on D:
* [ ] Exclude from antivirus:
  * `D:\arcgisportal`
  * Portal install directory
* [ ] Keep binaries on C:, data on D:

***

# 🚫 When NOT to use this runbook

Use **CreateAdminAccount** instead if:

* You only lost admin credentials
* Portal is otherwise healthy

👉 This runbook is for:

* Corrupt Portal state
* Failed site creation / upgrade loops
* Clean rebuild scenarios

***

# 💡 Key insight (why this is fast)

This avoids:

* MSI uninstall delays
* slow file-by-file deletion
* unnecessary reinstall cycles

👉 You’re resetting **state**, not reinstalling software

***

# ✅ One-line “break glass” version

If you’re in a rush:

```cmd
net stop "Portal for ArcGIS"
robocopy D:\empty D:\arcgisportal /MIR
rmdir /s /q D:\empty
net start "Portal for ArcGIS"
```

Then hit `/arcgis/home` and recreate.