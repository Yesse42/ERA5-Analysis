using CSV, DataFrames, Dates, StatsBase, StaticArrays
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

using Plots
pyplot()

const water_year_split = 9

function water_year(time)
    if month(time) < water_year_split
        year(time) - 1
    else
        year(time)
    end
end

function max_swe(swe, time)
    idx = argmax(swe)
    return (max_dayofyear = dayofyear(time[idx]), max_swe = swe[idx])
end

function peak_swe(basin_swe, times)
    data = DataFrame(; datetime = times, swe = basin_swe)
    transform!(data, :datetime => ByRow(water_year) => :water_year)
    water_year_group = groupby(data, :water_year)

    water_year_peaks = combine(
        water_year_group,
        [:swe, :datetime] => max_swe => [:max_dayofyear, :max_swe],
    )
    return water_year_peaks
end

const meter_to_inch = 39.3701

for eratype in ERA.eratypes
    datadir = joinpath(ERA.ERA5DATA, "basin_extractions", eratype)

    #Also plot basin averages
    water_years = nothing
    peak_swe_all_basins = []
    for basin in ERA.basin_names
        swedata = CSV.read(joinpath(datadir, "$(basin)_sd_avgs.csv"), DataFrame)
        peak_swe_data = peak_swe(swedata.sd_avg .* meter_to_inch, swedata.datetime)
        water_years = peak_swe_data.water_year
        push!(peak_swe_all_basins, peak_swe_data.max_swe)
    end
    peak_swe_combined = reduce(hcat, peak_swe_all_basins)
    myp = plot(
        water_years,
        peak_swe_combined;
        label = permutedims(ERA.basin_names),
        title = "ERA5-$eratype Peak Swe By Water Year",
        xlabel = "Water Year (beginning Sept 1st of stated year)",
        ylabel = "Peak Basin Mean SWE (in)",
        legend = :outertopright,
        size = 0.5e3 .* (2, 1),
    )

    savefig(myp, "../vis/$(eratype)_peak_swe.png")
end
