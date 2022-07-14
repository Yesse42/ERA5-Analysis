burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2
cd(@__DIR__)

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snotel.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "compare_summary.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))

eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")

for basin in ERA.basin_names
    eratype_dict = Dictionary()

    for eratype in ERA.eratypes
        basin_to_snotel =
            jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]

        snotels = basin_to_snotel[basin]
        used_snotels = String[]
        snotel_data = DataFrame[]
        for id in snotels
            single_snotel_data = load_snotel(id)
            eradata = load_era(eradatadir, eratype, id)
            (ismissing(eradata) || ismissing(single_snotel_data)) && continue
            data = innerjoin(single_snotel_data, eradata; on = :datetime)
            analyzed_data =
                comparison_summary(
                    data,
                    [:era_swe, :snotel_swe],
                    :datetime;
                    anom_stat = "median",
                ).grouped_data
            push!(used_snotels, id)
            select!(analyzed_data, :monthgroup=>:datetime, Not(:monthgroup))
            push!(snotel_data, analyzed_data)
        end

        isempty(used_snotels) && continue

        basinmean = sort!(
            basin_aggregate(snotel_data, used_snotels; timecol = "datetime"),
            "datetime",
        )
        insert!(eratype_dict, eratype, basinmean)
    end
    isempty(eratype_dict) && continue

    data = getindex.(Ref(eratype_dict), ERA.eratypes)
    #Filter for March
    data = [filter(x -> month(x.datetime) == 3, d) for d in data]
    #Now get the percent of median and anomaly diff
    omniplot(;
        basedat = data[1],
        landdat = data[2],
        basin,
        figtitle = "ERA5 vs SNOTEL ($basin) (March only)",
        stat_swe_name = "snotel_swe_pom_mean",
        era_swe_name = "era_swe_pom_mean",
    )
end
