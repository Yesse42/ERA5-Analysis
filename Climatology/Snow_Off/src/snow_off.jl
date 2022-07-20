using CSV, DataFrames, Dates, Dictionaries, JLD2, NCDatasets, StatsBase, RecursiveArrayTools
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

include("snow_off_single_year.jl")

na_or_miss(x) = ismissing(x) || isnan(x)

using Plots
pyplot()

for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    ds = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
    sd = ds["sd"][:]
    time = ds["time"][:]
    lon = ds["longitude"][:]
    lat = ds["latitude"][:]

    sd[ismissing.(sd)] .= NaN

    lonlat = tuple.(lon, lat')
    longrid, latgrid = first.(lonlat), last.(lonlat)
    years = nothing

    #Also plot basin averages
    basin_snowoff = Dictionary()
    for basin in ERA.basin_names
        basinidxdir = joinpath(ERA.ERA5DATA, "basin_extractions", eratype)
        basin_idx_df = CSV.read(joinpath(basinidxdir, "$(basin)_era_points.csv"), DataFrame)
        basin_idxs = CartesianIndex.(basin_idx_df.lonidx, basin_idx_df.latidx)
        basin_sd_timeseries = sd[basin_idxs, :]
        snow_offs = Vector{Union{Int, SnowOffType}}[]
        for tseries in eachslice(basin_sd_timeseries, dims=1)
            sd_df = DataFrame(datetime = Date.(time), sd = tseries; copycols = false)
            with_year = transform!(sd_df, :datetime=>ByRow(year)=>:year)
            grouped_year = groupby(with_year, :year)
            snow_off_yearly = combine(grouped_year, 
            [:sd, :datetime]=>((x...)->snow_off_single_year(x...))=>:snow_off)
            push!(snow_offs, snow_off_yearly.snow_off)
            isnothing(years) && (years = snow_off_yearly.year)
        end
        basinwide_data = VectorOfArray(snow_offs)
        basin_mean_snow_off = vec(mapslices(x->mean(map(Float32, filter(x->!isa(x, SnowOffType), x))), basinwide_data, dims=2))
        insert!(basin_snowoff, basin, basin_mean_snow_off)
    end

    minday, maxday = minimum(minimum.(ERA.skipnaormiss.(basin_snowoff))), maximum(maximum.(ERA.skipnaormiss.(basin_snowoff)))
    daysofyear = minday-2:5:maxday+2
    daylabels = Dates.format.(Date(2021) .+ Day.(round.(daysofyear) .- 1), dateformat"mm/dd")

    myp = plot(;title="ERA5 $eratype Basin Mean Snow Off Dates", xlabel="year", ylabel="Mean date of snow off",
                yticks = (daysofyear, daylabels))



    for basin in ERA.basin_names
        snow_off = basin_snowoff[basin]
        plot!(myp, years, snow_off; label = "$basin")
    end

    savefig(myp, "../vis/$(eratype)_basin_snow_off.png")
end
