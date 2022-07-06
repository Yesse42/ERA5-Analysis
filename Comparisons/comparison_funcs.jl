using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays, JLD2
burrowactivate()
import ERA5Analysis as ERA
nrcsdatadir = "$(ERA.NRCSDATA)/cleansed/"

function compare_with_ERA(;
    station_path,
    station_meta_path,
    dailyname::Symbol,
    monthlyname::Symbol,
    id_colname = :ID,
    savedir = "../data",
)
    eradatadir = "$(ERA.ERA5DATA)/extracted_points/"

    stations = CSV.read(station_path, DataFrame)

    station_data = CSV.read(station_meta_path, DataFrame)

    station_names = stations[!, id_colname]
    eratypes = ERA.eratypes
    data_by_station = Dictionary()
    for id in stations.ID

        #Skip if there is no extracted point there due to glaciation for either ERA5 type
        if !all(isfile.(joinpath.(eradatadir, eratypes, "$id.csv")))
            continue
        end

        #Now filter for the name of the column we want; it should have SWE and this ID in it
        colname = "SWE_$id"

        this_station_data = select(station_data, :datetime, colname => :Station)

        eras = DataFrame[]
        for eratype in ["Land", "Base"]
            times = CSV.read(joinpath(eradatadir, eratype, "times.csv"), DataFrame)
            data = CSV.read(joinpath(eradatadir, eratype, "$id.csv"), DataFrame)
            #Set to midnight for later joining
            times.datetime .-= Hour(12)
            #Convert to mm
            data.sd .*= 1e3
            eradata = rename!(hcat(times, data), [:datetime, Symbol(eratype)])
            push!(eras, eradata)
        end

        outdf = dropmissing(innerjoin(this_station_data, eras...; on = :datetime))
        if isempty(outdf)
            continue
        end
        insert!(data_by_station, id, outdf)
    end

    #Now that we've loaded everything in we can start analyzing

    #Things we'll be analyzing
    analysisarray = Array{Any}(undef, length.((data_by_station, eratypes)))
    labeled_data_array = AxisArray(
        analysisarray;
        station = collect(keys(data_by_station)),
        eratype = eratypes,
    )

    dailydata = Array{Any}(undef, length.((data_by_station, eratypes)))
    labeled_daily =
        AxisArray(dailydata; station = collect(keys(data_by_station)), eratype = eratypes)

    rmsd(diffarr) = sqrt(sum(x^2 for x in diffarr) / length(diffarr))

    for (i, (station, data)) in enumerate(zip(keys(data_by_station), data_by_station))
        for (j, eratype) in enumerate(eratypes)
            groupingcols = [eratype, "Station"]
            withmonth = transform(data, :datetime => ByRow(month) => :month)
            #1991-2020 normals
            filter!(row -> 1991 <= year(row.datetime) <= 2020, withmonth)
            #Skip this station if it's empty
            if isempty(withmonth)
                analysisarray[i, j] = missing
                dailydata[i, j] = missing
                continue
            end
            groupmonth = groupby(withmonth, :month)

            #Now get mean and median values
            monthstats = combine(
                groupmonth,
                groupingcols .=> mean .=> groupingcols .* "_Mean",
                groupingcols .=> median .=> groupingcols .* "_Median",
            )
            #Make a convenience function to get means and medians by month
            function getmonthstat(time, datasource, stat = "Median")
                idx = findfirst(==(month(time)), monthstats.month)
                if isnothing(idx)
                    return missing
                end
                return monthstats[idx, "$(datasource)_$stat"]
            end
            #Now calculate the differences, differences in anomalies, and differences in percent of normal
            groupcolswithtime = vcat(groupingcols, ["datetime"])
            diffdata = transform(
                data,
                groupingcols => ByRow(-) => :era_station_diff,
                groupcolswithtime =>
                    ByRow(
                        (x, y, t) ->
                            x - y - getmonthstat(t, eratype) + getmonthstat(t, "Station"),
                    ) => :anomaly_diff,
                groupcolswithtime =>
                    ByRow(
                        (x, y, t) ->
                            100 * (
                                x / getmonthstat(t, eratype) -
                                y / getmonthstat(t, "Station")
                            ),
                    ) => :pom_diff,
            )
            dropmissing!(diffdata)
            #Now calculate the mean differences and RMSD by month, for all available times, not just 1991-2020
            diffdata_withmonth = transform(diffdata, :datetime => ByRow(month) => :month)
            group_diff = groupby(diffdata_withmonth, :month)
            groupcols = String.([:era_station_diff, :anomaly_diff, :pom_diff])
            month_diff_stats = combine(
                group_diff,
                groupcols .=> mean .=> groupcols .* "_Mean",
                groupcols .=> rmsd .=> groupcols .* "_RMSD",
            )
            analysisarray[i, j] = outerjoin(monthstats, month_diff_stats; on = :month)
        end
    end

    jldsave("$savedir/$dailyname.jld2"; dailyname => labeled_daily)
    return jldsave("$savedir/$monthlyname.jld2"; monthlyname = labeled_data_array)
end
