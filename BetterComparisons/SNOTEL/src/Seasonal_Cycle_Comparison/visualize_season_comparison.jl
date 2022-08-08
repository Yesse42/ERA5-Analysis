cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, StatsBase, Plots, JLD2

include("compare_seasonal_cycles.jl")

savedir = "../../vis/plain_nn/"

basin_to_snotel =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]

analysis_kwargs = (;max_miss_days = 30, fractions = [0.01, 0.05, 0.1, 0.25, 0.4, 0.6, 0.75, 0.9], snow_on_thresh = 0.01, 
water_year_monthday = (startmonth = 9, startday = 1))

for basin in ERA.usable_basins
    for eratype in ERA.eratypes
        myplotargs = (title = "$basin ERA5 $eratype Seasonal Cycle Bias Corrected RMSD", titlefontsize = 10, 
        ylabel = "RMSD (days)", xlabel = "Fraction of Peak SWE",
        rotation = 45, label="")

        myplot = plot_cycle_bias(basin_to_snotel[basin], eratype, load_plain_nn, load_snotel;
                stat = "cycle_bias_corrected_rmsd", colnames = (timecol = "datetime", datacols = ["snotel_swe", "era_swe"]),
                analysis_args = analysis_kwargs, plotargs = myplotargs)

        ismissing(myplot) && continue

        display(myplot)

        savefig(myplot, joinpath(savedir, "$basin $eratype cycle_rmsd.png"))


    end
end

for basin in ERA.usable_basins
    myplotargs = (title = "$basin Mean Seasonal Cycle", ylabel = "Fraction of Peak SWE", xlabel = "Day of Water Year")

    stations = basin_to_snotel[basin]

    loadfuncs = [[id->load_plain_nn(type, id) for type in ERA.eratypes]; load_snotel]
    labels = [ERA.eratypes; "SNOTEL"]
    colnames = string.([:era_swe, :era_swe, :snotel_swe])

    myplot = nothing
    p = plot_basin_cycle(stations, loadfuncs, labels, colnames; timecol = "datetime", analysis_args = analysis_kwargs,
                plotargs = myplotargs)

    ismissing(p) && continue

    savefig(p, joinpath(savedir, "$(basin)_swe_cycles.png"))

    display(p)
end