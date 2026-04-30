# Integrating Business Analyst into Spark Data Pipelines

Business Analyst integration (trade area generation and enrichment) is not supported as a native process in Spark. However, including enriched data for a location using a trade area _is_ possible as part of a Spark workflow through an ArcGIS GeoEnrichment REST endpoint. This requires either an instance of Business Analyst Enterprise or using credits through ArcGIS Online. This requires enriching each location first, caching the result, and using this result as part of subsequent analysis.

``` python
from arcgis import GeoAccessor
from arcgis.gis import GIS
from arcgis.geoenrichment import enrich
import pandas as pd

#
