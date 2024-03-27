# GeoAnalytics Engine

## Documentation
- [ArcGIS Developers Geoanalytics](https://developers.arcgis.com/geoanalytics/)
- [Python API Reference](https://developers.arcgis.com/geoanalytics/api-reference/index.html)

## Code Snippets

### Load Points with Coordinate Columns

- [geoanalytics.sql.functions.point](https://developers.arcgis.com/geoanalytics/api-reference/geoanalytics.sql.functions.html#point)
- [geoanalytics.sql.functions.srid](https://developers.arcgis.com/geoanalytics/api-reference/geoanalytics.sql.functions.html#srid)

```python
from geoanalytics.sql import functions as fns_ga
from pyspark.sql import SparkSession
from pyspark.sql import functions as fns

pqt_pth = "/path/to/parquet"
coord_x_col = "longitude"
coord_y_col = "latitude"
geom_col = "geometry"

# get the active spark session - requires there to be one
spark = SparkSession.getActiveSession()

# read in the data frame
df = (spark.read.parquet(pqt_pth)
      .withColumn(
          colName=geom_col, 
          col=fns_ga.point(
              x=coord_x_col, 
              y=coord_y_col,
              sr=4326
          )
     )
     .fns_ga.set_geometry_field(geom_col)
)
```

### Spatial Join (Intersects)

- [geoanalytics.sql.functions.intersects](https://developers.arcgis.com/geoanalytics/api-reference/geoanalytics.sql.functions.html#intersects)

```python hl_lines="6 7 8 9"
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