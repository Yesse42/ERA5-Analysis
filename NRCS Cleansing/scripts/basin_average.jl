cd(@__DIR__)
using CSV, DataFrames, Dates, StatsBase

include("../data/wanted_stations.jl")

wanted_stations = CSV.read("../data/cleansed/Relevant_Stations.csv", DataFrame)

networks = ["SNOTEL", "Snow Course"]

mymean(thing) = if all(ismissing.(thing)) return missing else return mean(skipmissing(thing)) end

for networktype in networks
    data = CSV.read("../data/cleansed/$(replace(networktype, ' '=>'_'))_Data.csv", DataFrame)
    time = data[:, :Date]
    #Now average it all together and save it
    for (basin_name, hucs) in zip(basin_names, allowed_ids)
        #Get all data files which are in at least one of the basins
        stations = [row.ID for row in eachrow(wanted_stations) if occursin(networktype, row.Network) && any(occursin.(hucs, "$(row.HUC)"))]
        #Load them in and average the snow depth if the file actually exists
        station_timeseries = []
        for station in stations
            idx = "SWE_$(station)"
            if !any(occursin.(idx, names(data))) continue end
            push!(station_timeseries, data[:, idx])
        end
        means = [mymean(getindex(timeseries, i) for timeseries in station_timeseries) for i in eachindex(station_timeseries[1])]

        #Save as file with the basin name
        CSV.write("../data/basin_averages/$basin_name-$networktype-avgs.csv", DataFrame(datetime=time, mean_sd=means))
    end
end