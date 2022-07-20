using CSV,
    DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, JLD2, Missings
burrowactivate()
import ERA5Analysis as ERA, Base.Iterators as Itr

myrmsd(x) = sqrt(sum(x_i^2 for x_i in x) / length(x))

monthgroup(time) = round(time, Month(1), RoundDown)

function comparison_summary(
    data,
    comparecols,
    timecol;
    normal_times = (1991, 2020),
    anom_stat = "median",
    groupfunc = monthgroup,
    median_group_func = month,
)
    comparecols = string.(comparecols)
    timecol = string(timecol)

    median_group_name = Symbol(median_group_func)
    withmonth = transform(data, timecol => ByRow(median_group_func) => median_group_name)
    #1991-2020 normals
    filter!(
        row ->
            normal_times[1] <= year(getproperty(row, Symbol(timecol))) <= normal_times[2],
        withmonth,
    )
    #Skip this station if it's empty
    if isempty(withmonth)
        return missing
    end
    groupmonth = groupby(withmonth, median_group_name)

    mystat(stat) = f(x) =
        if all(Itr.map(ismissing, x))
            return missing
        else
            return stat(filter(!ismissing, x))
        end
    #Now get mean and median values
    monthstats = combine(
        groupmonth,
        comparecols .=> mystat(mean) .=> comparecols .* "_mean",
        comparecols .=> mystat(std) .=> comparecols .* "_std",
        comparecols .=> mystat(median) .=> comparecols .* "_median",
    )
    #Make a convenience function to get means and medians by month
    function getmonthstat(time, datasource; stat = anom_stat)
        idx = findfirst(==(month(time)), monthstats[!, median_group_name])
        if isnothing(idx)
            return missing
        end
        return monthstats[idx, "$(datasource)_$stat"]
    end
    #Now calculate the differences, differences in anomalies, and differences in percent of normal
    comparecols_time = [[comparecol; timecol] for comparecol in comparecols]
    anomfuncs = [((x, t) -> x - getmonthstat(t, col)) for col in comparecols]
    normedanomfuncs = [
        ((x, t) -> (x - getmonthstat(t, col)) / getmonthstat(t, col; stat = "std")) for
        col in comparecols
    ]
    fomfuncs = (((x, t) -> x / getmonthstat(t, col)) for col in comparecols)
    diffdata = transform(
        data,
        (comparecols_time .=> ByRow.(anomfuncs) .=> comparecols .* "_anom")...,
        (comparecols_time .=> ByRow.(fomfuncs) .=> comparecols .* "_fom")...,
        (comparecols_time .=> ByRow.(normedanomfuncs) .=> comparecols .* "_normed_anom")...,
    )
    statistic_names = ["_anom", "_normed_anom", "_fom"]
    statcols = permutedims(comparecols) .* statistic_names
    transform!(
        diffdata,
        comparecols => ByRow(-) => :raw_diff,
        comparecols .* "_anom" => ByRow(-) => :anomaly_diff,
        comparecols .* "_normed_anom" => ByRow(-) => :normed_anomaly_diff,
        comparecols .* "_fom" => ByRow(-) => :fom_diff,
    )
    #Now calculate the mean differences and rmsd by month, for all available times, not just 1991-2020
    my2argstat(stat) = function f(x, y)
        notmiss = (!).(ismissing.(x) .|| ismissing.(y))
        if all((!).(notmiss))
            return missing
        else
            return stat(x[notmiss], y[notmiss])
        end
    end

    groupcolname = Symbol(groupfunc)
    diffdata_withmonth = transform(diffdata, timecol => ByRow(groupfunc) => groupcolname)
    group_diff = groupby(diffdata_withmonth, groupcolname)
    groupcols = String.([:raw_diff, :anomaly_diff, :normed_anomaly_diff, :fom_diff])
    month_diff_stats = combine(
        group_diff,
        comparecols => ((x, y) -> sum((!).(ismissing.(x) .|| ismissing.(y)))) => :n_obs,
        comparecols .=> mystat(mean) .=> comparecols .* "_mean",
        comparecols .=> mystat(median) .=> comparecols .* "_median",
        statcols .=> mystat(mean) .=> statcols .* "_mean",
        groupcols .=> mystat(mean) .=> groupcols .* "_mean",
        groupcols .=> mystat(myrmsd) .=> groupcols .* "_rmsd",
        comparecols => my2argstat(cor) => "corr",
        collect.(eachrow(statcols)) .=> my2argstat(cor) .=> statistic_names .* "_corr",
        comparecols .* "_fom" .=>
            (x -> mystat(mean)(x .- 1)) .=> comparecols .* "_fom_climo_diff_mean",
        comparecols .* "_fom" .=>
            (x -> mystat(myrmsd)(x .- 1)) .=> comparecols .* "_fom_climo_diff_rmsd",
        comparecols .* "_normed_anom" .=>
            (x -> mystat(myrmsd)(x .- mystat(mean)(x))) .=>
                comparecols .* "_normed_anom_climo_diff_rmsd",
    )

    return (ungrouped_data = diffdata, grouped_data = month_diff_stats)
end
