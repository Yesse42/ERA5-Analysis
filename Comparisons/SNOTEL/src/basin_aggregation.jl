using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays, JLD2
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

analysis_data = jldopen("../data/snotel_monthly_data.jld2")["snotel_monthly_data"]
basin_to_stations = jldopen("$(ERA.NRCSDATA)/cleansed/SNOTEL_basin_to_id.jld2")["basin_to_id"]

for eratype in ERA.eratypes
    for basin in ERA.basin_names
        ids = basin_to_stations[basin]

        ids_with_data = filter(id -> id in string.(analysis_data.axes[1].val), ids)

        #Now get the associated list of data
        data = analysis_data[station = ids_with_data, eratype = eratype]
        data = data[(!).(ismissing.(data))]

        ids_with_data = data.axes[1].val

        varnames = names(data[1])[2:end]
        
        newnames = [["month"; names(data[1])[2:end].*"_".*station] for station in ids_with_data]

        renameddata = rename.(data.data, newnames)

        basindata = outerjoin(renameddata...; on=:month)

        sort!(basindata, :month)

        basinmean = select!(basindata, :month, (Regex.(varnames).=>ByRow((x...)->mean(skipmissing(x))).=>varnames)...)
        display((basin, eratype))
        println()
        display(round.(basinmean; digits=1))
    end
end