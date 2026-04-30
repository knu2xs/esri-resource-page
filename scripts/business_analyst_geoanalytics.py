"""
Geoenrich point locations using Esri Business Analyst (GeoEnrichment).

Reads a set of point locations from a Parquet file, connects to an ArcGIS Online
or Enterprise organization, and runs GeoEnrichment to append demographic and
lifestyle variables to each location using a configurable proximity buffer.

Workflow
--------
1. Read point locations (longitude/latitude) from a Parquet file.
2. Cast the DataFrame to a spatially-enabled DataFrame (WKID 4326).
3. Authenticate to an ArcGIS portal via the ArcGIS Python API.
4. Enrich the locations with the variables listed in GEOENRICHMENT_VARIABLES
   using a drive-time, walk-time, or distance buffer.
5. Drop the geometry column and convert the result to a Spark DataFrame for
   downstream analysis.

Configuration
-------------
All run-time settings are controlled via the module-level constants defined
directly below the imports:

GIS_URL
    Full URL of the ArcGIS Online organization or Enterprise portal,
    e.g. ``"https://myorg.maps.arcgis.com"``.
GIS_USERNAME / GIS_PASSWORD
    Credentials for portal authentication.
PARQUET_FILE
    Absolute or relative path to the input Parquet file.  The file must
    contain ``longitude`` and ``latitude`` columns in decimal degrees (WGS 84).
GEOENRICHMENT_VARIABLES
    List of Esri Data Browser variable names to append to each location.
PROXIMITY_VALUE
    Proximity type: ``"drive_time"``, ``"walk_time"``, or ``"distance"``.
PROXIMITY_RADIUS
    Numeric radius value (minutes or miles, depending on PROXIMITY_METRIC).
PROXIMITY_METRIC
    Unit for the radius: ``"minutes"`` or ``"miles"``.

Requirements
------------
- arcgis >= 2.0
- pandas
- pyarrow (for Parquet I/O)
- PySpark (``spark`` session must be available in the execution environment)
- Access to an ArcGIS Business Analyst license on the target portal

Notes
-----
- Credentials are stored as plain-text constants for scripting convenience;
  replace with environment variables or a secrets manager before sharing.
- The GeoEnrichment service incurs credit consumption on ArcGIS Online.
"""

# import necessary libraries
from arcgis import GeoAccessor
from arcgis.gis import GIS
from arcgis.geoenrichment import enrich
import pandas as pd

# constants
GIS_URL = "https://myorg.maps.arcgis.com"
GIS_USERNAME = "your_username"
GIS_PASSWORD = "your_password"
PARQUET_FILE = "/path/to/input_locations/parquet"
GEOENRICHMENT_VARIABLES = [
    "TOTPOP_CY",   # Population: Total Population (Esri)
    "DIVINDX_CY",  # Diversity Index (Esri)
    "AVGHHSZ_CY",  # Average Household Size (Esri)
    "MEDAGE_CY",   # Age: Median Age (Esri)
    "MEDHINC_CY",  # Income: Median Household Income (Esri)
    "BACHDEG_CY",  # Education: Bachelor's Degree (Esri)
]
PROXIMITY_VALUE = "drive_time"  # can be "drive_time", "walk_time", "distance"
PROXIMITY_RADIUS = 12           # radius value in minutes or miles depending on the PROXIMITY_METRIC
PROXIMITY_METRIC = "minutes"    # can be "minutes" or "miles"

# read input locations from parquet file
input_file = PARQUET_FILE
locations_df = pd.read_parquet(input_file)

# cast to spatially enabled dataframe
spatial_df = GeoAccessor.from_xy(locations_df, x_column='longitude', y_column='latitude', sr=4326)
assert spatial_df.spatial.validate(strict=False), "Spatial dataframe is not valid. Check the input coordinates."

# connect to GIS
gis = GIS(GIS_URL, GIS_USERNAME, GIS_PASSWORD)

# perform geoenrichment
enriched_df = enrich(
    study_areas=spatial_df,
    analysis_variables=GEOENRICHMENT_VARIABLES,
    proximity_type=PROXIMITY_VALUE,
    proximity_value=PROXIMITY_RADIUS,
    proximity_metric=PROXIMITY_METRIC
)

# drop geometry column if not needed for further analysis
enriched_df = enriched_df.drop(columns='SHAPE')

# convert enriched spatial dataframe to spark dataframe for further analysis
# assumes a Spark session named 'spark' is available in the execution environment
enriched_spark_df = spark.createDataFrame(enriched_df)
