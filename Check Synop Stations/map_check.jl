burrowactivate()
import ERA5Analysis as ERA
cd(@__DIR__)
using PyCall, CSV, DataFrames
@pyimport matplotlib.pyplot as plt 
@pyimport cartopy.crs as ccrs


#Set up the plot
goodproj = ccrs.AlbersEqualArea(central_longitude = -147,
standard_parallels = (57,69))

ax = plt.subplot(1,1,1,projection = goodproj)

#Now load in the data
stations = CSV.read("era5_us_snow_stations_1979-2021_new.csv", DataFrame)
filter!(x->x["mean(lat)"]>50, stations)
latlonnames = ["mean(lat)", "mean(lon)"]
stations = combine(groupby(stations, "statid@hdr"), latlonnames.=>first.=>["lat", "lon"], "count(1)"=>sum=>"n_obs", nrow=>"n_years")

#Now load in the snotel data too
station_data = CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "Metadata.csv"), DataFrame)
snotel_data = filter!(x->x.Network == "SNOTEL", station_data)

#Now make the plot
scat = ax.scatter(stations.lon, stations.lat, c = stations.n_years; transform = ccrs.PlateCarree(), cmap="nipy_spectral", label = "SYNOP Stations")
ax.scatter(snotel_data.Longitude, snotel_data.Latitude, c="gray", s=5; transform = ccrs.PlateCarree(), label = "SNOTELs")
ax.set_extent(ERA.ak_bounds, crs=ccrs.PlateCarree())
ax.gridlines()
ax.coastlines()

ax.set_title("Synop and SNOTEL Stations")
plt.tight_layout()
ax.legend()
plt.colorbar(mappable=scat, ax=ax, label="Years of Data")
plt.savefig("synop_station_vis.png")
plt.close()