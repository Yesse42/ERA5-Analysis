using CSV, DataFrames, Dates, Dictionaries, StatsBase, RecursiveArrayTools
burrowactivate()
import ERA5Analysis as ERA, Base.Iterators as Itr

"""This wondrous function expects a list of stations, and a dict of sttaions to data, which
it will then use to aggregate the data. Expects a vector of dataframes for each station"""
function basin_aggregate(datavec; timecol = :datetime, n_obs_weighting = false)
    isempty(datavec) && return missing
    not_time_vars = filter(x -> x ≠ string(timecol) && x ≠ "n_obs", names(datavec[1]))
    #Get the times into a common format
    all_times = if length(datavec) > 1
        outerjoin([data[:, [timecol]] for data in datavec]...; on = timecol)
    else
        datavec[1][:, [timecol]]
    end
    #Now get all the other variables into the same time scale you just made 
    revised_data = [outerjoin(data, all_times; on = timecol) for data in datavec]

    #Now make vectors of vectors for each data column
    combined_data =
        [VectorOfArray([data[!, name] for data in revised_data]) for name in not_time_vars]

    n_obs = VectorOfArray([data[!, :n_obs] for data in revised_data])

    #Now apply a special aggfunction
    na_or_miss(x) = ismissing(x) || isnan(x) || isinf(x)
    meanfunc = if !n_obs_weighting
        skipmiss_mean(x, _) = begin
            if all(Itr.map(na_or_miss, x))
                return NaN
            else
                return mean(filter(!na_or_miss, x))
            end
        end
    else
        weighted_skipmiss_mean(x, weights) = begin
            ismiss = map(na_or_miss, x)
            notmiss = (!).(ismiss) .&& (!).(na_or_miss.(weights))
            if all(ismiss)
                return NaN
            else
                return sum(x[notmiss] .* weights[notmiss] ./ sum(weights[notmiss]))
            end
        end
    end
    count_na_or_miss(x...) = count(!na_or_miss, x)

    basinmeans = DataFrame(
        [
            vec([
                meanfunc(data, weights) for
                (data, weights) in zip(eachrow(combodat), eachrow(n_obs))
            ]) for combodat in combined_data
        ],
        not_time_vars,
    )

    basinmeans[!, timecol] = all_times[!, timecol]

    return basinmeans
end
