import os.path
import shutil
import tempfile

import arcpy

# script constants
INPUT_POINTS = r'D:\data\raw\address.gdb\address_points'
INPUT_TRACTS = r'D:\data\raw\census.gdb\tracts'
OUTPUT_DIR = r'D:\data\output\final.gdb'


def get_tmp_fgdb() -> str:
    """Get a file geodatabase to use for intermediate data."""
        # create temporary directory
    tmp_dir = tempfile.mkdtemp()

    # create temporary file geodatabase in temporary directory to use for intermediate data
    tmp_gdb = arcpy.management.MakeFileGDB(out_folder_path=tmp_dir, out_name='temp_data.gdb')[0]

    return tmp_gdb


# within the try block, create the the temporary file geodatabase and use it for analysis
try:

    # get the scratch gdb
    scratch_gdb = get_tmp_fgdb()

    # perform spatial overlay to get count of points per tract - putting output into temp file geodatabase
    points_per_tract = arcpy.analysis.SpatialJoin(
        target_features=INPUT_TRACTS,
        join_features=INPUT_POINTS,
        out_feature_class=os.path.join(scratch_gdb, 'points_per_tract'),
        match_option='INTERSECT',
        join_type='KEEP_ALL',
    )[0]

    # create output file geodatabase if it does not already exist
    if not arcpy.Exists(OUTPUT_DIR):
        arcpy.management.CreateFileGDB(
            out_folder_path=os.path.dirname(OUTPUT_DIR),
            out_name=os.path.basename(OUTPUT_DIR)
        )

    # create the field mapping to rename the Join_Count field to tract_addr_count and keep the other fields inherited from tracts as is
    field_mappings = arcpy.FieldMappings()
    field_mappings.addTable(points_per_tract)
    join_count_index = field_mappings.findFieldMapIndex('Join_Count')
    join_count_field_map = field_mappings.getFieldMap(join_count_index)
    join_count_field_map.outputField.name = 'tract_addr_count'
    field_mappings.replaceFieldMap(join_count_index, join_count_field_map)

    # use feature class to feature class to copy features from temporary gdb to final output gdb, renaming the spatial join count to tract_addr_count
    arcpy.conversion.FeatureClassToFeatureClass(
        in_features=points_per_tract,
        out_path=OUTPUT_DIR,
        out_name='tracts_with_address_counts',
        field_mapping=field_mappings
    )

# if an error occurs, raise it
except Exception as e:
    raise

# clean up temporary data whether or not an error occurred
finally:
    # first, delete the file geodatabase using arcpy - this avoids some errors due to hanging schema locks
    arcpy.management.Delete(scratch_gdb)

    # next clean up the temporary directory and anything left in it
    shutil.rmtree(os.path.dirname(scratch_gdb), ignore_errors=True)
