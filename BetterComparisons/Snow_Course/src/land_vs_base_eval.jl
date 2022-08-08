burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dictionaries
cd(@__DIR__)

include("land_vs_base_func.jl")
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))

load_k_fold_func = let
    kfolddatadir = joinpath(ERA.ERA5DATA, "better_extracted_points", "k-fold_data")

    #Useful preloading
    datadict = nothing
    for foldtype in ERA.foldtypes, eratype in ERA.eratypes
        stationtodata =
            jldopen(joinpath(kfolddatadir, foldtype, eratype, "eradata.jld2"))["station_to_data"]
        stationtodata = map(stationtodata) do datatup
            df = DataFrame(datatup; copycols = false)
            select!(
                df,
                :time => ByRow(Date) => :datetime,
                :sd => ByRow(x -> x .* ERA.meter_to_inch) => :era_swe,
            )
            return sort!(df, :datetime)
        end

        if isnothing(datadict)
            datadict = Dictionary([(foldtype, eratype)], [stationtodata])
        else
            insert!(datadict, (foldtype, eratype), stationtodata)
        end
    end

    load_k_fold_func(foldtype) = function load_era_k_fold(_, eratype, id)
        stationtodata = datadict[(foldtype, eratype)]
        return get(stationtodata, string(id), missing)
    end
end

savedirs = "../vis/" .* ["plain_nn", "cheater", joinpath.("k-fold", ERA.foldtypes)...]

load_cheater(_, eratype, id) =
    load_era(joinpath(ERA.ERA5DATA, "better_extracted_points", "cheater_data"), eratype, id)

loadfuncs =
    [load_plain_nn, load_cheater, [load_k_fold_func(type) for type in ERA.foldtypes]...]

titles = [
    "Nearest Neighbor Error",
    "Minimizing RMSD",
    "Minimizing RMSD K-Fold Validation (Every 3rd year)",
    "Minimizing RMSD K-Fold Validation (3 Chunks)",
]

for (stat, statname, bounds) in zip(("diff_mean", "rmsd", "bias_corrected_rmsd"), ("Bias", "RMSD", "Bias Corrected RMSD"), ((-0.2,0.2),(0, 1), (0,1)))
    for time in [12, 2, 3, 4, 5]
        for (dir, func, title) in zip(savedirs, loadfuncs, titles)
            mkpath(dir)
            datavec = land_vs_base_datagen(;
                load_era_func = func,
                base_stat_name = "fom_$stat",
                climo_stat_name = "climo_fom_$stat",
                time_to_pick = time,
            )
            [data[isnan.(data)] .= 0 for data in datavec]
            style_kwargs = (;
                title = title,
                ylabel = "Fraction of Median $statname",
                xlabel = "year",
                margin = 5Plots.mm,
            )
            error_bar_plot(
                datavec,
                dir;
                style_kwargs,
                plotname = "Month $time basin_summary $statname.png",
                ylim = bounds
            )
        end
    end
end
