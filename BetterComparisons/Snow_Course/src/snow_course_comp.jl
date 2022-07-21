burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, WeakRefStrings

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "comparison_machinery.jl"))

for basin in ERA.basin_names
    eradata = DataFrame[]

    for eratype in ERA.eratypes
        basin_to_courses =
            jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

        courses = basin_to_courses[basin]
        basinmean = general_station_compare(
            eratype,
            courses;
            load_data_func = load_snow_course,
            comparecolnames = [:era_swe, :snow_course_swe],
            timecol = "datetime",
            groupfunc = shifted_monthperiod,
            median_group_func = shifted_month,
            eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")
        )
        push!(eradata, basinmean.basindata)
    end

    #Now plot the difference in percent of median and the anomaly difference on separate axes,
    #for both era5 land and base
    #Filter for end of march/beginning of april
    eradata = [filter(x -> month(x.datetime) == 4, d) for d in eradata]
    #Now get the percent of median and anomaly diff
    omniplot(;
        basedat = eradata[1],
        landdat = eradata[2],
        basin,
        figtitle = "ERA5 vs Snow Course ($basin) (Mar 16th - Apr 15th)",
        stat_swe_name = "snow_course_swe_fom_mean",
        era_swe_name = "era_swe_fom_mean",
        fom_climo_diff_name = "snow_course_swe_fom_climo_diff_mean",
    )
end
