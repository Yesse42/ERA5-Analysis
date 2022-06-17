using Proj, NCDatasets, Dates

trans = Proj.Transformation("EPSG:4326", "+proj=aea +lat_1=58 +lat_2=70 +lon_0=-150")

land_data = Dataset("Land/ERA5-Land-SD-1979-2022-DL-2022-6-15.nc", "r")
sd = land_data["sd"][:]
lat = land_data["latitude"][:]
lon = land_data["longitude"][:]
time = DateTime(1900) + Hour.(land_data["time"][:])

lonlatgrid = tuple.(lat, lon')

#Transform with projection
projectedcoords = trans.(lonlatgrid)
x , y = first.(projectedcoords), last.(projectedcoords)

close(land_data)

using Plots
pyplot()

plotdata = sd

anim = @animate for timeid in axes(plotdata, 3)
    contourf(x,y, plotdata[:,:,timeid]')
end

gif(anim, "ERA5-Land.mp4", fps=30)
