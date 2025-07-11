# Swap ArcGIS Online View Source

There are times when it is just easier to swap the source for a Feature Layer View manually. Doing this manually requires going to the
item page, and going to the REST endpoint. From there click on Admin in the top right corner of the page. This will take you to another
similar page, with the _Supported Operations_ now including _Add to Definition_ and _Delete from Definition_. These will be used to first
remove the existing reference to the Feature Service, and next, add the new.

## Remove Existing

Using the layer index, remove the exiting layer from the Feature Layer View. After clicking on _Delete from Definition_. On the _Delete 
From Service Definition_ page, remove and replace the JSON in the window with the following.

``` json
{
  "layers": [
    {
      "id": 0
    }
  ]
}
```

## Add New Layer

After successfully removing the layer, next add the new one by going to _Add to Definition_. On the _Add to Service Definition_ page,
replace the JSON with the following, replacing `centroids_20250611` with the name of the updated feature service name.

``` json
{
  "layers": [
    {
      "adminLayerInfo": {
        "viewLayerDefinition": {
          "sourceServiceName": "centroids_20250611",
          "sourceLayerId": 0,
          "sourceLayerFields": "*"
        },
        "geometryField": {
          "name": "Shape"
        },
        "xssTrustedFields": ""
      }, 
      "id": 0,
      "name": "centroids_20250611"
    }
  ]
}
```