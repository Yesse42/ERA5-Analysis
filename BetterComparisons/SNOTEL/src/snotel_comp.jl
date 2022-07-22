burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, WeakRefStrings

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snotel.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "comparison_machinery.jl"))

for basin in ERA.usable_basins
    eradata = DataFrame[]

    for eratype in ERA.eratypes
        basin_to_snotels =
            jldopen(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_basin_to_id.jld2"))["basin_to_id"]

        snotels = basin_to_snotels[basin]
        basinmean = general_station_compare(
            eratype,
            snotels;
            load_data_func = load_snotel,
            comparecolnames = [:era_swe, :snotel_swe],
            timecol = "datetime",
            eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")
        )
        ismissing(basinmean) && continue
        push!(eradata, basinmean.basindata)
    end

    isempty(eradata) && continue

    #Now plot the difference in percent of median and the anomaly difference on separate axes,
    #for both era5 land and base
    #Filter for march
    eradata = [filter(x -> month(x.datetime) == 3, d) for d in eradata]
    #Now get the percent of median and anomaly diff
    omniplot(;
        basedat = eradata[1],
        landdat = eradata[2],
        basin,
        figtitle = "ERA5 vs SNOTEL ($basin) March)",
        stat_swe_name = "snotel_swe_fom_mean",
        era_swe_name = "era_swe_fom_mean",
        fom_climo_diff_name = "snotel_swe_fom_climo_diff_mean",
    )
end
