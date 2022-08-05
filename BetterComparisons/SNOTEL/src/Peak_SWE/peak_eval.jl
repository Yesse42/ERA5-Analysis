burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dictionaries
cd(@__DIR__)

include("../../../Snow_Course/src/land_vs_base_func.jl")
include("peak_datagen.jl")
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))

dir = "../../vis/plain_nn"

basin_to_snotel =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]

load_plain_nn(_, eratype, id) =
    load_era(joinpath(ERA.ERA5DATA, "better_extracted_points", "plain_nn"), eratype, id)

mkpath(dir)

snotel_basins = filter(x -> !isempty(basin_to_snotel[x]), ERA.usable_basins)

for (stat, statname, bounds) in zip(("diff_mean", "rmsd", "bias_corrected_rmsd"), ("Bias", "RMSD", "Bias Corrected RMSD"), ((-0.2,0.2),(0, 1), (0,1)))
    for eratype in ERA.eratypes
        stat_names = ["raw", "anom", "normed_anom", "fom"]
        datavec = peak_datagen(;
            eratype,
            basin_to_stations = basin_to_snotel,
            station_compare_args = peak_comp_args,
            load_era_func = peak_swe_load(load_plain_nn),
            stats_to_extract = stat_names .* "_" .* stat,
            basins = snotel_basins
        )
        [data[isnan.(data)] .= 0 for data in datavec]
        display(datavec)
        style_kwargs = (;
            title = "ERA5 $eratype vs SNOTEL Peak SWE",
            ylabel = "Fraction of Median $statname",
            xlabel = "Water Year",
            margin = 5Plots.mm,
        )
        error_bar_plot(
            datavec,
            dir;
            plotname = "$(eratype)_peak_swe_$stat.png",
            labels = ["Raw SWE", "Anomaly", "Normed Anomaly", "Frac. of Median"],
            cvec = [:green, :blue, :purple, :red],
            ylim = bounds,
            xticklabels = snotel_basins,
            style_kwargs
        )
    end
end
