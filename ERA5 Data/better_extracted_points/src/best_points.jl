cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, NearestNeighbors, Dictionaries, Distances, StaticArrays, JLD2
import ERA5Analysis as ERA

include("metric_defs.jl")
include("find_most_representative_point.jl")

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

fold_types = ["Every 3rd year", "3 periods"]

"Returns true every nth year"
every_nth_year(n_folds, foldnum) = function f(timevec)
    timeyears = unique(year(t) for t in timevec)
    year_to_in_fold = Dictionary(timeyears, ((0:length(timeyears)-1) .% n_folds) .== (foldnum - 1))
    return getindex.(Ref(year_to_in_fold), year.(timevec))
end
"Returns true for the foldnumth section of the n_folds the timeseries is evenly split into"
n_periods(n_folds, foldnum) = function f(timevec)
    timeyears = unique(year(t) for t in timevec)
    year_to_in_fold = Dictionary(timeyears, fld.(0:length(timeyears)-1, length(timeyears)/n_folds) .== (foldnum - 1))
    return getindex.(Ref(year_to_in_fold), year.(timevec))
end

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
network_metrics = Dictionary(ERA.networktypes, [snotelmetric, coursemetric])



for eratype in ERA.eratypes
    sd = sds[eratype]
    eratime = times[eratype]
    glaciermask = glacier_masks[eratype]
    lonlatgrid = lonlatgrids[eratype]
    lonlatballtree = BallTree(vec(lonlatgrid), Distances.Haversine{Float32}())
    elevationdata = elevations_datas[eratype]

    outdf = best_points(;eratype, sd, eratime, glaciermask, lonlatgrid, lonlatballtree, elevationdata,
    metadatas, network_metrics, searchwindow = CartesianIndex(15, 5))
    select!(outdf, :id, :best=>collect=>[:lonidx, :latidx])
    CSV.write("../data/$(eratype)_best_ids.csv", outdf)
end