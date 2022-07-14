cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, NearestNeighbors
import ERA5Analysis as ERA
include("nearest_era_index_machinery.jl")

#A special distance function which weights both elevation differences and horizontal ones
#100m elevation diff is equal to a 5km distance diff
standard_weight_func(eldiff, dist) = eldiff / 100 + (dist / 5000)

#Load in the stations too
stations =
    CSV.read.("$(ERA.NRCSDATA)/cleansed/" .* ERA.networktypes .* "_Metadata.csv", DataFrame)
stations = vcat(stations...)

basin_to_snotels, basin_to_snow_courses =
    getindex.(
        jldopen.(
            joinpath.(ERA.NRCSDATA, "cleansed", ERA.networktypes .* "_basin_to_id.jld2")
        ),
        "basin_to_id",
    )

#Load in the dict of the optimal search parameters for each basin
best_params_dict = jldopen(
    joinpath(
        ERA.ERA5DATA,
        "extracted_points",
        "sensitivity_analysis",
        "data",
        "best_weight_offset_dict.jld2",
    ),
)["best_weight_offset_dict"]

#This script will find the nearest ERA5 grid point to each station
for eratype in ERA.eratypes
    outdfs = DataFrame[]
    for basin in ERA.basin_names
        ids = vcat(basin_to_snotels[basin], basin_to_snow_courses[basin])
        basin_stations = filter(x -> string.(x.ID) in ids, stations)
        search_params = best_params_dict[(basin, eratype)]
        offset = search_params.offset
        weight_func(eldiff, dist) = eldiff + dist / (search_params.weight)
        push!(outdfs, era_best_neighbors(eratype, basin_stations; offset, weight_func))
    end
    outdf = reduce(vcat, outdfs)
    CSV.write("../data/$(eratype)_chosen_points.csv", outdf)
end
