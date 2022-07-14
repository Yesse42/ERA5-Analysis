burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, WeakRefStrings

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "compare_summary.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))

eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")

#This function groups the two halves of the month the snow course measurements can occur in (e.g. end of march and start of april are grouped)
function mymonth(date)
    #+18 days ensures that the 15th, 16th, and 17th get shifted into the next month
    date = date+Day(18)
    return month(date)
end
function mymonthperiod(date)
    shiftdate = date+Day(18)
    return round(date, Month(1), RoundDown)
end

land_pom_rmsd = []; base_pom_rmsd = []
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
                    groupfunc = mymonth,
                    median_group_func = mymonth
                ).grouped_data
            push!(used_courses, id)
            select!(analyzed_data, :mymonth=>:datetime, Not(:mymonth))
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
    #Filter for end of march/beginning of april
    data = [filter(x -> x.datetime == 4, d) for d in data]
    #Now get the percent of median and anomaly diff
    push!(land_pom_rmsd, only(data[2].pom_diff_rmsd))
    push!(base_pom_rmsd, only(data[1].pom_diff_rmsd))
end

display(DataFrame(;basin=ERA.basin_names, land_minus_base_pom_rmsd = land_pom_rmsd.-base_pom_rmsd, land_pom_rmsd, base_pom_rmsd))