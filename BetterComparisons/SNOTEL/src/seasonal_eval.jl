burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dictionaries
cd(@__DIR__)

include("../../Snow_Course/src/land_vs_base_func.jl")
include("seasonal_datagen.jl")
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))

dir = "../vis/plan_nn"

basin_to_snotel =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]

load_plain_nn(_, eratype, id) =
    load_era(joinpath(ERA.ERA5DATA, "better_extracted_points", "plain_nn"), eratype, id)

mkpath(dir)

snotel_basins = filter(x -> !isempty(basin_to_snotel[x]), ERA.usable_basins)

for eratype in ERA.eratypes
    mymonths = [11, 12, 1, 2, 3, 4, 5]
    datavec = seasonal_datagen(;
        eratype,
        stat_name = :fom_rmsd,
        load_era_func = load_plain_nn,
        times_to_select = mymonths,
    )
    [data[isnan.(data)] .= 0 for data in datavec]
    style_kwargs = (;
        title = "ERA5 $eratype vs SNOTEL by Month",
        ylabel = "Fraction of Median RMSD",
        xlabel = "year",
        margin = 5Plots.mm,
    )
    cvec = [:yellow, :orange, :red, :purple, :blue, :lightseagreen, :green]
    labels = string.(mymonths)
    plotname = "$eratype basin summary.png"
    error_bar_plot(
        datavec,
        dir;
        cvec,
        labels,
        plotname,
        style_kwargs,
        xticklabels = snotel_basins,
    )
end
