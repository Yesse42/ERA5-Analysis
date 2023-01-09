burrowactivate()
import ERA5Analysis as ERA
cd(@__DIR__)
using PyCall, CSV, DataFrames
@pyimport cartopy.crs as ccrs
@pyimport matplotlib.pyplot as plt

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))

const min_n_years = 20
time_filter_func(date) = month(round(date, Month(1), RoundNearestTiesUp)) == 4
const normal_period = (1991, 2020)
const eratype = "Land"

slopes(x,y,idxs) = Base.Iterators.filter(!isnan, (y[i]-y[j])/(x[i]-x[j]) for i in idxs for j in 1:(i-1))

function theil_sen(x, y; bootstrap_size  = 600, null = 0)
    length(x) ≠ length(y) && throw(ArgumentError("Bad bad bad vectors not same length why make me suffer"))
    idxs = eachindex(x)
    slope = median(slopes(x,y,idxs))
    #Too lazy to special case for even/odd
    boot_arr = Vector{typeof(first(x)/first(y))}(undef, bootstrap_size)
    boot_sample_idxs = Vector{Int}(undef, length(x))
    for i in 1:bootstrap_size
        boot_sample_idxs .= rand.(Ref(idxs))
        boot_x, boot_y = (@view(data[boot_sample_idxs]) for data in (x, y))
        boot_arr[i] = median(slopes(boot_x, boot_y, idxs))
    end
    quant = quantilerank(boot_arr, null)
    quant = min(quant, 1-quant)

    return (;slope, p_val = quant)
end

#First load in the snow course stations for the whole state 

snow_courses = CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_Metadata.csv"), DataFrame)

#Get their data, calculate years of data

function get_data_for_month(id)
    not_suitable = [missing, missing]

    id = string(id)
    data = dropmissing!(innerjoin(load_snow_course(id), load_plain_nn(eratype, id); on=:datetime))
    filter!(row->time_filter_func(row.datetime), data)
    normal_data = filter!(row-> normal_period[1] <= year(row.datetime) <= normal_period[2], data)
    length(unique(year.(normal_data.datetime))) < min_n_years && return not_suitable
    isempty(normal_data) && return not_suitable
    for col in [:era_swe, :snow_course_swe]
        data[!, col] .*= 100 / median(normal_data[!, col])
    end
    return [data[:, Not(:era_swe)], data[:, Not(:snow_course_swe)]]
end

datacols = [:snow_course, :era]

transform!(snow_courses, :ID=>ByRow(get_data_for_month)=>datacols)
dropmissing!(snow_courses, datacols)

#Calculate the trends and significance for each station

for col in datacols
    transform!(snow_courses, col=>ByRow(x->theil_sen(year.(x.datetime), Array(x[:, Not(:datetime)])))=>["$(col)_slope", "$(col)_p_val"])
end


#And then plot
goodproj = ccrs.AlbersEqualArea(central_longitude = -147, standard_parallels = (57,69))

ax = plt.subplot(1,1,1,projection = goodproj)

#Now load in the data

#Now make the plot
vmin = -(vmax = 1)
scat = ax.scatter(snow_courses.Longitude, snow_courses.Latitude, c = snow_courses.snow_course_slope, s=64; transform = ccrs.PlateCarree(), cmap="viridis", label = "Snow Course Trends", vmin, vmax, marker="o")
ax.scatter(snow_courses.Longitude, snow_courses.Latitude, c = snow_courses.era_slope, s=8; transform = ccrs.PlateCarree(), cmap="viridis", label = "ERA5 Land Trends", vmin, vmax, marker="o")
ax.set_extent(ERA.course_bounds, crs=ccrs.PlateCarree())
ax.coastlines()

ax.set_title("ERA5 Land versus April 1st Snow Course Theil Sen Trend Slopes", fontsize = 9)
plt.tight_layout()
ax.legend()
plt.colorbar(mappable=scat, ax=ax, label="Slope (% of 1991-2020 Median per year)")
plt.savefig("../vis/othervis/trend_map.png", dpi=300)
plt.close()

