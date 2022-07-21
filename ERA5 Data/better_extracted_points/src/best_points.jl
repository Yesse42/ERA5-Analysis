cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, NearestNeighbors, Dictionaries, Distances, StaticArrays
import ERA5Analysis as ERA

include("metric_defs.jl")
include("find_most_representative_point.jl")

#Some functions to be used later; this one detects a glacier or missing data
function isglacier(era_sd; glacier_thresh = 0.95, min_snow = 1e-3)
    era_sd[ismissing.(era_sd)] .= NaN
    return ((sum(era_sd .> min_snow; dims = 3) ./ size(era_sd, 3)) .>= glacier_thresh) .||
           isnan.(era_sd[:, :, 1])
end

# #Pre-load some stuff
# sds = Dictionary{String, Any}()
# glacier_masks = Dictionary{String, Array{Bool, 2}}()
# elevations_datas = Dictionary{String, Array{Float32, 2}}()
# lonlatgrids = Dictionary{String, Array{SVector{2, Float32}, 2}}()
# times = Dictionary{String, Vector{Date}}()

# for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
#     sd_data = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
#     sd = sd_data["sd"][:]
#     elev_data = Dataset(
#         "$(ERA.ERA5DATA)/extracted_points/data/$(eratype)_aligned_elevations.nc",
#         "r",
#     )
#     elevations = elev_data["elevation_m"][:]
#     glacier_mask = isglacier(sd_data["sd"][:])
#     lonlatgrid = SVector.(sd_data["longitude"][:], sd_data["latitude"][:]')
#     time = Date.(sd_data["time"][:])
#     insert!.(
#         [glacier_masks, elevations_datas, lonlatgrids, times, sds],
#         eratype,
#         [glacier_mask[:, :], elevations, lonlatgrid, time, sd],
#     )
#     close(sd_data)
#     close(elev_data)
# end

metadatas = Dictionary(ERA.networktypes, 
CSV.read.(joinpath.(ERA.NRCSDATA, "cleansed", ERA.networktypes.*"_Metadata.csv"), DataFrame))
metrics = Dictionary(ERA.networktypes, [snotelmetric, coursemetric])

for eratype in ERA.eratypes
    sd = sds[eratype]
    eratime = times[eratype]
    glaciermask = glacier_masks[eratype]
    lonlatgrid = lonlatgrids[eratype]
    lonlatballtree = BallTree(vec(lonlatgrid), Distances.Haversine{Float32}())
    elevationdata = elevations_datas[eratype]

    best_neighbor_df = DataFrame(id = [], lonidx = [], latidx = [])
    for networktype in ERA.networktypes
        metadata = metadatas[networktype]
        metric_func = metrics[networktype]
        for stationmetadata in eachrow(metadata)
            out = era_best_neighbor(;
                eratype,
                sd,
                eratime,
                glaciermask,
                lonlatgrid,
                lonlatballtree,
                elevationdata,
                stationmetadata,
                searchwindow = CartesianIndex(15, 5),
                metric_func,
            )
            ismissing(out) && continue
            best_ids = Tuple(out.best)
            push!(best_neighbor_df, (id = stationmetadata.ID, lonidx = best_ids[1], latidx = best_ids[2]))
        end
    end
    CSV.write("../data/$(eratype)_best_ids.csv", best_neighbor_df)
end