import os

#os.chdir("/import/FIREICE/fiboreal/data/cds/reanalysis-era5-land/sd")
os.chdir("/Users/jerobinett/Desktop/Hollings Omni-Folder/ERA5 Data/Land")

files = [f for f in os.listdir(".") if os.path.isfile(f) and "adaptor" in f]

import netCDF4 as cdf
import numpy as np
import datetime as dt

for file in files:
    rootgrp = cdf.Dataset(file, "r")
    times = rootgrp.variables["time"][:]
    minyear = times.min()
    maxyear = times.max()
    epochstart = dt.datetime(1900,1,1)
    minyear = (epochstart+dt.timedelta(hours=int(minyear))).year
    maxyear = (epochstart+dt.timedelta(hours=int(maxyear))).year
    
    newname = "ERA5-Land-sd-{}-{}.nc".format(minyear, maxyear)
    os.rename(file, newname)