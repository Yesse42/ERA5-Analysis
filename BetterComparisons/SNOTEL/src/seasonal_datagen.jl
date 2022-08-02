burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dates

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snotel.jl"))

snotel_comp_args = pairs((;
    load_data_func = load_snotel,
    comparecolnames = [:snotel_swe, :era_swe],
    timecol = "datetime",
    groupfunc = month,
    median_group_func = month,
    n_obs_weighting = true,
    eradatadir = joinpath(ERA.ERA5DATA, "extracted_points"),
))

basin_to_snotel =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]

function seasonal_datagen(;
    eratype,
    basin_to_stations = basin_to_snotel,
    stat_name,
    station_compare_args = snotel_comp_args,
    load_era_func,
    times_to_select,
    basins = ERA.usable_basins
)
    erastats = [Vector{Float64}() for _ in 1:length(times_to_select)]
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

        for (i, month) in enumerate(times_to_select)
            month_idx = findfirst(==(month), basinmean.datetime)
            push!(erastats[i], basinmean[month_idx, stat_name])
        end
    end

    #Now return a vector of the vectors
    return erastats
end
