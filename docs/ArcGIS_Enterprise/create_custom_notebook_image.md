# Create Custom Notebook Container Image

Reference: [Build a custom container image](https://enterprise.arcgis.com/en/notebook/latest/install/windows/extend-a-notebook-runtime.htm#ESRI_SECTION1_027D1A1826A242B3BEB7F9A0166DEEEF)

## Build the Custom Image

### Get ImageID

From a administrator command prompt, use the following command to get the container image identifier to use in the next step.

``` bat
docker images
```

![Docker Images command](../assets/docker_images.png)

### Create Dockerfile

Create a custom `DOCKERFILE` following a similar template as below.

!!! note

    This file needs to be in a new empty directory. This will make the subsequent steps _much_ easier.

``` dockerfile
# starting point for new notebook image, the base arcgis-notebook-python-windows image
# this is discovered by typing `docker images` in an administrator command prompt
FROM arcgis-notebook-python-windows:11.3.0.51575

# use run to install and clean to reduce image size - using geopandas installed from conda-forge as an example
RUN conda install -c conda-forge geopandas \
    && conda clean -y -a
```

### Build the Container Image

Build the container image by running the following command from an administrator command prompt.

!!! note

    This step also installs the newly built image locally.

``` bat
docker build .
```

### Get the Python Package Manifest

Reference: [Generate a manifest file for custom and/or extended runtimes](https://support.esri.com/en-us/knowledge-base/generate-manifest-file-for-custom-extended-runtimes-000025575) (Tech Support Article)

Use the following command to get the Python Package manifest, the list of packages installed in the new custom image.

``` powershell
$ID = docker container run -d --rm -it -v /:/host <custom_runtime_image_ID>; docker exec -it $ID /opt/conda/bin/conda list --json >> ~\Desktop\manifest.json; docker kill $ID
```

## Install the Image in Notebook Server


