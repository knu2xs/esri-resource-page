# GeoAnalytics Engine

## Documentation
- [ArcGIS Developers Geoanalytics](https://developers.arcgis.com/geoanalytics/)
- [Python API Reference](https://developers.arcgis.com/geoanalytics/api-reference/index.html)

## Code Snippets

### Load Points with Coordinate Columns

- [geoanalytics.sql.functions.point](https://developers.arcgis.com/geoanalytics/api-reference/geoanalytics.sql.functions.html#point)
- [geoanalytics.extensions.STDataFrameAccessor.set_geometry_field](https://developers.arcgis.com/geoanalytics/api-reference/geoanalytics.extensions.html#set-geometry-field)

```python hl_lines="17 18 19 20 23"
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
     .st.set_geometry_field(geom_col)
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

### Geocoding

- **TODO:** Document how to use StreetMap Premium internally

- [geoanalytics.tools.Geocode](https://developers.arcgis.com/geoanalytics/api-reference/geoanalytics.tools.html#geocode)

```python hl_lines="17 18 19 20 21 22"
from geoanalytics import auth_info
from geoanalytics.tools import Geocode
from geoanalytics.sql import functions as fns_ga
from pyspark.sql import functions as fns

# variables for urls and paths
data_url = r"https://services1.arcgis.com/Ua5sjt3LWTPigjyD/arcgis/rest/services/Public_School_Location_201819/FeatureServer/0"
loc_pth = r"/home/geoanalytics/United_States.mmpk"

# Create a public schools DataFrame
df = (spark.read.format("feature-service").load(data_url) 
      .filter(fns.col('STATE') == 'WA')
      .select("NAME", "STREET", "CITY", "STATE", "ZIP")
     )

# Use Geocode to convert the public school addresses into actual locations
geocoder = (Geocode()
            .setLocator(loc_pth)
            .setAddressFields("NAME", "STREET", "CITY", "STATE", "ZIP")
            .setMinScore(80)
            .setOutFields("all")
            .setCountryCode("USA")
           )

# run the geocoder
df_addr = geocoder.run(df)
```