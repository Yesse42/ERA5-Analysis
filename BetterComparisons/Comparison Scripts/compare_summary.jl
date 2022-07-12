using CSV,
    DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays, JLD2, Missings
burrowactivate()
import ERA5Analysis as ERA

StatsBase.rmsd(x) = sqrt(sum(x_i^2 for x_i in x) / length(x))

function comparison_summary(
    data,
    comparecols,
    timecol;
    normal_times = (1991, 2020),
    anom_stat = "median",
)
    comparecols = string.(comparecols)
    timecol = string(timecol)

    withmonth = transform(data, timecol => ByRow(month) => :month)
    #1991-2020 normals
    filter!(row -> normal_times[1] <= year(row.datetime) <= normal_times[2], withmonth)
    #Skip this station if it's empty
    if isempty(withmonth)
        return StationIsEmpty
    end
    groupmonth = groupby(withmonth, :month)

    mystat(stat) = f(x) =
        if all(ismissing.(x))
            return missing
        else
            return stat(filter(!ismissing, x))
        end
    #Now get mean and median values
    monthstats = combine(
        groupmonth,
        comparecols .=> mystat(mean) .=> comparecols .* "_mean",
        comparecols .=> mystat(median) .=> comparecols .* "_median",
    )
    #Make a convenience function to get means and medians by month
    function getmonthstat(time, datasource, stat = anom_stat)
        idx = findfirst(==(month(time)), monthstats.month)
        if isnothing(idx)
            return missing
        end
        return monthstats[idx, "$(datasource)_$stat"]
    end
    #Now calculate the differences, differences in anomalies, and differences in percent of normal
    comparecols_time = [[comparecol; timecol] for comparecol in comparecols]
    anomfuncs = [((x, t) -> x - getmonthstat(t, col)) for col in comparecols]
    pomfuncs = (((x, t) -> 100x / getmonthstat(t, col)) for col in comparecols)
    diffdata = transform(
        data,
        (comparecols_time .=> ByRow.(anomfuncs) .=> comparecols .* "_anom")...,
        (comparecols_time .=> ByRow.(pomfuncs) .=> comparecols .* "_pom")...,
    )
    statcols = vec(comparecols .* permutedims(["_anom", "_pom"]))
    transform!(
        diffdata,
        comparecols => ByRow(-) => :raw_diff,
        comparecols .* "_anom" => ByRow(-) => :anomaly_diff,
        comparecols .* "_pom" => ByRow(-) => :pom_diff,
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

    diffdata_withmonth = transform(diffdata, timecol => ByRow(month) => :month)
    group_diff = groupby(diffdata_withmonth, :month)
    groupcols = String.([:raw_diff, :anomaly_diff, :pom_diff])
    month_diff_stats = combine(
        group_diff,
        groupcols .=> mystat(mean) .=> groupcols .* "_mean",
        groupcols .=> mystat(rmsd) .=> groupcols .* "_rmsd",
        comparecols => my2argstat(cor) => "corr",
        comparecols .* "_anom" => my2argstat(cor) => "anom_corr",
        comparecols .* "_pom" => my2argstat(cor) => "pom_corr",
    )

    diff_month_stats = outerjoin(monthstats, month_diff_stats; on = :month)

    #Now also calculate means for each monthlong period
    diffdata_month_period = transform(
        diffdata,
        timecol => ByRow(x -> Dates.round(x, Month(1), RoundDown)) => timecol,
    )
    group_month_period = groupby(diffdata_month_period, timecol)
    monthperiodstats = combine(
        group_month_period,
        groupcols .=> mean .=> groupcols .* "_mean",
        groupcols .=> rmsd .=> groupcols .* "_rmsd",
        comparecols .=> mean .=> comparecols .* "_mean",
        comparecols .=> median .=> comparecols .* "_median",
        statcols .=> mean .=> statcols .* "_mean",
    )

    return (
        dailydata = diffdata,
        monthperioddata = monthperiodstats,
        monthmeandata = diff_month_stats,
    )
end
