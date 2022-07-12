burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "compare_summary.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))

eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")

for basin in ERA.basin_names
    eratype_dict = Dictionary()

    for eratype in ERA.eratypes
        basin_to_courses =
            jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

        courses = basin_to_courses[basin]
        used_courses = String[]
        course_data = []
        for id in courses
            single_course_data = load_snow_course(id)
            eradata = load_era(eradatadir, eratype, id)
            (ismissing(eradata) || ismissing(single_course_data)) && continue
            data = innerjoin(single_course_data, eradata; on = :datetime)
            analyzed_data =
                comparison_summary(
                    data,
                    [:era_swe, :snow_course_swe],
                    :datetime;
                    anom_stat = "median",
                ).monthperioddata
            push!(used_courses, id)
            push!(course_data, analyzed_data)
        end

        basinmean = sort!(
            basin_aggregate(course_data, used_courses; timecol = "datetime"),
            "datetime",
        )
        insert!(eratype_dict, eratype, basinmean)
    end

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
        figtitle = "ERA5 vs Snow Course ($basin) (04/01 only)",
        stat_swe_name = "snow_course_swe_pom_mean",
        era_swe_name = "era_swe_pom_mean",
    )
end
