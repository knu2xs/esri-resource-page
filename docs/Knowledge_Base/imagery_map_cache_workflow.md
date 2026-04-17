# Imagery Map Cache Workflow

Below is a **battle‑tested, lowest‑impact cache build playbook** for **ArcGIS Enterprise map caches** (no Image Server), explicitly designed to **minimize CPU, I/O, storage spikes, and user disruption** while still producing a **fully compatible basemap cache**.

Everything here is supported by Esri documentation and field practice. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/considerations-when-creating-cache-content.htm), [\[esriaustra...dpress.com\]](https://esriaustraliatechblog.wordpress.com/2023/08/01/caching-best-practices-in-arcgis-enterprise/), [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/10.9.1/publish-services/windows/accelerating-map-cache-creation.htm), [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/cache-efficiently.htm)

***

# Lowest‑Impact Cache Build Playbook

*(Enterprise Map Image Layer → Cached Basemap)*

## Goal

> Build a large raster basemap cache **without overwhelming ArcGIS Server**, shared storage, or downstream users.

***

## Phase 0 — Before You Touch the Server (Most Impact)

### ✅ 0.1 Pre‑optimize raster **offline**

Do this *before* publishing:

*   Reproject raster to **Web Mercator**
*   Mosaic once (single raster or minimal mosaic dataset)
*   Build **pyramids and statistics**
*   Eliminate dynamic rendering (masking, stretch, etc.)

This removes the most CPU‑intensive work from the cache build process. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/10.9.1/publish-services/windows/accelerating-map-cache-creation.htm)

***

### ✅ 0.2 Tune symbology for caching

*   Raster only
*   No transparency unless required
*   No blend modes or effects

During cache creation, **every styling decision is multiplied by millions of tiles**.

***

## Phase 1 — Publish for Caching (Minimal Runtime Cost)

### ✅ 1.1 Publish as **Map Image Layer**

*   Referenced data (not copied)
*   Mapping only
*   No feature capabilities

This ensures ArcGIS Server only renders pixels, not features. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/considerations-when-creating-cache-content.htm)

***

### ✅ 1.2 Enable caching but **do nothing else yet**

At publish time:

*   Enable caching
*   Choose **ArcGIS Online / Bing / Google tiling scheme**
*   DO NOT auto‑build the cache

Esri strongly recommends **manual cache building** to avoid oversized, inefficient caches. [\[mumgis.mcgm.gov.in\]](https://mumgis.mcgm.gov.in/portal/portalhelp/en/portal/latest/use/optimize-maps.htm)

***

## Phase 2 — Cache Design Decisions (Biggest Server Impact Lever)

### ✅ 2.1 Choose the *minimum* viable scale set

**Rule of thumb**

| Extent            | Recommended max zoom  |
| ----------------- | --------------------- |
| Statewide imagery | 1:9,028 – 1:18,056    |
| County imagery    | 1:4,514               |
| City imagery      | 1:2,257 (rarely more) |

The largest‑scale levels generate **90%+ of tiles**. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/considerations-when-creating-cache-content.htm)

***

### ✅ 2.2 Use JPEG unless transparency is required

*   JPEG = smallest size + fastest build
*   PNG = 3–10× more I/O cost

Esri explicitly calls out image format choice as a major resource factor. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/cache-efficiently.htm)

***

## Phase 3 — Low‑Impact Cache Build Strategy

This is where most people go wrong.

***

### ✅ 3.1 Build *small‑scale tiles first*

Order matters.

**Recommended sequence**

1.  World → regional scales
2.  Stop
3.  Validate visuals
4.  Proceed to mid‑scales
5.  Proceed to large‑scales last

If something fails, you’ve only wasted the *cheapest* tiles. [\[esriaustra...dpress.com\]](https://esriaustraliatechblog.wordpress.com/2023/08/01/caching-best-practices-in-arcgis-enterprise/)

***

### ✅ 3.2 Always constrain areas of interest

Never cache full extent by default.

Use:

*   **Counties**
*   **Urban areas**
*   **Land‑only polygons**
*   **Administrative boundaries**

Esri documents AOI caching as the single most effective way to reduce cache size and build time. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/cache-efficiently.htm)

***

### ✅ 3.3 Split cache jobs intentionally

Instead of:

> “All scales, all areas, one job”

Do:

*   One job per scale range
*   One job per AOI
*   Multiple short‑lived jobs

This:

*   Reduces lock contention
*   Improves recoverability
*   Preserves service responsiveness

***

## Phase 4 — Server Resource Protection

### ✅ 4.1 Limit caching service concurrency

In **CachingTools service**:

*   Start with:
        Max instances = CPU cores + 1
*   Increase only after monitoring

Esri explicitly warns against saturating CPUs at 100% during caching. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/10.9.1/publish-services/windows/accelerating-map-cache-creation.htm)

***

### ✅ 4.2 Schedule during true off‑hours

Cache builds are:

*   CPU‑heavy
*   Disk‑heavy
*   Burst‑spiky

Avoid:

*   Business hours
*   ETL windows
*   Backup windows

***

### ✅ 4.3 Prefer local disk over network storage

If possible:

*   Place raster data and cache on **local fast disks**
*   Replicate data paths across server nodes

Network latency is a major cache slowdown risk. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/10.9.1/publish-services/windows/accelerating-map-cache-creation.htm)

***

## Phase 5 — Validate Early, Often, and Cheaply

### ✅ 5.1 Spot‑check tiles at every phase

After each scale group:

*   Zoom directly to tile endpoints
*   Look for seams, blurring, artifacts

Catching errors at small scales saves hours or days later. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/considerations-when-creating-cache-content.htm)

***

### ✅ 5.2 Track disk growth intentionally

Monitor:

*   Cache directory size
*   Tile counts by level

Large‑scale levels explode exponentially. [\[esriweb.lge-ku.com\]](https://esriweb.lge-ku.com/portal/portalhelp/en/server/latest/publish-services/windows/planning-a-map-cache.htm)

***

## Phase 6 — Production Hygiene

### ✅ 6.1 Freeze the basemap

Once complete:

*   Disable further cache generation
*   Document scale limits
*   Treat as immutable

Basemaps should be **snapshots**, not live services. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/considerations-when-creating-cache-content.htm)

***

### ✅ 6.2 Add as Portal basemap web map

*   Single cached service
*   Nothing dynamic
*   Shared via basemap gallery

Esri explicitly recommends cached services for Portal basemaps. [\[enterprise...arcgis.com\]](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/considerations-when-creating-cache-content.htm)

***

## Summary: The “Lowest‑Impact Rules”

✅ Pre‑render everything before publishing  
✅ Cache as little area and as few scales as possible  
✅ Build coarse → fine  
✅ Split jobs aggressively  
✅ Never let caching auto‑run blindly

***

### If you want next

I can:

*   Produce a **one‑page operator runbook**
*   Generate an **AOI feature class strategy**
*   Estimate **tile counts and disk impact** *before* building

Just tell me your **extent size and max zoom target**.
