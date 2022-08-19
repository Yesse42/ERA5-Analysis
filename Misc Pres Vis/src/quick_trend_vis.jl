burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using NCDatasets, PyCall, StatsBase, DataFrames
@pyimport cartopy.crs as ccrs
@pyimport matplotlib.pyplot as plt

include(joinpath(ERA.SCRIPTPATH, "load_era_data.jl"))

goodproj = ccrs.AlbersEqualArea(central_longitude = -147,standard_parallels = (57,69))

function theil_sen(x, y)
    idxs = eachindex(x)
    theil_slope = median((y[i]-y[j])/(x[i]-x[j]) for i in idxs for j in 1:(i-1))
    return (;theil_slope, intercept = median(b - theil_slope .* a for (a,b) in zip(x,y)))
end

eratime = times["Land"]
time_mask = map(t->month(t)==4 && (Date(1979) <= t), eratime)
erasd = sds["Land"]

erasd[glacier_masks["Land"], :] .= NaN

years = year.(eratime[time_mask])
april_sds = @view erasd[:,:, time_mask]

data = DataFrame(datetime = years, sd = [@view(april_sds[:,:,i]) for i in Base.axes(april_sds, 3)])

data = groupby(data, :datetime)

function mysum(arr)
    init = zeros(size(first(arr)))
    for A in arr
        init .+= A
    end
    return init
end

april_average_slice = combine(data, :sd=>(x->Ref(mysum(x) ./ length(x)))=>:sd)

sort!(april_average_slice, :datetime)

april_average_sds = reduce((x...)->cat(x...;dims=3), april_average_slice.sd)

datayears = april_average_slice.datetime

function get_slope(slice)
    isnan(first(slice)) && return (theil_slope = NaN, intercept = NaN)
    return theil_sen(datayears, slice)
end

slopes_intercepts = [get_slope(@view(april_average_sds[i,j,:])) for i in Base.axes(april_average_sds, 1), j in Base.axes(april_average_sds, 2)]

trends = getproperty.(slopes_intercepts, :theil_slope)

intercepts = getproperty.(slopes_intercepts, :intercept)

init_swe = first(datayears) .* trends .+ intercepts

trends[init_swe .< 0.0254] .= NaN

trends .*= length(datayears) ./ init_swe .* 100

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
ax.set_title("% Change, April SWE, 1979-2021 (Theil-Sen Fit)")

plt.colorbar(pcm; label = "% Change in SWE over 44 Years")

plt.savefig("foo", dpi = 400)