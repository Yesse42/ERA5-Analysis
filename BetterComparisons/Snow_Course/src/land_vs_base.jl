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

land_pom_rmsd = []; base_pom_rmsd = []
for basin in ERA.basin_names
    eradata = DataFrame[]

    for eratype in ERA.eratypes
        basin_to_courses =
            jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

        courses = basin_to_courses[basin]
        basinmean = general_course_compare(eratype, courses;groupfunc=mymonth)
        push!(eradata, basinmean.basindata)
    end

    #Now plot the difference in percent of median and the anomaly difference on separate axes,
    #for both era5 land and base
    #Filter for end of march/beginning of april
    eradata = [filter(x -> x.datetime == 4, d) for d in eradata]
    #Now get the percent of median and anomaly diff
    push!(land_pom_rmsd, only(eradata[2].pom_diff_rmsd))
    push!(base_pom_rmsd, only(eradata[1].pom_diff_rmsd))
end
    #Now get the percent of median and anomaly diff

display(DataFrame(;basin=ERA.basin_names, land_minus_base_pom_rmsd = land_pom_rmsd.-base_pom_rmsd, land_pom_rmsd, base_pom_rmsd))