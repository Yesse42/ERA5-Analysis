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

"This function groups the two halves of the month the snow course measurements can occur in (e.g. end of march and start of april are grouped)"
function mymonth(date)
    #+18 days ensures that the 15th, 16th, and 17th get shifted into the next month
    date = date+Day(18)
    return month(date)
end
function mymonthperiod(date)
    shiftdate = date+Day(18)
    return round(date, Month(1), RoundDown)
end

function general_course_compare(eratype, courses; groupfunc=mymonthperiod, median_group_func=mymonth)
    course_data = DataFrame[]
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
                groupfunc,
                median_group_func
            ).grouped_data
        newtimecol = Symbol(groupfunc)
        select!(analyzed_data, newtimecol=>:datetime, Not(newtimecol))
        push!(course_data, analyzed_data)
    end

    basinmean = sort!(
        basin_aggregate(course_data; timecol = "datetime"),
        "datetime",
    )
    return basinmean
end
