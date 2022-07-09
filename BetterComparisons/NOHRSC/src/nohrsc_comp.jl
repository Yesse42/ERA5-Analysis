burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_nohrsc.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "compare_summary.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))

for basin in ERA.basin_names
    eradata = Dictionary()

    for eratype in ERA.eratypes
        basin_to_fline =
            jldopen(joinpath(ERA.NOHRSCDATA, "$(eratype)_basin_to_flines.jld2"))["basin_to_flines"]

        flines = basin_to_fline[basin]
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
                ).monthlymeandata
            push!(used_flines, id)
            # basin == "Chena" && display(analyzed_data)
            push!(nohrsc_data, analyzed_data)
        end

        basinmean =
            sort!(basin_aggregate(nohrsc_data, used_flines; timecol = :month), :month)
        display((basin, eratype))
        display(basinmean[:, r"(month)|(pom)"])
        insert!(eradata, eratype, basinmean)
    end
end
