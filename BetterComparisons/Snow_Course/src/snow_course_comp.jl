burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "compare_summary.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))

eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")

for basin in ERA.basin_names
    eratype_dict = Dictionary()

    for eratype in ERA.eratypes
        basin_to_courses =
            jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

        courses = basin_to_courses[basin]
        used_courses = String[]
        course_data = DataFrame[]
        for id in courses
            single_course_data = load_snow_course(id)
            eradata = load_era(eradatadir, eratype, id)
            (ismissing(eradata) || ismissing(single_course_data)) && continue
            data = innerjoin(single_course_data, eradata; on = :datetime)
            analyzed_data =
                comparison_summary(
                    data,
                    ["$eratype", :snow_course_swe],
                    :datetime;
                    anom_stat = "median",
                ).monthmeandata
            push!(used_courses, id)
            push!(course_data, analyzed_data)
        end

        basinmean =
            sort!(basin_aggregate(course_data, used_courses; timecol = "month"), "month")
        display((basin, eratype))
        display(filter(x -> x.month == 4, basinmean)[:, r"(month)|(pom)"])
        insert!(eratype_dict, eratype, basinmean)
    end
end