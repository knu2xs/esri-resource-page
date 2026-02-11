# Accessing Esri Software from Ubuntu (Internal Esri Network)

## Install Required Package

Install CIFS utilities to mount network shares:

``` bash
sudo apt install cifs-utils -y
```

## Create Mount Point

Create a directory where the network share will be mounted:

``` bash
sudo mkdir -p /mnt/software
```

## Mount the Network Drive

Mount the Esri software share (you'll be prompted for your password):

``` bash
sudo mount -t cifs //RED-INF-DCT-P05.esri.com/software/Esri/Released /mnt/software -o username=YOUR_USERNAME,domain=ESRI
```

Replace `YOUR_USERNAME` with your Esri username (without @esri.com). You'll be prompted to enter your password.

## Access the Software

Browse the mounted share:

``` bash
ls /mnt/software
```

## Unmount When Done

When finished, unmount the drive:

``` bash
sudo umount /mnt/software
```
