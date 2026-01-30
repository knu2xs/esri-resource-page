# ArcPy Intermediate Data

When scripting analysis workflows using ArcPy, most tools create output datasets. Managing these intermediate datasets—where they're stored and how to clean them up—can pose challenges to script repeatability and portability.

This guide covers two strategies for handling intermediate data:

1. **Memory workspace** – Fast, simple, but limited by available RAM
2. **Temporary file geodatabase** – More robust, with automatic cleanup

---

## Option 1: Memory Workspace

**Reference:** [Write geoprocessing output to memory—ArcGIS Pro](https://pro.arcgis.com/en/pro-app/latest/help/analysis/geoprocessing/basics/the-in-memory-workspace.htm)

For smaller datasets fiting into memory, using the `memory` workspace is by far the simplest approach. Just prefix your output dataset name with `memory/`:

```python
out_feature_class = "memory/output_dataset"
```

### Example

```python
import os.path
import arcpy

# Script constants
INPUT_POINTS = r'D:\data\raw\address.gdb\address_points'
INPUT_TRACTS = r'D:\data\raw\census.gdb\tracts'
OUTPUT_FEATURES = r'D:\data\output\final.gdb\tracts_with_counts'

# Perform spatial join, storing result in memory
points_per_tract = arcpy.analysis.SpatialJoin(
    target_features=INPUT_TRACTS,
    join_features=INPUT_POINTS,
    out_feature_class='memory/points_per_tract',
    match_option='INTERSECT',
    join_type='KEEP_ALL',
)[0]

# Rename Join_Count field to tract_addr_count
field_mappings = arcpy.FieldMappings()
field_mappings.addTable(points_per_tract)
join_count_index = field_mappings.findFieldMapIndex('Join_Count')
join_count_field_map = field_mappings.getFieldMap(join_count_index)
join_count_field_map.outputField.name = 'tract_addr_count'
field_mappings.replaceFieldMap(join_count_index, join_count_field_map)

# Validate output geodatabase exists
if not arcpy.management.Exists(os.path.dirname(OUTPUT_FEATURES)):
    raise FileNotFoundError(f'Output geodatabase does not exist: {os.path.dirname(OUTPUT_FEATURES)}')

# Export to final location
arcpy.conversion.FeatureClassToFeatureClass(
    in_features=points_per_tract,
    out_path=os.path.dirname(OUTPUT_FEATURES),
    out_name=os.path.basename(OUTPUT_FEATURES),
    field_mapping=field_mappings
)
```

---

## Option 2: Temporary File Geodatabase

ArcPy provides `arcpy.env.scratchGDB` for temporary data. However, I have occasionally encountered issues with this scratch file geodatabase becoming corrupted, and interrupting my scripts, especially those I have set up as scheduled tasks. A more reliable approach I have discovered uses  Python's `tempfile` module to create an ephemeral directory with Python's `try / except / finally` structure for automatic cleanup. 

**References:**

- [`tempfile.gettempdir`](https://docs.python.org/3/library/tempfile.html#tempfile.gettempdir)
- [`try / except / finally`](https://docs.python.org/3/reference/compound_stmts.html#try)
- [`arcpy.env.scratchGDB`](https://pro.arcgis.com/en/pro-app/latest/tool-reference/environment-settings/scratch-gdb.htm)

### Example: Inline Approach

```python
import os.path
import shutil
import tempfile
import arcpy

INPUT_POINTS = r'D:\data\raw\address.gdb\address_points'
INPUT_TRACTS = r'D:\data\raw\census.gdb\tracts'
OUTPUT_FEATURES = r'D:\data\output\final.gdb\tracts_with_counts'

try:
    # Create temporary directory and geodatabase
    tmp_dir = tempfile.mkdtemp()
    tmp_gdb = arcpy.management.CreateFileGDB(out_folder_path=tmp_dir, out_name='temp_data.gdb')[0]

    with arcpy.EnvManager(workspace=tmp_gdb):
        # spatial join creating intermediate data
        points_per_tract = arcpy.analysis.SpatialJoin(
            target_features=INPUT_TRACTS,
            join_features=INPUT_POINTS,
            out_feature_class='points_per_tract',
            match_option='INTERSECT',
            join_type='KEEP_ALL',
        )[0]

        # Rename field
        field_mappings = arcpy.FieldMappings()
        field_mappings.addTable(points_per_tract)
        join_count_index = field_mappings.findFieldMapIndex('Join_Count')
        join_count_field_map = field_mappings.getFieldMap(join_count_index)
        join_count_field_map.outputField.name = 'tract_addr_count'
        field_mappings.replaceFieldMap(join_count_index, join_count_field_map)

        # Validate and export
        if not arcpy.management.Exists(os.path.dirname(OUTPUT_FEATURES)):
            raise FileNotFoundError(f'Output geodatabase does not exist: {os.path.dirname(OUTPUT_FEATURES)}')

        # creating permanant output data
        arcpy.conversion.FeatureClassToFeatureClass(
            in_features=points_per_tract,
            out_path=os.path.dirname(OUTPUT_FEATURES),
            out_name=os.path.basename(OUTPUT_FEATURES),
            field_mapping=field_mappings
        )

# still raise any errors encountered - facilitates debugging
except Exception:
    raise

# whether the script runs or encounters errors, clean up temporary data created
finally:
    # delete geodatabase first to release any potential schema locks
    arcpy.management.Delete(tmp_gdb)
    shutil.rmtree(tmp_dir, ignore_errors=True)
```

---

### Example: Reusable Decorator

Wrapping the above pattern in a reusable decorator makes this paradim much more reusuable. To take advantage of the temporary file geodatabase, all you have to do is apply the `@with_temp_fgdb` decorator to any ArcPy spatial analysis function.

**References:**

- [`functools.wraps`](https://docs.python.org/3/library/functools.html#functools.wraps)
- [`pathlib.Path`](https://docs.python.org/3/library/pathlib.html)

!!! tip

    ArcPy doesn't accept `Path` objects directly. Consequently, you must convert them to strings first.

    ```python
    arcpy.DoSomething(str(path_object))
    ```

```python
import shutil
import tempfile
from functools import wraps
from pathlib import Path
from typing import Any, Callable, Union

import arcpy


def with_temp_fgdb(func: Callable) -> Callable:
    """
    ## Temporary File Geodatabase Decorator

    This decorator function creates and manages a temporary file geodatabase that can be used to store intermediate data during geoprocessing operations.

    ### Purpose

    When performing complex geoprocessing workflows in ArcGIS/ArcPy, intermediate results often need to be stored temporarily before producing final outputs.
    
    This decorator:

    1. **Creates a temporary workspace** - Automatically generates a temporary file geodatabase before the decorated function executes
    2. **Provides the path** - Passes the geodatabase path to the decorated function so it can write intermediate feature classes, tables, or rasters
    3. **Handles cleanup** - Automatically deletes the temporary geodatabase and all its contents after the function completes (whether successful or not)

    ### Benefits

    - **Prevents workspace clutter** - No leftover temporary files in your project directories
    - **Automatic resource management** - No need to manually create/delete temp workspaces
    - **Exception safety** - Cleanup occurs even if the function raises an error
    - **Reusable pattern** - Can be applied to any function needing temporary storage

    ### Typical Use Case

    Useful when a geoprocessing workflow requires multiple steps where intermediate outputs from one tool become inputs to another, but those intermediate outputs are not needed in the final result.
    """

    # @wraps preserves the original function's metadata (name, docstring, etc.) when creating the wrapper
    @wraps(func)
    def wrapper(*args, **kwargs) -> Any:
    
        # create the temporary directory and file geodatabase
        tmp_dir = tempfile.mkdtemp()
        tmp_gdb = arcpy.management.CreateFileGDB(out_folder_path=tmp_dir, out_name='temp_data.gdb')[0]

        # use the try block to invoke the wrapped function
        try:

            # set the workspace to the temporary file geodatabase so any intermediate datasets are cleaned up
            with arcpy.EnvManager(workspace=tmp_gdb):
                return func(*args, **kwargs)

        # still raise exceptions so errors can be debugged
        except Exception:
            raise

        # clean up intermediate data, even if errors are encountered
        finally:
            arcpy.management.Delete(tmp_gdb)
            shutil.rmtree(tmp_dir, ignore_errors=True)

    return wrapper


@with_temp_fgdb
def perform_analysis(
    input_points: Union[str, Path],
    input_tracts: Union[str, Path],
    output_features: Union[str, Path]
) -> Path:
    """
    Perform spatial analysis with automatic intermediate data cleanup. If copying this script, customize this function to do your spatial analysis.

    Args:
        input_points: Path to input point features.
        input_tracts: Path to input tract features.
        output_features: Path for output feature class.

    Returns:
        Path to the output feature class.
    """
    # Normalize paths
    input_points = str(input_points)
    input_tracts = str(input_tracts)
    output_features = Path(output_features)

    # Spatial join
    points_per_tract = arcpy.analysis.SpatialJoin(
        target_features=input_tracts,
        join_features=input_points,
        out_feature_class='points_per_tract',
        match_option='INTERSECT',
        join_type='KEEP_ALL',
    )[0]

    # Rename field
    field_mappings = arcpy.FieldMappings()
    field_mappings.addTable(points_per_tract)
    join_count_index = field_mappings.findFieldMapIndex('Join_Count')
    join_count_field_map = field_mappings.getFieldMap(join_count_index)
    join_count_field_map.outputField.name = 'tract_addr_count'
    field_mappings.replaceFieldMap(join_count_index, join_count_field_map)

    # make sure the output file geodatabase exists as a directory
    if not arcpy.management.Exists(str(output_features.parent)):
        raise FileNotFoundError(f'Output geodatabase does not exist: {output_features.parent}')

    # describe and ensure the file geodatbase directory is a valid and non-corrupted file geodatabase
    desc = arcpy.Describe(str(output_features.parent))
    if desc.dataType != 'Workspace' or desc.workspaceType != 'LocalDatabase':
        raise ValueError(f'Output path is not a valid file geodatabase: {output_features.parent}')

    # create output features
    arcpy.conversion.FeatureClassToFeatureClass(
        in_features=points_per_tract,
        out_path=str(output_features.parent),
        out_name=output_features.name,
        field_mapping=field_mappings
    )

    return output_features


if __name__ == '__main__':

    # call spatial analysis function
    perform_analysis(
        input_points=r'D:\data\raw\address.gdb\address_points',
        input_tracts=r'D:\data\raw\census.gdb\tracts',
        output_features=r'D:\data\output\final.gdb\tracts_with_address_counts'
    )
```

!!! tip
    When a tool requires separate geodatabase and feature class name parameters, use `arcpy.env.workspace` for the geodatabase:

    ```python
    arcpy.management.CreateFeatureclass(
        out_path=arcpy.env.workspace,
        out_name="feature_class_name"
    )
    ```

    This works because the `@with_temp_fgdb` decorator sets the workspace to the temporary geodatabase using `arcpy.EnvManager(workspace=tmp_gdb)` before calling the wrapped spatial analysis function. Any code inside the decorated spatial analysis function can reference `arcpy.env.workspace` to get the path to this temporary geodatabase.
