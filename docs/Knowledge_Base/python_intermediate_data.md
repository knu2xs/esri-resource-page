# ArcPy Intermediate Data

When doing creating analysis workflows using ArcPy tools, a vast majority of tools create an output dataset. These intermediate datasets, where they are stored and cleaning them following a script run, can pose challenges to repeatablity and portability of scripts. 

Typically, when scripting a workflow, you will need to manage the input and output as parameters for a script or function. The intermediate data created, data needed in between steps in the analysis workflow, from experience, I have come up with a few strategies for handling this intermediate data. These strategies include using the `memory` workspace, and creating my own temporary file geodatabase for intermediate data with every script run.

## `memory` workspace

Reference: [Write geoprocessing output to memory—ArcGIS Pro](https://pro.arcgis.com/en/pro-app/latest/help/analysis/geoprocessing/basics/the-in-memory-workspace.htm)

If the dataset is not too large, if it is small enough to fit into the memory of the instance where you are working, by far the easiest intermediate data storage locations is the `memory` workspace. Utilizing this workspace is as simple as prefixing the intermediate dataset name with `memory`. Hence, if performing a spatial overlay between address points and tract polygons to get the count, and want to name the output feature class `tract_addr_cnt`, all you need to do is create a path for output as a string`"memory/tract_addr_cnt"`.

``` python
import os.path

import arcpy

# script constants
INPUT_POINTS = r'D:\data\raw\address.gdb\address_points'
INPUT_TRACTS = r'D:\data\raw\census.gdb\tracts'
OUTPUT_FEATURES = r'D:\data\output\final.gdb'

# perform spatial overlay to get count of points per tract - putting output into temp file geodatabase
points_per_tract = arcpy.analysis.SpatialJoin(
    target_features=INPUT_TRACTS,
    join_features=INPUT_POINTS,
    out_feature_class='workspace/points_per_tract',  # using memory workspace
    match_option='INTERSECT',
    join_type='KEEP_ALL',
)[0]

# create the field mapping to rename the Join_Count field to tract_addr_count and keep the other fields inherited from tracts as is
field_mappings = arcpy.FieldMappings()
field_mappings.addTable(points_per_tract)
join_count_index = field_mappings.findFieldMapIndex('Join_Count')
join_count_field_map = field_mappings.getFieldMap(join_count_index)
join_count_field_map.outputField.name = 'tract_addr_count'
field_mappings.replaceFieldMap(join_count_index, join_count_field_map)

# ensure output file geodatabase exists
if not arcpy.management.Exists(os.path.dirname(OUTPUT_FEATURES)):
    raise FileNotFoundError(f'Output geodatabase does not exist: {os.path.dirname(OUTPUT_FEATURES)}')

# use feature class to feature class to copy features from temporary gdb to final output gdb, renaming the spatial join count to tract_addr_count
arcpy.conversion.FeatureClassToFeatureClass(
    in_features=points_per_tract,
    out_path=os.path.dirname(OUTPUT_FEATURES),
    out_name=os.path.basename(OUTPUT_FEATURES),
    field_mapping=field_mappings
)
```


## Using a File Geodatabase in a Temporary Directory

ArcPy does provide a temporary file geodatabase accessed through `arcpy.env.scratchGDB`. In my experience, although not frequent, this workspace _can get corrupted_. For this reason, I have started to utilize the Python `tempfile` module to provide an ephmerial location for storing intermediate data, with automatic script cleanup within the Python `try/except/finally` structure.

References:

- [`tempfile,gettempdir`](https://docs.python.org/3/library/tempfile.html#tempfile.gettempdir)
- [try/except/finally](https://docs.python.org/3/reference/compound_stmts.html#try)
- [`arcpy.env.scratchGDB`](https://pro.arcgis.com/en/pro-app/latest/tool-reference/environment-settings/scratch-gdb.htm)

### Example with Logic Embedded

In this example, we perform a spatial overlay to get the count of address points within census tracts, storing intermediate data in a temporary file geodatabase created in a temporary directory. Finally, we clean up the temporary data whether or not an error occurs. The logic for creating the temporary file geodatabase is part of the flow of the script.

References:

- [arcpy.env.workspace](https://pro.arcgis.com/en/pro-app/latest/tool-reference/environment-settings/current-workspace.htm)
- [arcpy.EnvManager](https://pro.arcgis.com/en/pro-app/latest/arcpy/classes/envmanager.htm)

``` python
import os.path
import shutil
import tempfile

import arcpy

# script constants
INPUT_POINTS = r'D:\data\raw\address.gdb\address_points'
INPUT_TRACTS = r'D:\data\raw\census.gdb\tracts'
OUTPUT_FEATURES = r'D:\data\output\final.gdb'

# within the try block, create the the temporary file geodatabase and use it for analysis
try:

    # create temporary directory
    tmp_dir = tempfile.mkdtemp()

    # create temporary file geodatabase in temporary directory to use for intermediate data
    tmp_gdb = arcpy.management.MakeFileGDB(out_folder_path=tmp_dir, out_name='temp_data.gdb')[0]

    # set the arcpy workspace to the temporary file geodatabase so intermediate data is stored there
    with arcpy.EnvManager(workspace=tmp_gdb):

        # perform spatial overlay to get count of points per tract - putting output into temp file geodatabase
        points_per_tract = arcpy.analysis.SpatialJoin(
            target_features=INPUT_TRACTS,
            join_features=INPUT_POINTS,
            out_feature_class='points_per_tract',
            match_option='INTERSECT',
            join_type='KEEP_ALL',
        )[0]

        # create the field mapping to rename the Join_Count field to tract_addr_count and keep the other fields inherited from tracts as is
        field_mappings = arcpy.FieldMappings()
        field_mappings.addTable(points_per_tract)
        join_count_index = field_mappings.findFieldMapIndex('Join_Count')
        join_count_field_map = field_mappings.getFieldMap(join_count_index)
        join_count_field_map.outputField.name = 'tract_addr_count'
        field_mappings.replaceFieldMap(join_count_index, join_count_field_map)

        # ensure output file geodatabase exists
        if not arcpy.management.Exists(os.path.dirname(OUTPUT_FEATURES)):
            raise FileNotFoundError(f'Output geodatabase does not exist: {os.path.dirname(OUTPUT_FEATURES)}')

        # use feature class to feature class to copy features from temporary gdb to final output gdb, renaming the spatial join count to tract_addr_count
        arcpy.conversion.FeatureClassToFeatureClass(
            in_features=points_per_tract,
            out_path=os.path.dirname(OUTPUT_FEATURES),
            out_name=os.path.basename(OUTPUT_FEATURES),
            field_mapping=field_mappings
        )

# if an error occurs, raise it
except Exception as e:
    raise

# clean up temporary data whether or not an error occurred
finally:
    # first, delete the file geodatabase using arcpy - this avoids some errors due to hanging schema locks
    arcpy.management.Delete(tmp_gdb)

    # next clean up the temporary directory and anything left in it
    shutil.rmtree(tmp_dir, ignore_errors=True)
```

### As a Decorator

For reusability, you can also create a decorator to handle the temporary file geodatabase creation and cleanup. In this example, the decorator `with_temp_fgdb` creates a temporary file geodatabase, sets it as the workspace for the decorated function, and cleans up afterward.

References:
- [`functools.wraps`]
- [`pathlib.Path`]

!!! note
    This example uses type hints and the `Path` class from the `pathlib` module for improved code clarity. Make sure to import `Union` and `Path` from the `typing` and `pathlib` modules respectively if you use this code.

``` python
import os.path
import shutil
import tempfile
from functools import wraps

import arcpy


# script constants - easily parameterized using sys.argv
INPUT_POINTS = r'D:\data\raw\address.gdb\address_points'
INPUT_TRACTS = r'D:\data\raw\census.gdb\tracts'
OUTPUT_FEATURES = r'D:\data\output\final.gdb\tracts_with_address_counts'


def with_temp_fgdb(func):
    """Decorator to provide a temporary file geodatabase for intermediate data."""
    @wraps(func)
    def wrapper(*args, **kwargs):
        # create temporary directory
        tmp_dir = tempfile.mkdtemp()

        # create temporary file geodatabase in temporary directory to use for intermediate data
        tmp_gdb = arcpy.management.MakeFileGDB(out_folder_path=tmp_dir, out_name='temp_data.gdb')[0]

        try:
            # execute the decorated function with the temporary geodatabase set as the workspace
            with arcpy.EnvManager(workspace=tmp_gdb):
                return func(*args, **kwargs)

        # make sure to raise any exceptions encountered
        except Exception as e:
            raise

        # clean up temporary data whether or not an error occurred
        finally:
            # first, delete the file geodatabase using arcpy - this avoids some errors due to hanging schema locks
            arcpy.management.Delete(tmp_gdb)

            # next clean up the temporary directory and anything left in it
            shutil.rmtree(tmp_dir, ignore_errors=True)

    return wrapper


@with_temp_fgdb
def perform_analysis(
    input_points: Union[arcpy._mp.FeatureLayer, Path, str], 
    input_tracts: Union[arcpy._mp.FeatureLayer, Path, str], 
    output_features: Union[Path, str]
) -> Path:
    """
    Perform analysis using a temporary file geodatabase for intermediate data.

    Args:
        input_points: The input point features as a FeatureLayer, Path, or string.
        input_tracts: The input tract features as a FeatureLayer, Path, or string.
        output_features: The output feature class path as a Path.

    Returns:
        The path to the output feature class.
    """
    # ensure input feature parameter Paths are strings
    input_points = str(input_points) if isinstance(input_points, Path) else input_points
    input_tracts = str(input_tracts) if isinstance(input_tracts, Path) else input_tracts

    # ensure output feature parameter is a Path
    output_features = Path(output_features) if isinstance(output_features, str) else output_features

    # perform spatial overlay to get count of points per tract - putting output into temp file geodatabase
    points_per_tract = arcpy.analysis.SpatialJoin(
        target_features=input_tracts,
        join_features=input_points,
        out_feature_class='points_per_tract',
        match_option='INTERSECT',
        join_type='KEEP_ALL',
    )[0]

    # create the field mapping to rename the Join_Count field to tract_addr_count and keep the other fields inherited from tracts as is
    field_mappings = arcpy.FieldMappings()
    field_mappings.addTable(points_per_tract)
    join_count_index = field_mappings.findFieldMapIndex('Join_Count')
    join_count_field_map = field_mappings.getFieldMap(join_count_index)
    join_count_field_map.outputField.name = 'tract_addr_count'
    field_mappings.replaceFieldMap(join_count_index, join_count_field_map)

    # ensure output file geodatabase exists
    if not arcpy.management.Exists(str(output_features.parent)):
        raise FileNotFoundError(f'Output geodatabase does not exist: {output_features.parent}')

    # ensure output file geodatabase is a valid file geodatabase
    desc = arcpy.Describe(str(output_features.parent))
    if desc.dataType != 'Workspace' or desc.workspaceType != 'FileSystem' or not desc.isFileGDB:
        raise ValueError(f'Output geodatabase is not a valid file geodatabase: {output_features.parent}')

    # use feature class to feature class to copy features from temporary gdb to final output gdb, renaming the spatial join count to tract_addr_count
    arcpy.conversion.FeatureClassToFeatureClass(
        in_features=points_per_tract,
        out_path=str(output_features.parent),  # has to be a string for arcpy
        out_name=output_features.name,
        field_mapping=field_mappings
    )

    return output_features

# execute the analysis
if __name__ == '__main__':

    perform_analysis(
        input_points=INPUT_POINTS, 
        input_tracts=INPUT_TRACTS, 
        output_features=OUTPUT_FEATURES
    )
```
