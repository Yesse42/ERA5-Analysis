using CSV, DataFrames, Dates, Dictionaries, StatsBase, RecursiveArrayTools
burrowactivate()
import ERA5Analysis as ERA, Base.Iterators as Itr

"""This wondrous function expects a list of stations, and a dict of sttaions to data, which
it will then use to aggregate the data. Expects a vector of dataframes for each station"""
function basin_aggregate(datavec; timecol = :datetime, aggfunc = mean)
    isempty(datavec) && return missing
    not_time_vars = filter(x -> x ≠ string(timecol), names(datavec[1]))
    #Get the times into a common format
    all_times = outerjoin([data[:,[timecol]] for data in datavec]..., on=timecol)
    #Now get all the other variables into the same time scale you just made 
    revised_data = [outerjoin(data, all_times; on=timecol) for data in datavec]

    #Now make vectors of vectors for each data column
    combined_data = [VectorOfArray([data[!, name] for data in datavec]) for name in not_time_vars]

    #Now apply a special aggfunction
    na_or_miss(x) = ismissing(x) || isnan(x)
    special_aggfunc(x) =
        if all(Itr.map(na_or_miss, x))
            return NaN
        else
            return aggfunc(Itr.filter(!na_or_miss, x))
        end
    count_na_or_miss(x...) = count(!na_or_miss, x)

    basinmeans = DataFrame([vec(mapslices(special_aggfunc, combodat, dims=(2,))) for combodat in combined_data], not_time_vars)

    basinmeans[!, timecol] = all_times[!, timecol]

    return basinmeans
end
