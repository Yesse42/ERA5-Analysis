burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2
cd(@__DIR__)

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_nohrsc.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "compare_summary.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))

for basin in ERA.basin_names
    eratype_dict = Dictionary()

    for eratype in ERA.eratypes
        basin_to_fline =
            jldopen(joinpath(ERA.NOHRSCDATA, "$(eratype)_basin_to_flines.jld2"))["basin_to_flines"]

        flines = basin_to_fline[basin]
        isempty(flines) && continue
        used_flines = String[]
        nohrsc_data = DataFrame[]
        for id in flines
            data = load_nohrsc(id, eratype)
            ismissing(data) && continue
            analyzed_data =
                comparison_summary(
                    data,
                    [:mean_era_swe, :gamma],
                    :datetime;
                    anom_stat = "median",
                ).monthperioddata
            push!(used_flines, id)
            push!(nohrsc_data, analyzed_data)
        end

        isempty(nohrsc_data) && continue

        basinmean = sort!(
            basin_aggregate(nohrsc_data, used_flines; timecol = "datetime"),
            "datetime",
        )
        insert!(eratype_dict, eratype, basinmean)
    end

    isempty(eratype_dict) && continue

    #Now plot the difference in percent of median and the anomaly difference on separate axes,
    #for both era5 land and base
    data = getindex.(Ref(eratype_dict), ERA.eratypes)
    #Filter for april
    data = [filter(x -> month(x.datetime) == 4, d) for d in data]
    #Now get the percent of median and anomaly diff
    omniplot(;
        basedat = data[1],
        landdat = data[2],
        basin,
        figtitle = "ERA5 vs NOHRSC ($basin) (April only)",
        stat_swe_name = "gamma_pom_mean",
        era_swe_name = "mean_era_swe_pom_mean",
    )
end
