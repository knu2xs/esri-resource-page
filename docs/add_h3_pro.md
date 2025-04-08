# Adding H3 to ArcGIS Pro

Adding H3 to ArcGIS Pro requires creating a new cloned Conda environment, a copy of the default `arcgispro-py3` environment, installing H3 into this new environment, and telling ArcGIS Pro to use this new environment.

## Step by Step

Start by opening up the Python Command Promptby going to **Start > Programs > ArcGIS > Python Command Prompt**. This opens up a Windows  commannd prompt with Conda added to the paths so commands work.

**NOTE:** In this example, I name the new environment `arcgis`. Please feel free to use any other name you wish. This is only my convention.

### Clone `arcgispro-py3`

You can either do this in the interface, or just do it from the command line. The latter I have found to be somewhat faster, and a little more satisfying since it provides progress updates.

```
conda create -n arcgis --clone arcgispro-py3
activate arcgis
```

### Install H3-Py

Next, you need to install the H3-Py library using Conda.

```
conda install -c conda-forge h3-py
```

### Tell ArcGIS Pro to Use the New Envronment

Finally, since already in the command prompt, you can switch the ArcGIS Pro environment usin the following command.

```
proswap arcgis
```

Now, you can open up ArcGIS Pro and use this new environment with H3 available.

## Adding a Column with H3

You can quickly get the H3 index for features in a feature class by adding a new field to store these indices, and adding them using the field calculator. After adding a text field with a length of 20, you can use the field calculator to populate the H3 index values.

### Add H3 Indices with Field Calculator

In the field calculator populate the expression and code block parameters with the following.

#### Expression

This just tells ArcGIS Pro to use the custom function from the code block, and give it the geometry.

```
get_idx(!SHAPE!)
```

#### Code Block

This succicnt function uses H3-Py to retrieve the H3 index from the latitude (y-coordinate) and longitude (x-coordinate) of each feature geometry at the desired resolution.

```
import h3

h3_resolution = 7

def get_idx(geom):
    idx = h3.latlng_to_cell(geom.centroid.Y, geom.centroid.X, h3_resolution)
    return idx
```

## References 

[H3-Py](https://uber.github.io/h3-py/intro.html)