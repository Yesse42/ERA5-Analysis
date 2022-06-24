cd(@__DIR__); cd("..")
#This script will visualize the topography around the station, showcasing the 9 nearby ERA5 base and ERA5 land points, the true station location,
#and the discrepancy between the elevations of the chosen ERA5 points and the actual station elevation.

#Load in the latitude, longitude, elevation, and make a glacier mask for the points nearest to every station

datadir="data/"

files = ["../../Base/ERA5-SD-1979-2022-CREATE-2022-06-16.nc", "../../Land/ERA5-Land-SD-1979-2022-DL-2022-6-15.nc"]

geofiles = "../data/".*["base","land"].*"_geopotentials.nc"

using Plots, CSV, NCDatasets, DataFrames, Proj
pyplot()

#Load the nearest neighbor ids, the geopotential arrays, and the latitude and longitude arrays, along with the snow depth array for a glacier mask
gravity = 9.80665
datasets = Dataset.(files, "r")
geosets = Dataset.(geofiles, "r")
times = [Hour.(ds["time"][:]) .+ DateTime(1900,1,1) for ds in datasets]
lats = [ds["latitude"][:] for ds in datasets]
lons = [ds["longitude"][:] for ds in datasets]
sds = [ds["sd"][:] for ds in datasets]
geolats = [gds["latitude"][:] for gds in geosets]
geolons = [gds["longitude"][:] for gds in geosets]

elevneighbors = CSV.read("../data/"*name*"_nearby_point_idx.csv", DataFrame)
sdneighbors = CSV.read("../data/"*name*"_true_nearest_neighbor.csv", DataFrame)

lonlatgrid = tuple.(lat', lonlat)

