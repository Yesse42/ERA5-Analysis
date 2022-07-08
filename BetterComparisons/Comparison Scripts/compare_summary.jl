using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays, JLD2
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

@enum Messages StationIsEmpty

function comparison_summary(
    comparecols,
    timecol;
    normal_times = (1991, 2020),
    anom_stat = "median",
)
    withmonth = transform(data, timecol => ByRow(month) => :month)
    #1991-2020 normals
    filter!(row -> normal_times[1] <= year(row.datetime) <= normal_times[2], withmonth)
    #Skip this station if it's empty
    if isempty(withmonth)
        return StationIsEmpty
    end
    groupmonth = groupby(withmonth, :month)

    #Now get mean and median values
    monthstats = combine(
        groupmonth,
        comparecols .=> mean .=> comparecols .* "_mean",
        comparecols .=> median .=> comparecols .* "_median",
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
    groupcolswithtime = [comparecols; timecol]
    diffdata = transform(
        data,
        timecol,
        comparecols => ByRow(-) => :raw_diff,
        groupcolswithtime =>
            ByRow(
                (x, y, t) ->
                    x - y - getmonthstat(t, eratype) + getmonthstat(t, "Station"),
            ) => :anomaly_diff,
        groupcolswithtime =>
            ByRow(
                (x, y, t) ->
                    100 * (x / getmonthstat(t, eratype) - y / getmonthstat(t, "Station")),
            ) => :pom_diff,
    )
    #Now calculate the mean differences and rmsd by month, for all available times, not just 1991-2020
    diffdata_withmonth = transform(diffdata, timecol => ByRow(month) => :month)
    group_diff = groupby(diffdata_withmonth, :month)
    groupcols = String.([:raw_station_diff, :anomaly_diff, :pom_diff])
    month_diff_stats = combine(
        group_diff,
        groupcols .=> mean .=> groupcols .* "_mean",
        groupcols .=> rmsd .=> groupcols .* "_rmsd",
    )

    diff_month_stats = outerjoin(monthstats, month_diff_stats; on = :month)

    #Now also calculate means for each monthlong period
    diffdata_month_period = transform(
        diffdata,
        timecol => ByRow(x -> Dates.round(x, Month(1), RoundDown)) => timecol,
    )
    group_month_period = groupby(diffdata_month_period, timecol)
    monthperiodstats = combine(
        diffdata_month_period,
        groupcols .=> mean .=> groupcols .* "_mean",
        groupcols .=> rmsd .=> groupcols .* "_rmsd",
        comparecols .=> mean .=> comparecols .* "_mean",
        comparecols .=> median .=> comparecols .* "_median",
    )

    return (dailydata = diffdata,
            monthperioddata = monthperiodstats,
            monthlymeandata = diff_month_stats)
end
