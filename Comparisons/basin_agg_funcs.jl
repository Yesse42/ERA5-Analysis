using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays, JLD2
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

function basin_agg(analysis_data, basin_to_stations, basins)
    outarr = AxisArray(
        fill(DataFrame(), 2, length(basins));
        eratype = ERA.eratypes,
        basin = basins,
    )

    for eratype in ERA.eratypes
        for basin in basins
            ids = basin_to_stations[basin]

            ids_with_data =
                filter(id -> string(id) in string.(analysis_data.axes[1].val), ids)

            #Now get the associated list of data
            data = analysis_data[station = ids_with_data, eratype = eratype]
            data = data[(!).(ismissing.(data))]

            ids_with_data = data.axes[1].val

            varnames = names(data[1])[2:end]

            newnames = [
                ["month"; names(data[1])[2:end] .* "_" .* station] for
                station in ids_with_data
            ]

            renameddata = rename.(data.data, newnames)

            basindata = outerjoin(renameddata...; on = :month)

            sort!(basindata, :month)

            basinmean = select!(
                basindata,
                :month,
                (
                    Regex.(varnames) .=>
                        ByRow((x...) -> mean(skipmissing(x))) .=> varnames
                )...,
                Regex(varnames[1]) => ((x...) -> length(x)) => :n_stations,
            )
            outarr[basin = basin, eratype = eratype] = basinmean
        end
    end
    return outarr
end
