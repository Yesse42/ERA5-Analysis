cd(@__DIR__)
burrowactivate()
datadir(paths...)=joinpath("../data/", paths...)

using CSV, DataFrames, Dictionaries, JLD2
import ERA5Analysis as ERA 

#We want to filter the Metadata to contain just the stations we want. Also create a dictionary to
#conveniently map between basin HUC's and their associated station ids

metadata = CSV.read("../data/cleansed/Metadata.csv", DataFrame)

huc_to_basin = Dict([huc=>basin for (hucs, basin) in zip(ERA.allowed_hucs, ERA.basin_names) for huc in hucs])

for network in ERA.networktypes
    basin_to_id=Dictionary{String, Vector{String}}(ERA.basin_names, [String[] for i in 1:length(ERA.basin_names)])
    network_data = CSV.read("../data/cleansed/$(network)_Data.csv", DataFrame)
    #Check each row of the metadata table
    for row in eachrow(metadata)
        for huc in keys(huc_to_basin)
            if occursin(huc, string(row.HUC))
                #Now confirm that we have data for the station, and that it is in the proper network
                !any(occursin.(row.ID, names(network_data))) && continue
                #If we do push it
                push!(basin_to_id[huc_to_basin[huc]], row.ID)
            end
        end
    end

    #Now recover the basin from the ID
    display(basin_to_id)
    basin_from_id = Dict([id=>basin for (basin, ids) in collect(pairs(basin_to_id)) for id in ids])

    jldsave("../data/cleansed/$(network)_basin_to_id.jld2", basin_to_id=basin_to_id)
    id_indices = findall(id->id in reduce(vcat, collect(basin_to_id)), metadata.ID)
    new_metadata = metadata[id_indices, :]
    transform!(new_metadata, :ID=>ByRow(x->basin_from_id[x])=>:Basin)

    CSV.write("../data/cleansed/$(network)_Metadata.csv",new_metadata)
    display(nrow(new_metadata))
end