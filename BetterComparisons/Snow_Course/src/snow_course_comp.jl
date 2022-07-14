burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, WeakRefStrings

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "compare_summary.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))

include("comparison_machinery.jl")

for basin in ERA.basin_names
    eradata = DataFrame[]

    for eratype in ERA.eratypes
        basin_to_courses =
            jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

        courses = basin_to_courses[basin]
        basinmean = general_course_compare(eratype, courses)
        push!(eradata, basinmean.basindata)
    end

    #Now plot the difference in percent of median and the anomaly difference on separate axes,
    #for both era5 land and base
    #Filter for end of march/beginning of april
    eradata = [filter(x -> month(x.datetime) == 4, d) for d in data]
    #Now get the percent of median and anomaly diff
    omniplot(;
        basedat = data[1],
        landdat = data[2],
        basin,
        figtitle = "ERA5 vs Snow Course ($basin) (Mar 16th - Apr 15th)",
        stat_swe_name = "snow_course_swe_pom_mean",
        era_swe_name = "era_swe_pom_mean",
    )
end
