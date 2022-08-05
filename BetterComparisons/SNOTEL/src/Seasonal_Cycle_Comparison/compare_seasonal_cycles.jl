burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, JLD2, Dictionaries, StatsBase

include("calculate_seasonal_cycle.jl")
include("../water_year.jl")
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))

default_colnames = (;timecol = "datetime", datacols = ["snotel_swe","era_swe"])
analysis_kwargs = (;max_miss_days = 30, fractions = 1//100:1//20:99//100, snow_on_thresh = 0.01, 
water_year_monthday = (startmonth = 9, startday = 1))

function cycle_generate(combined_data; timecol, max_miss_days, fractions, snow_on_thresh, water_year_monthday)
    dropmissing!(combined_data)
    transform!(combined_data, timecol=>ByRow(x->day_of_water_year(x; water_year_monthday...))=>:water_yearday,
                                timecol=>ByRow(x->water_year(x; water_year_monthday...))=>:water_year)
    year_group = groupby(combined_data, :water_year)

    swe_cols = filter!(x-> x ≠ string(timecol), names(combined_data))
    swe_with_dayofyear = [[col, timecol] for col in swe_cols]
    cycle(swe, args...; kwargs...) = if count(ismissing, swe) > max_miss_days missing else swe_shape(swe, args...;kwargs...)
    season_data = combine(year_group, swe_with_dayofyear.=>((x,y)->cycle(x,y, fractions; snow_on_thresh))=>swe_cols.*"_cycle" )
end

myrmsd(x,y) = sqrt(mean((a-b)^2 for (a,b) in zip(x,y)))
mybias(x,y) = mean(a-b for (a,b) in zip(x,y))

function cycle_rmsd_bias(cycles; datacols, timecol, T=Float64, kwargs...)
    dropmissing!(cycles)
    function cycle_func(func)
         return function g(d1, d2)
            ncols = length(first(d1))
            out = zeros(T, ncols)
            for i in 1:ncols
                out[i] = func((v[i] for v in d1),(v[i] for v in d2))
            end
            return out
         end
    end
    rmsd = cycle_func(myrmsd)
    bias = cycle_func(mybias)
    collapsed = combine(cycles, datacols=>rmsd=>"cycle_rmsd", datacols=>bias=>"cycle_bias")
    return collapsed
end

function cycle_aggregate(valrow, weightrow)
    unmiss = (!).(ismissing.(valrow) .|| ismissing.(weightrow))
    return @views sum(valrow[unmiss] .* weightrow[unmiss]) ./ sum(weightrow[unmiss])
end

function basinwide_cycle_analysis(stations, era_load, eratype, snotel_load; colnames = default_colnames, analysis_args = analysis_kwargs)
    stationdata = DataFrame[]
    for station in stations
        snotel = snotel_load(station)
        era = era_load(eratype, station)
        any(ismissing.((snotel, era))) && continue
        combined = dropmissing!(innerjoin(snotel, era); on = colnames.timecol)
        cycles = cycle_generate(combined; colnames..., analysis_args...)
        rmsd_bias_stats = cycle_rmsd_bias(cycles, colnames..., analysis_args...)
        push!(stationdata, rmsd_bias_stats)
    end
    return basin_aggregate(stationdata; timecol = colnames.timecol, aggregate_func = cycle_aggregate)
end