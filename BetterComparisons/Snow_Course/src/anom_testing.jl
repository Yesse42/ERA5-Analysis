cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dictionaries

include("land_vs_base_func.jl")
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))

dir = "../vis/plain_nn"

func = load_plain_nn

mkpath(dir)
for (stat, statname, bounds) in zip(("diff_mean", "rmsd", "bias_corrected_rmsd"), ("Bias", "RMSD", "Bias Corrected RMSD"), ((-0.2,0.2),(0, 1), (0,1)))
    for eratype in ERA.eratypes
        stat_types = ["raw", "anom", "normed_anom", "fom", "climo_fom"]
        datavec = raw_anom_fom_comp_datagen(;
            eratype,
            load_era_func = load_plain_nn,
            basin_to_stations = def_basin_to_station,
            stats_to_extract = stat_types .* "_$stat",
        )
        style_kwargs = (;
            title = "$eratype Statistic Comparison, Naive NN, April 1st Snow Course",
            titlefontsize = 12,
            ylabel = "Fraction of Median $statname",
            xlabel = "Year",
            margin = 5Plots.mm,
        )
        error_bar_plot(
            datavec,
            dir;
            style_kwargs,
            plotname = "$(eratype)_$(statname)_different_statistic_comparison.png",
            labels = ["Raw SWE", "Anomaly", "Normed Anomaly", "Frac. of Median", "Climatological Median"],
            cvec = [:green, :blue, :purple, :red, :orange],
            ylim = bounds,
        )
    end
end
