using CSV, DataFrames, Dates, Dictionaries, StatsBase, RecursiveArrayTools
burrowactivate()
import ERA5Analysis as ERA, Base.Iterators as Itr

na_or_miss(x) = ismissing(x) || isnan(x) || isinf(x)
function weighted_mean(row, weights)
    notmiss = map(!na_or_miss, row) .&& map(!na_or_miss, weights)
    return sum(row[notmiss] .* weights[notmiss]) ./ sum(weights[notmiss])
end

"""This wondrous function expects a list of stations, and a dict of sttaions to data, which
it will then use to aggregate the data. Expects a vector of dataframes for each station"""
function basin_aggregate(datavec; timecol = :datetime, aggregate_func = weighted_mean)
    isempty(datavec) && return missing
    not_time_vars = filter(x -> x ≠ string(timecol) && x ≠ "n_obs", names(datavec[1]))
    #Get the times into a common format
    all_times = if length(datavec) > 1
        outerjoin([data[:, [timecol]] for data in datavec]...; on = timecol)
    else
        datavec[1][:, [timecol]]
    end
    sort!(all_times, timecol)
    #Now get all the other variables into the same time scale you just made 
    revised_data =
        [sort!(leftjoin(all_times, data; on = timecol), timecol) for data in datavec]

    #Now make vectors of vectors for each data column
    combined_data =
        [reduce(hcat, [data[!, name] for data in revised_data]) for name in not_time_vars]

    n_obs = reduce(hcat, [data[!, :n_obs] for data in revised_data])

    basinmeans = DataFrame(
        [
            [
                aggregate_func(data, weights) for
                (data, weights) in zip(eachrow(combodat), eachrow(n_obs))
            ] for combodat in combined_data
        ],
        not_time_vars,
    )

    basinmeans[!, timecol] = all_times[!, timecol]

    return basinmeans
end
