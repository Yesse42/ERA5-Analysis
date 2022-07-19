burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dictionaries

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "compare_summary.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "basin_agg_funcs.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))

eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")

"This function groups the two halves of the month the snow course measurements can occur in (e.g. end of march and start of april are grouped)"
function shifted_month(date)
    #+18 days ensures that the 15th, 16th, and 17th get shifted into the next month
    date = date + Day(18)
    return month(date)
end
function shifted_monthperiod(date)
    shiftdate = date + Day(18)
    return round(shiftdate, Month(1), RoundDown)
end

function monthperiod(date)
    return round(date, Month(1), RoundDown)
end

function general_station_compare(
    eratype,
    stations;
    load_data_func,
    load_era_func = load_era,
    comparecolnames,
    groupfunc = monthperiod,
    median_group_func = month,
    timeperiod = (Date(0, 1, 1), Date(3000, 1, 1)),
    timecol = "datetime",
    grouped_or_ungrouped = :grouped_data,
    n_obs_weighting = false,
)
    station_data = DataFrame[]
    used_stations = String[]
    for id in stations
        single_station_data = load_data_func(id)
        eradata = load_era_func(eradatadir, eratype, id)
        (ismissing(eradata) || ismissing(single_station_data)) && continue
        data = innerjoin(single_station_data, eradata; on = timecol)
        filter!(x -> timeperiod[1] <= x.datetime <= timeperiod[2], data)
        analyzed_data = comparison_summary(
            data,
            comparecolnames,
            timecol;
            anom_stat = "median",
            groupfunc,
            median_group_func,
        )
        analyzed_data = getproperty(analyzed_data, grouped_or_ungrouped)
        newtimecol = Symbol(groupfunc)
        select!(analyzed_data, newtimecol => timecol, Not(newtimecol))
        push!(station_data, analyzed_data)
        push!(used_stations, id)
    end

    display(station_data[1])

    basinmean = basin_aggregate(station_data; timecol = timecol, n_obs_weighting)

    if ismissing(basinmean)
        return missing
    end

    sort!(basinmean, timecol)

    return (basindata = basinmean, stationdata = Dictionary(used_stations, station_data))
end
