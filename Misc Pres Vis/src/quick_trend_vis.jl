burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using NCDatasets, PyCall, StatsBase
@pyimport cartopy.crs as ccrs
@pyimport matplotlib.pyplot as plt

include(joinpath(ERA.SCRIPTPATH, "load_era_data.jl"))

goodproj = ccrs.AlbersEqualArea(central_longitude = -147,standard_parallels = (57,69))

function theil_sen(x, y)
    idxs = eachindex(x)
    theil_slope = median((y[i]-y[j])/(x[i]-x[j]) for i in idxs for j in 1:(i-1))
    return theil_slope
end

eratime = times["Land"]
time_mask = map(t->month(t)==3 && day(t) == 31 && (Date(1979) <= t), eratime)
erasd = sds["Land"]

erasd[glacier_masks["Land"], :] .= NaN

years = year.(eratime[time_mask])
april_1st_sds = @view erasd[:,:, time_mask]

init_swe = mapslices(mean, april_1st_sds, dims=3)

erasd[init_swe .< 0.0254, :] .= NaN

function get_slope(slice)
    isnan(first(slice)) && return NaN
    return theil_sen(years, slice)
end

trends = [get_slope(@view(april_1st_sds[i,j,:])) for i in Base.axes(april_1st_sds, 1), j in Base.axes(april_1st_sds, 2)]

trends .*= length(years) ./ init_swe .* 100

mintrend = -50
maxtrend = 50

trends[trends.>maxtrend].=maxtrend
trends[trends.<mintrend].=mintrend

ax = plt.subplot(1,1,1,projection = goodproj)

lon = lons["Land"]
lat = lats["Land"]

longrid = lon .* ones(1, length(lat))
latgrid = ones(length(lon)) .* lat'

spacing = 7

pcm = ax.contourf(longrid, latgrid, trends; transform = ccrs.PlateCarree(), cmap = "coolwarm_r", levels = -55:10:55)

ax.coastlines("10m")
ax.set_title("% Change, March 31st SWE, 1979-2022 (Theil-Sen Fit)")

plt.colorbar(pcm; label = "% Change in SWE over 44 Years")

plt.savefig("foo", dpi = 400)