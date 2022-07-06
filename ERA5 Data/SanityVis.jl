using Proj, NCDatasets, Dates
cd(@__DIR__);
cd("..");

trans = Proj.Transformation("EPSG:4326", "+proj=stere +lat_0=63 +lon_0=-150")

land_data = Dataset("ERA5 Data/Land/ERA5-Land-SD-1979-2022-DL-2022-6-15.nc", "r")
sd = land_data["sd"][:]
lat = land_data["latitude"][:]
lon = land_data["longitude"][:]
time = DateTime(1900) + Hour.(land_data["time"][:])

#Transform with projection
projectedcoords = trans.(tuple.(lat, lon'))
x, y = first.(projectedcoords), last.(projectedcoords)

sd = permutedims(sd, (2, 1, 3))

close(land_data)
name = "ERA5 Data/plotdata.nc"
if isfile(name)
    rm(name)
end
plotdata = Dataset(name, "c")
defDim(plotdata, "row", size(x, 1))
defDim(plotdata, "column", size(x, 2))
defDim(plotdata, "time", size(sd, 3))
defVar(plotdata, "sd", sd, ("row", "column", "time"))
defVar(plotdata, "time", time, ("time",))
defVar(plotdata, "x", x, ("row", "column"))
defVar(plotdata, "y", y, ("row", "column"))
close(plotdata)
