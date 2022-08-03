burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using NCDatasets, PyCall, Dates
@pyimport matplotlib.pyplot as plt
@pyimport cartopy.crs as ccrs

eratype = "Land"
mytime = DateTime(2022, 3, 30, 12)
erafile = ERA.erafiles[2]

isglacier(sds) = mapslices(slice->all((x->ismissing(x) || x>0).(slice)) || any(slice .>= 10), sds, dims = 3)[:,:]

eradata = Dataset(joinpath(ERA.ERA5DATA, eratype, erafile))
times = DateTime.(eradata["time"][:])
time_idx = argmin(abs.(Dates.value.(times) .- Dates.value.(mytime)))
eratime = Date(times[time_idx])
sd = eradata["sd"][:,:, time_idx]
mask = isglacier(eradata["sd"][:])
sd[mask] .= NaN
sd .*= ERA.meter_to_inch
max_swe = 20
sd[sd.>max_swe] .= max_swe
lon, lat = getindex.(getindex.(Ref(eradata), ("longitude","latitude")), :)
longrid = lon .* ones(1, length(lat))
latgrid = lat' .* ones(length(lon))

fig = plt.figure()
goodproj = ccrs.AlbersEqualArea(central_longitude = -147, standard_parallels = (57, 69))

ax = fig.add_subplot(1, 1, 1; projection = goodproj)

ax.set_extent(ERA.ak_bounds)
ax.set_title("ERA5 Land SWE, $eratime")
ax.set_xticks([])
ax.set_yticks([])
ax.grid()
ax.set_facecolor("grey")
ax.coastlines("10m")

cf = ax.pcolormesh(longrid, latgrid, sd; transform = ccrs.PlateCarree(), cmap = "Blues_r")
fig.colorbar(cf, label = "SWE (in)")

fig.savefig("../vis/swe_vis.png", dpi = 300)
fig.close()

