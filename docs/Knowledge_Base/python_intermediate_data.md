# ArcPy Intermediate Data

When doing creating analysis workflows using ArcPy tools, a vast majority of tools create an output dataset. These intermediate datasets, where they are stored and cleaning them following a script run, can pose challenges to repeatablity and portability of scripts. Typically you will need to manage the input and output as parameters for a script or function, but from experience, I have come up with a few strategies for handling intermediate data. These include using the `memory` workspace, and creating my own temporary file geodatabase for intermediate data with every script run.

## `memory` workspace

If the dataset is not too large, if it is small enough to fit into the memory of the instance where you are working, one of the easiest data storage locations is the `memory` workspace. Utilizing this workspace is as simple as prefixing the intermediate dataset name with `memory`. Hence, if performing a spatial overlay between address points and tract polygons to get the count, and want to name the output feature class `tract_addr_cnt`, all you need to do is create a path for output as a string`"memory/tract_addr_cnt"`.

## Using a File Geodatabase in a Temporary Directory

ArcPy does provide a temporary file geodatabase accessed through `arcpy.env.scratchGDB`. In my experience, although not frequent, this workspace can get corrupted. For this reason, I have started to utilize the Python `tempfile` module to provide an ephmerial location for storing intermediate data, with automatic script cleanup within the Python `try/except/finally` structure.

``` python
from tempfile import gettempdir
```