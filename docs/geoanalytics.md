# GeoAnalytics Engine

## Documentation
- [ArcGIS Developers Geoanalytics](https://developers.arcgis.com/geoanalytics/)
- [Python API Reference](https://developers.arcgis.com/geoanalytics/api-reference/index.html)

## Code Snippets

### Spatial Join (Overlay)

- [geoanalytics.sql.functions.intersects](https://developers.arcgis.com/geoanalytics/api-reference/geoanalytics.sql.functions.html#intersects)

```python
from geoanalytics.sql import functions as fns_ga
from pyspark.sql import functions as fns

df_pnts = df_pnts.join(
    other=df_poly,
    on=fns_ga.intersects(
        geometry1=df_pnts["geometry"], 
        geomery2=df_poly["overlay_geometry"]
    ),
    how="left",
)
```