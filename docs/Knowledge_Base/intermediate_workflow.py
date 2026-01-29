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
    tmp_gdb = arcpy.management.MakeFileGDB(
        output_folder=tmp_dir,
        output_name='tmp.gdb'
    )[0]

    return tmp_gdb


# within the try block, create the the temporary file geodatabase and use it for analysis
try:

    # get the scratch gdb
    scratch_gdb = get_tmp_fgdb()

    # perform spatial overlay to get count of points per tract - putting output into temp file geodatabase

    # create output file geodatabase if it does not already exist

    # 

# if an error occurs, raise it
except Exception as e:
    raise

# clean up temporary data whether or not an error occurred
finally:
    # first, delete the file geodatabase using arcpy - this avoids some errors due to hanging schema locks
    arcpy.management.Delete(scratch_gdb)

    # next clean up the temporary directory and anything left in it
    shutil.rmtree(os.path.dirname(scratch_gdb), ignore_errors=True)
