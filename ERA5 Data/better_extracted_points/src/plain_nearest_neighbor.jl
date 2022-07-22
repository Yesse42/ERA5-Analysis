cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, NearestNeighbors, Dictionaries, Distances, StaticArrays, JLD2
import ERA5Analysis as ERA

include("metric_defs.jl")
include("find_most_representative_point.jl")

const windowsize = CartesianIndex(9,3)

#Some functions to be used later; this one detects a glacier or missing data
function isglacier(era_sd; glacier_thresh = 0.95, min_snow = 1e-3)
    era_sd[ismissing.(era_sd)] .= NaN
    return ((sum(era_sd .> min_snow; dims = 3) ./ size(era_sd, 3)) .>= glacier_thresh) .||
           isnan.(era_sd[:, :, 1])
end

#Pre-load some stuff
sds = Dictionary{String, Any}()
glacier_masks = Dictionary{String, Array{Bool, 2}}()
elevations_datas = Dictionary{String, Array{Float32, 2}}()
lonlatgrids = Dictionary{String, Array{SVector{2, Float32}, 2}}()
times = Dictionary{String, Vector{Date}}()

for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    sd_data = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
    sd = sd_data["sd"][:]
    elev_data = Dataset(
        "$(ERA.ERA5DATA)/extracted_points/data/$(eratype)_aligned_elevations.nc",
        "r",
    )
    elevations = elev_data["elevation_m"][:]
    glacier_mask = isglacier(sd_data["sd"][:])
    lonlatgrid = SVector.(sd_data["longitude"][:], sd_data["latitude"][:]')
    time = Date.(sd_data["time"][:])
    insert!.(
        [glacier_masks, elevations_datas, lonlatgrids, times, sds],
        eratype,
        [glacier_mask[:, :], elevations, lonlatgrid, time, sd],
    )
    close(sd_data)
    close(elev_data)
end

all_metadatas = Dictionary(ERA.networktypes, 
CSV.read.(joinpath.(ERA.NRCSDATA, "cleansed", ERA.networktypes.*"_Metadata.csv"), DataFrame))

savedir = "../plain_nn"

function plain_distance(;kwargs...) 
    #Check that this isn't on the sea or glacier
    all(val == 0 for val in kwargs[:eravals]) || kwargs[:glacierbool] && return Inf
    sdata = kwargs[:stationmetadata]
    statlonlat = SVector(sdata.Longitude, sdata.Latitude)
    return Distances.Haversine{Float64}()(kwargs[:eralonlat], statlonlat)
end

for eratype in ERA.eratypes
    sd = sds[eratype]
    eratime = times[eratype]
    glaciermask = glacier_masks[eratype]
    lonlatgrid = lonlatgrids[eratype]
    lonlatballtree = BallTree(vec(lonlatgrid), Distances.Haversine{Float32}())
    elevationdata = elevations_datas[eratype]

    nn_points = best_points(;eratype, sd, eratime, glaciermask, lonlatgrid, lonlatballtree, elevationdata,
    metadatas, network_metrics = Dict(ERA.networktypes.=>plain_distance), searchwindow = windowsize)
    CSV.write("$savedir/$(eratype)_best_ids.csv", select(nn_points, :id, :best=>collect=>[:lonidx, :latidx]))
    for row in eachrow(nn_points)
        sd_at_loc = sd[row.best..., :]
        if all(ismissing.(sd_at_loc))
            continue
        end
        CSV.write(joinpath(savedir, "$(eratype)/$(row.id).csv"), DataFrame(; sd = sd_at_loc))
    end
    CSV.write(joinpath(savedir, "$(eratype)/times.csv"), DataFrame(; datetime = eratime))
end