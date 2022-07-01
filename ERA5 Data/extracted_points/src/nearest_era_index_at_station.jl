cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets
import ERA5Analysis as ERA
include("../../nearest_geodetic_neighbor.jl")

#Some functions to be used later; this one detects a glacier or missing data
function isglacier(era_sd; glacier_thresh=0.95)
    era_sd[ismissing.(era_sd)] .= NaN

    return ((sum(era_sd .> 0; dims=3) ./ size(era_sd, 3)) .>= glacier_thresh) .| ismissing.(era_sd[:,:,1])
end

#A special distance function which weights both elevation differences and horizontal ones
#100m elevation diff is equal to a 5km distance diff
weight_func(eldiff, dist) = eldiff/100 + dist/5000

#Load in the stations too
stations = CSV.read.("$(ERA.NRCSDATA)/cleansed/".*ERA.networktypes.*"_Metadata.csv", DataFrame)
stations = vcat(stations...)

#This script will find the nearest ERA5 grid point to each station
for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    sd_data = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile","r")
    sd = sd_data["sd"][:]
    elev_data = Dataset("../data/$(eratype)_aligned_elevations.nc","r")
    elevations = elev_data["elevation_m"][:]
    glacier_mask = isglacier(sd_data["sd"][:])
    lonlatgrid = tuple.(sd_data["longitude"][:], sd_data["latitude"][:]')
    station_locs = tuple.(stations.Longitude, stations.Latitude)

    #Now get the nearest neighbor indices
    nearest_neighbors = brute_nearest_neighbor_idx.(station_locs, Ref(lonlatgrid))

    #Now we must go through the 9 gridpoints closest to the nearest neighbor and select one that is not on the sea,
    #or a glacier, and that is close by the above defined weighting function
    out_neighbor_df = DataFrame(stat_id = String[], lonidx = Int[], latidx = Int[], era_point_el = Float16[])
    for (statdata, I) in zip(eachrow(stations), nearest_neighbors)
        offset = CartesianIndex(1,1)
        near_idxs = I-offset:I+offset

        elev_data = elevations[near_idxs]

        elev_data[glacier_mask[near_idxs]] .= NaN

        #Now calculate the weights
        eldiffs = abs.(statdata.Elevation_m .- elev_data)
        near_lonlat = lonlatgrid[near_idxs]
        dists = great_circ_dist.(Ref((statdata.Longitude, statdata.Latitude)), near_lonlat)
        weight_data = weight_func.(eldiffs, dists)

        #Now get the ordering of the weight data from lowest to highest (NaNs will float to the top))
        order = sortperm(weight_data[:])
        #Only accept the points with the 4 lowest weights
        for i in order[1:4]
            if !isnan(eldiffs[i])
                idx = Tuple(near_idxs[i])
                push!(out_neighbor_df, (stat_id=string(statdata.ID), lonidx=idx[1], latidx=idx[2], era_point_el=elev_data[i]))
                break
            end
        end
    end

    #Now save the data on the nearest neighbors, including the row, column, station name, and elevation
    CSV.write("../data/$(eratype)_chosen_points.csv", out_neighbor_df)
end





