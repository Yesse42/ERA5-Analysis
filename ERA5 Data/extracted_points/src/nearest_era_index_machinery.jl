burrowactivate()
using CSV,
    DataFrames, Dates, NCDatasets, NearestNeighbors, Distances, StaticArrays, Dictionaries
import ERA5Analysis as ERA

#Some functions to be used later; this one detects a glacier or missing data
function isglacier(era_sd; glacier_thresh = 0.95)
    era_sd[ismissing.(era_sd)] .= NaN
    return ((sum(era_sd .> 0; dims = 3) ./ size(era_sd, 3)) .>= glacier_thresh) .|
           ismissing.(era_sd[:, :, 1])
end

#A special distance function which weights both elevation differences and horizontal ones
#100m elevation diff is equal to a 5km distance diff
weight_func(eldiff, dist) = eldiff / 100 + dist / 5000

gi = getindex

#Pre-load some stuff
glacier_masks = Dictionary{String, Array{Bool, 2}}()
elevations_datas = Dictionary{String, Array{Float32, 2}}()
lonlatgrids = Dictionary{String, Array{SVector{2, Float32}, 2}}()
for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    sd_data = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
    elev_data = Dataset(
        "$(ERA.ERA5DATA)/extracted_points/data/$(eratype)_aligned_elevations.nc",
        "r",
    )
    elevations = elev_data["elevation_m"][:]
    glacier_mask = isglacier(sd_data["sd"][:])
    lonlatgrid = SVector.(sd_data["longitude"][:], sd_data["latitude"][:]')
    insert!.(
        [glacier_masks, elevations_datas, lonlatgrids],
        eratype,
        [glacier_mask[:, :], elevations, lonlatgrid],
    )
    close(sd_data)
    close(elev_data)
end

function era_best_neighbors(
    eratype,
    stations;
    offset = CartesianIndex(3, 1),
    weight_func = weight_func,
)
    glacier_mask = glacier_masks[eratype]
    elevations = elevations_datas[eratype]
    lonlatgrid = lonlatgrids[eratype]

    station_locs = SVector.(stations.Longitude, stations.Latitude)

    #Now make a balltree
    mytree = BallTree(vec(lonlatgrid), Distances.Haversine{Float32}())

    #Now get the nearest neighbor indices
    nearest_neighbors, _ = nn(mytree, station_locs)
    nearest_neighbors = getindex.(Ref(CartesianIndices(lonlatgrid)), nearest_neighbors)

    #Now we must go through the 9 gridpoints closest to the nearest neighbor and select one that is not on the sea,
    #or a glacier, and that is close by the above defined weighting function
    out_neighbor_df = DataFrame(;
        stat_id = String15[],
        lonidx = Int16[],
        latidx = Int16[],
        era_point_el = Float16[],
    )
    for (statdata, I) in zip(eachrow(stations), nearest_neighbors)
        near_idxs = max(I - offset, CartesianIndex(1,1)):min(I + offset, CartesianIndex(size(elevations)))

        elev_data = elevations[near_idxs]

        elev_data[glacier_mask[near_idxs]] .= NaN

        #Now calculate the weights
        eldiffs = abs.(statdata.Elevation_m .- elev_data)
        near_lonlat = lonlatgrid[near_idxs]
        dists =
            Haversine{Float64}().(Ref((statdata.Longitude, statdata.Latitude)), near_lonlat)
        weight_data = weight_func.(eldiffs, dists)

        #Now get the ordering of the weight data from lowest to highest (NaNs will float to the top))
        order = sortperm(weight_data[:])
        #Only accept the points with the 4 lowest weights
        for i in order[1:min(4, length(order))]
            if !isnan(eldiffs[i])
                idx = Tuple(near_idxs[i])
                push!(
                    out_neighbor_df,
                    (
                        stat_id = string(statdata.ID),
                        lonidx = idx[1],
                        latidx = idx[2],
                        era_point_el = elev_data[i],
                    ),
                )
                break
            end
        end
    end
    return out_neighbor_df
end
