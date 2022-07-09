burrowactivate()
import ERA5Analysis as ERA 
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snotel.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "compare_summary.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))

eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")

for basin in ERA.basin_names
    eratype_dict = Dictionary()

    for eratype in ERA.eratypes
        basin_to_snotel = jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]
    
        snotels = basin_to_snotel[basin]
        used_snotels=String[]
        snotel_data = DataFrame[]
        for id in snotels
            single_snotel_data = load_snotel(id)
            eradata = load_era(eradatadir, eratype, id)
            (ismissing(eradata) || ismissing(single_snotel_data)) && continue
            data = innerjoin(single_snotel_data, eradata; on=:datetime)
            analyzed_data = comparison_summary(data, ["$eratype", :snotel_swe], :datetime; anom_stat="median").monthmeandata
            push!(used_snotels, id)
            push!(snotel_data, analyzed_data)
        end

        basinmean = sort!(basin_aggregate(snotel_data, used_snotels; timecol="month"), "month")
        display((basin, eratype))
        display(filter(x->x.month==4, basinmean)[:, r"(month)|(pom)"])
        insert!(eratype_dict, eratype, basinmean)
    end
end