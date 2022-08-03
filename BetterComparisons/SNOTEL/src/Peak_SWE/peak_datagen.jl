burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dates

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snotel.jl"))
include("../water_year.jl")

function peak_swe_load(loadfunc)
     function f(args...)
        unprocessed = loadfunc(args...)
        ismissing(unprocessed) && return missing
        #Now group on water year and get the peak swe
        timecol = "datetime"
        not_time = only(filter(x->x≠timecol, names(unprocessed)))
        with_water_year = transform!(unprocessed, timecol=>ByRow(round_water_year)=>timecol)
        water_year_group = groupby(with_water_year, timecol)
        return combine(water_year_group, not_time=>(x->maximum(skipmissing(x)))=>not_time)
    end
end

peak_comp_args = pairs((;
    load_data_func = peak_swe_load(load_snotel),
    comparecolnames = [:snotel_swe, :era_swe],
    timecol = "datetime",
    groupfunc = x->true,
    median_group_func = x->true,
    n_obs_weighting = true,
    eradatadir = joinpath(ERA.ERA5DATA, "extracted_points"),
))

basin_to_snotel =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]

function peak_datagen(;
    eratype,
    basin_to_stations = basin_to_snotel,
    station_compare_args = peak_comp_args,
    load_era_func,
    stats_to_extract = ["raw", "anom", "normed_anom", "fom"] .* "_rmsd",
    basins = ERA.usable_basins
)
    peak_swe_stats = [Float64[] for _ in 1:length(stats_to_extract)]
    for basin in basins
        snotels = basin_to_stations[basin]
        basinmean = general_station_compare(
            eratype,
            snotels;
            load_era_func,
            station_compare_args...,
        )
        ismissing(basinmean) && continue
        

        basinmean = basinmean.basindata

        for (i,stat) in enumerate(stats_to_extract)
            push!(peak_swe_stats[i], only(basinmean[:, stat]))
        end
    end

    #Now return a vector of the vectors
    return peak_swe_stats
end
