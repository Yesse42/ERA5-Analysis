cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, NearestNeighbors
import ERA5Analysis as ERA
include("nearest_era_index_machinery.jl")

#A special distance function which weights both elevation differences and horizontal ones
#100m elevation diff is equal to a 5km distance diff
weight_func(eldiff, dist) = eldiff / 100 + (dist / 5000)

#Load in the stations too
stations =
    CSV.read.("$(ERA.NRCSDATA)/cleansed/" .* ERA.networktypes .* "_Metadata.csv", DataFrame)
stations = vcat(stations...)

#This script will find the nearest ERA5 grid point to each station
for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    outdf = era_best_neighbors(eratype, erafile, stations)
    CSV.write("../data/$(eratype)_chosen_points.csv")
end
