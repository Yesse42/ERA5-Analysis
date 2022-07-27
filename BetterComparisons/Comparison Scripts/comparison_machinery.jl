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
    return month(round(date, Month(1), RoundNearestTiesUp))
end
"This means that the period from march 16th to april 14th will be rounded to April 1st"
function shifted_monthperiod(date)
    return round(date, Month(1), RoundNearestTiesUp)
end

function monthperiod(date)
    return round(date, Month(1), RoundDown)
end

function general_station_compare(
    eratype,
    stations;
    load_data_func,
    load_era_func,
    comparecolnames,
    groupfunc,
    median_group_func,
    timeperiod = (typemin(DateTime), typemax(DateTime)),
    timecol = "datetime",
    grouped_or_ungrouped = :grouped_data,
    n_obs_weighting = false,
    eradatadir = eradatadir,
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
        ismissing(analyzed_data) && continue
        analyzed_data = getproperty(analyzed_data, grouped_or_ungrouped)
        newtimecol = Symbol(groupfunc)
        select!(analyzed_data, newtimecol => timecol, Not(newtimecol))
        push!(station_data, analyzed_data)
        push!(used_stations, id)
    end

    basinmean = basin_aggregate(station_data; timecol = timecol, n_obs_weighting)

    if ismissing(basinmean)
        return missing
    end

    sort!(basinmean, timecol)

    return (basindata = basinmean, stationdata = Dictionary(used_stations, station_data))
end
