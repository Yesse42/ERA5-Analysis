burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dictionaries
cd(@__DIR__)

include("../../Snow_Course/src/land_vs_base_func.jl")
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_nohrsc.jl"))

savedir = "../vis/plain_nn"

title = "Naive Nearest Neighbor, Error vs. NOHRSC"

basin_to_flines =
    jldopen(joinpath(ERA.NOHRSCDATA, "Land_basin_to_flines.jld2"))["basin_to_flines"]

nohrsc_args = pairs((;
    load_data_func = load_nohrsc_only,
    comparecolnames = [:gamma, :mean_era_swe],
    timecol = "datetime",
    #The NOHRSC data is so sparse we can't really afford to split it up, hence grouping not on x->month(x) but instead just x->true
    groupfunc = (x -> true),
    median_group_func = (x -> true),
    eradatadir = joinpath(ERA.ERA5DATA, "extracted_points"),
))

mkpath(savedir)
datavec = land_vs_base_datagen(;
    load_era_func = load_nohrsc_era,
    base_stat_name = :fom_rmsd,
    climo_stat_name = :climo_fom_rmsd,
    time_to_pick = true,
    basin_to_stations = basin_to_flines,
    station_compare_args = nohrsc_args,
)
[data[isnan.(data)] .= 0 for data in datavec]
style_kwargs = (;
    title = title,
    ylabel = "Fraction of Median RMSD",
    xlabel = "year",
    margin = 5Plots.mm,
)
error_bar_plot(
    datavec,
    savedir;
    style_kwargs,
    plotname = "NOHRSC_basin_summary.png",
    legend = :topright,
)
