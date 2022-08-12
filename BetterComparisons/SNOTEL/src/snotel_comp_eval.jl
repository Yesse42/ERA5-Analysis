burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include("../../Snow_Course/src/snow_course_comp_func.jl")
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snotel.jl"))

savedir = "../vis/plain_nn/time_series"
mkpath(savedir)

snotel_from_basin =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]

snotel_compare_args = (;
    load_data_func = load_snotel,
    comparecolnames = [:snotel_swe, :era_swe],
    timecol = "datetime",
    groupfunc = monthperiod,
    median_group_func = month,
    eradatadir = nothing,
)

mkpath(dir)
omni_args = (;
    savedir = savedir,
)

snow_course_comp_lineplot(;
    era_load_func = load_plain_nn,
    era_swe_name = :era_swe_fom_mean,
    station_swe_name = :snotel_swe_fom_mean,
    timepick = 3,
    basin_to_station = snotel_from_basin,
    station_compare_args = snotel_compare_args,
    figtitle_func = (basin -> "$basin ERA5 vs SNOTEL (March)"),
    omniplot_args = omni_args,
)
