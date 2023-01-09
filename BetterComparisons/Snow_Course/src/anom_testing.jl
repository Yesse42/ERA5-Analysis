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
        stat_types = ["raw", "anom", "normed_anom", "fom", "rank", "climo_fom"]
        datavec = raw_anom_fom_comp_datagen(;
            eratype,
            load_era_func = load_plain_nn,
            basin_to_stations = def_basin_to_station,
            stats_to_extract = stat_types .* "_$stat",
        )
        style_kwargs = (;
            title = "ERA5 $eratype SWE Metric Comp., April 1st Snow Course",
            titlefontsize = 12,
            ylabel = "Fraction of Median $statname",
            xlabel = "Basin",
            margin = 5Plots.mm,
        )
        error_bar_plot(
            datavec,
            dir;
            style_kwargs,
            plotname = "$(eratype)_$(statname)_different_statistic_comparison.png",
            labels = ["Raw SWE", "Anomaly", "Normed Anomaly", "Frac. of Median", "Rank", "Climatological Median"],
            cvec = [:green, :blue, :purple, :red, :yellow, :orange],
            ylim = bounds,
        )
    end
end

let 

    dir = "../vis/pres"
    mkpath(dir)

    stat_types = ["raw", "anom", "normed_anom", "fom", "rank", "climo_fom"]
    datavec = raw_anom_fom_comp_datagen(;
        eratype = "Land",
        load_era_func = load_plain_nn,
        basin_to_stations = def_basin_to_station,
        stats_to_extract = stat_types .* "_rmsd",
        basins = ["Chena"]
    )
    style_kwargs = (;
        title = "Chena ERA5 Land SWE Metric Comp., April 1st Snow Course",
        titlefontsize = 12,
        ylabel = "Fraction of Median RMSD",
        xlabel = "Basin",
        margin = 5Plots.mm,
    )
    error_bar_plot(
        datavec,
        dir;
        style_kwargs,
        plotname = "Sample_Statistic_Comp.png",
        labels = ["Raw SWE", "Anomaly", "Normed Anomaly", "Frac. of Median", "Rank", "Climatological Median"],
        cvec = [:green, :blue, :purple, :red, :yellow, :orange],
        ylim = (0,0.6),
    )

end
