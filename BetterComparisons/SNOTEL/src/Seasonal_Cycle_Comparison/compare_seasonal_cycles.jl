burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, JLD2, Dictionaries, StatsBase

include("calculate_seasonal_cycle.jl")
include("../water_year.jl")
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))
include.(joinpath.(ERA.COMPAREDIR, "Load Scripts", ("load_era.jl", "load_snotel.jl")))

default_colnames = (;timecol = "datetime", datacols = ["snotel_swe","era_swe"])
analysis_kwargs = (;max_miss_days = 30, fractions = 1//100:1//20:99//100, snow_on_thresh = 0.01, 
water_year_monthday = (startmonth = 9, startday = 1))

function cycle_generate(combined_data; timecol, max_miss_days, fractions, snow_on_thresh, water_year_monthday, unused...)
    dropmissing!(combined_data)
    swe_cols = filter!(x-> x ≠ string(timecol), names(combined_data))
    transform!(combined_data, timecol=>ByRow(x->day_of_water_year(x; water_year_monthday...))=>:water_yearday,
                                timecol=>ByRow(x->water_year(x; water_year_monthday...))=>:water_year)
    year_group = groupby(combined_data, :water_year)

    swe_with_dayofyear = [[col, "water_yearday"] for col in swe_cols]
    function cycle(swe, args...; kwargs...)
        if count(ismissing, swe) > max_miss_days 
            missing 
        else 
            shape = swe_shape(swe, args...;kwargs...)
            return Ref(shape)
        end
    end
    cyclenames = swe_cols.*"_cycle"
    season_data = combine(year_group, (swe_with_dayofyear.=>((x,y)->cycle(x,y, fractions; snow_on_thresh)).=>cyclenames)...)
    select!(season_data, :water_year => timecol, Not(:water_year))
end

function mycorrectedrmsd(x,y)
    meandiff = mean(a-b for (a,b) in zip(x,y))
    return sqrt(mean((a - b - meandiff)^2 for (a,b) in zip(x,y)))
end
mybias(x,y) = mean(a-b for (a,b) in zip(x,y))
..(d, sym) = getproperty.(d, sym)

function cycle_func(func; T=Float64)
    return function g(d1, d2)
       d1, d2 = d1..:days, d2..:days
       ncols = length(first(d1))
       out = zeros(T, ncols)'
       for i in 1:ncols
           out[i] = func((v[i] for v in d1),(v[i] for v in d2))
       end
       return Ref(out)
    end
end

function cycle_rmsd_bias(cycles; datacols, timecol, kwargs...)
    dropmissing!(cycles)
    
    corrected_rmsd = cycle_func(mycorrectedrmsd)
    bias = cycle_func(mybias)
    collapsed = combine(cycles, datacols.*"_cycle"=>corrected_rmsd=>"cycle_bias_corrected_rmsd", datacols.*"_cycle"=>bias=>"cycle_bias", nrow=>:n_obs)
    return collapsed
end

function cycle_aggregate(valrow, weightrow)
    unmiss = (!).(ismissing.(valrow) .|| ismissing.(weightrow))
    return @views sum(valrow[unmiss] .* weightrow[unmiss]) ./ sum(weightrow[unmiss])
end

function basinwide_cycle_diff(stations, eratype, era_load, snotel_load; colnames, analysis_args)
    stationdata = DataFrame[]
    for station in stations
        snotel = snotel_load(station)
        era = era_load(eratype, station)
        any(ismissing.((snotel, era))) && continue
        combined = dropmissing!(innerjoin(snotel, era; on = colnames.timecol))
        cycles = cycle_generate(combined; colnames..., analysis_args...)
        rmsd_bias_stats = cycle_rmsd_bias(cycles; colnames..., analysis_args...)
        rmsd_bias_stats[!, colnames.timecol] = [true]
        push!(stationdata, rmsd_bias_stats)
    end

    return basin_aggregate(stationdata; timecol = colnames.timecol, aggregate_func = cycle_aggregate)
end

function plot_cycle_bias(stations, eratype, era_load, snotel_load; stat="cycle_bias", colnames = default_colnames, analysis_args = analysis_kwargs,
                            plotargs)
    data = basinwide_cycle_diff(stations, eratype, era_load, snotel_load; 
                colnames = default_colnames, analysis_args = analysis_kwargs)
    ismissing(data) && return missing
    (;fractions) = analysis_args
    label_idxs = range(1, length(fractions); step = length(fractions) ÷ 5)
    label_fracs = fractions[label_idxs]

    frac_labels = [string.(label_fracs) .* "↑"; "1-"; string.(reverse(label_fracs)) .* "↓"]
    label_locs = [label_idxs; length(fractions) + 1; 2 .* length(fractions) .- reverse(label_idxs) .+ 2]
    plotdata = vec(data[1, stat])
    ticks = 1:length(plotdata)
    p = plot(ticks, vec(data[1, stat]); plotargs..., xticks = (label_locs, frac_labels), rotation = 45)
    return p
end

function func_over_single_station(func; T=Float64)
    function h(data)
        data = pad_to_full_year.(swe_shape_output_to_interpolated_values.(data))
        data = [d.swe_interped for d in skipmissing(data)]
        ncols = length(first(data))
        out = zeros(T, ncols)'
        for i in 1:ncols
            out[i] = func((v[i] for v in data))
        end
       return Ref(out)
    end
end

function mean_cycle(cycles; datacol)
    dropmissing!(cycles)
    mymean = func_over_single_station(mean)
    collapsed = combine(cycles, datacol=>mymean=>datacol, nrow=>:n_obs)
    return collapsed
end

function basinwide_mean_cycle(stations, loadfunc; timecol, datacol, analysis_args)
    stationdata = DataFrame[]
    for station in stations
        data = loadfunc(station)
        cycles = cycle_generate(data; timecol, analysis_args...)
        meancycle = mean_cycle(cycles; datacol = datacol * "_cycle")
        meancycle[!, timecol] = [true]
        push!(stationdata, meancycle)
    end

    return basin_aggregate(stationdata; timecol, aggregate_func = cycle_aggregate)
end

function plot_basin_cycle(stations, loadfuncs, labels, colnames; timecol, analysis_args = analysis_kwargs,
    plotargs)
    (;fractions) = analysis_args
    myp = plot(;plotargs...)
    for (func, label, colname) in zip(loadfuncs, labels, colnames)
        data = basinwide_mean_cycle(stations, func; 
        timecol, datacol = colname,  analysis_args = analysis_kwargs)
        ismissing(data) && return missing
        pdata = vec(data[1, colname * "_cycle"])
        plot!(myp, eachindex(pdata), pdata; label)
    end
    return myp
end