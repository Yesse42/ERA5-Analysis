burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dictionaries
cd(@__DIR__)

include("land_vs_base_func.jl")
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))

dir = "../vis/plain_nn"

func =
    load_plain_nn(_, eratype, id) =
        load_era(joinpath(ERA.ERA5DATA, "better_extracted_points", "plain_nn"), eratype, id)

mkpath(dir)
for eratype in ERA.eratypes
    stat_types = ["raw", "anom", "normed_anom", "fom"]
    datavec = raw_anom_fom_comp_datagen(;
        eratype,
        load_era_func = load_plain_nn,
        basin_to_stations = def_basin_to_station,
        stats_to_extract = stat_types .* "_rmsd",
    )
    style_kwargs = (;
        title = "$eratype Statistic Comparison, Naive NN",
        ylabel = "Fraction of Median RMSD",
        xlabel = "year",
        margin = 5Plots.mm,
    )
    error_bar_plot(
        datavec,
        dir;
        style_kwargs,
        plotname = "$(eratype)_different_statistic_comparison.png",
        labels = stat_types,
        cvec = [:green, :blue, :purple, :red],
        ylim = (0, 2),
    )
end
