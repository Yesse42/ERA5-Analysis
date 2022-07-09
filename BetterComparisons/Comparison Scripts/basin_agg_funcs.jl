using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays, JLD2
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

"""This wondrous function expects a list of stations, and a dict of sttaions to data, which
it will then use to aggregate the data. Expects a vector of the dataframe for each station"""
function basin_aggregate(datavec, station_names; timecol=:datetime, aggfunc = mean)
    not_time_vars = filter(x->x≠string(timecol), names(datavec[1]))
    revised_data = [
        select(data, timecol, not_time_vars.=>not_time_vars.*name)
    for (data, name) in zip(datavec, station_names)]
    #Now join all your data together
    basindata = outerjoin(revised_data...; on=timecol)

    #Now apply a special aggfunction
    na_or_miss(x) = ismissing(x) || isnan(x)
    special_aggfunc(x...) = if all(na_or_miss.(x)) return NaN else return aggfunc(filter(!na_or_miss,x)) end
    count_na_or_miss(x...) = count(!na_or_miss, x)

    basinmeans = select!(basindata, timecol, Regex(not_time_vars[1])=>ByRow(count_na_or_miss)=>:count,
                        (Regex.(not_time_vars).=>ByRow(special_aggfunc).=>not_time_vars)...)
    
    return basinmeans
end
