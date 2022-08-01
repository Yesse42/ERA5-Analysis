using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, JLD2, Missings
burrowactivate()
import ERA5Analysis as ERA, Base.Iterators as Itr

monthgroup(time) = round(time, Month(1), RoundDown)

function comparison_summary(
    data,
    comparecols,
    timecol;
    normal_times = (1991, 2020),
    anom_stat = "median",
    groupfunc,
    median_group_func,
)
    data = dropmissing(data)
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
    #Now get mean and median values
    monthstats = combine(
        groupmonth,
        comparecols .=> mean .=> comparecols .* "_mean",
        comparecols .=> std .=> comparecols .* "_std",
        comparecols .=> median .=> comparecols .* "_median",
    )
    monthstatdict = Dict([
        (group, dsource, stat) => monthstats[
            findfirst(==(group), monthstats[!, median_group_name]),
            "$(dsource)_$stat",
        ] for group in monthstats[!, median_group_name], dsource in comparecols,
        stat in ["mean", "std", "median"]
    ])
    #Make a convenience function to get means and medians by month
    function getmonthstat(time, datasource; stat = anom_stat)
        return get(monthstatdict, (median_group_func(time), datasource, stat), missing)
    end
    #Now calculate the differences, differences in anomalies, and differences in percent of normal
    comparecols_time = [[comparecol; timecol] for comparecol in comparecols]
    anomfuncs = [((x, t) -> x - getmonthstat(t, col)) for col in comparecols]
    normedanomfuncs = [
        ((x, t) -> (x - getmonthstat(t, col)) / getmonthstat(t, col; stat = "std")) for
        col in comparecols
    ]
    fomfuncs = [((x, t) -> x / getmonthstat(t, col)) for col in comparecols]
    diffdata = transform(
        data,
        (comparecols_time .=> ByRow.(anomfuncs) .=> comparecols .* "_anom")...,
        (comparecols_time .=> ByRow.(fomfuncs) .=> comparecols .* "_fom")...,
        (comparecols_time .=> ByRow.(normedanomfuncs) .=> comparecols .* "_normed_anom")...,
    )
    statcols = permutedims(comparecols) .* [""; "_" .* ["anom", "normed_anom", "fom"]]

    #Now the second variable of comparecol should have all of its values (raw swe, anomaly, normed_anomaly)
    #translated into percent of median USING THE FIRST VARIABLE'S median and standard deviation
    #This is so all calculated RMSDs have the same units
    raw_names = comparecols[2] .* ["", "_anom", "_normed_anom"]
    raw_names_with_time = [[name, timecol] for name in raw_names]
    transform_funcs =
        ByRow.([
            (x, t) -> x / getmonthstat(t, comparecols[1]),
            (x, t) ->
                (x + getmonthstat(t, comparecols[1])) / getmonthstat(t, comparecols[1]),
            (x, t) ->
                (
                    x * getmonthstat(t, comparecols[1]; stat = "std") +
                    getmonthstat(t, comparecols[1])
                ) / getmonthstat(t, comparecols[1]),
        ])
    as_fom_names = raw_names .* "_as_col1_fom"
    dropmissing!(diffdata)
    transform!(diffdata, (raw_names_with_time .=> transform_funcs .=> as_fom_names)...)

    #Now take the differences between the first datacol's percent of median and the
    #second datacol's 4 different guesses of the first column's percent of median

    col2_as_fom_names = [as_fom_names; comparecols[2] .* "_fom"]
    input_cols = [[comparecols[1] .* "_fom"; col] for col in col2_as_fom_names]
    stat_types = ["raw", "anom", "normed_anom", "fom"]
    meandiffnames = stat_types .* "_diff_mean"
    rmsdnames = stat_types .* "_rmsd"
    corrnames = stat_types .* "_corr"

    #Now get correlations and RMSDs, and mean differences after grouping by month
    newtimecol = Symbol(groupfunc)
    with_groupcol = transform!(diffdata, timecol => ByRow(groupfunc) => newtimecol)
    grouped_by_groupcol = groupby(with_groupcol, newtimecol)
    # mymean(x) = if isempty(x) return missing else return mean(x) end
    myrmsd(x, y) = sqrt(mean((a - b)^2 for (a, b) in zip(x, y)))
    month_stats = combine(
        grouped_by_groupcol,
        comparecols .* "_fom" .=> mean .=> comparecols .* "_fom_mean",
        (input_cols .=> ((a, b) -> mean(Itr.map(-, a, b))) .=> meandiffnames)...,
        (input_cols .=> myrmsd .=> rmsdnames)...,
        (input_cols .=> StatsBase.Statistics.cor .=> corrnames)...,
        (eachrow(statcols) .=> myrmsd .=> "native_unit_" .* stat_types .* "_rmsd")...,
        #Also throw in the number of observations for weighting purposes
        nrow => :n_obs,
        #Also throw in the RMSD for guessing the climatological median (fraction of median = 1) of the first column
        comparecols[1] .* "_fom" =>
            (x -> myrmsd(x, Itr.repeated(1.0, length(x)))) => :climo_fom_rmsd,
        comparecols[1] .* "_fom" =>
            (x -> StatsBase.Statistics.cor(collect(x), repeat([1.0], length(x)))) =>
                :climo_fom_corr,
    )

    return (ungrouped_data = diffdata, grouped_data = month_stats)
end
