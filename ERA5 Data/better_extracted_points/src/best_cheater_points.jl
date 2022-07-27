cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, NearestNeighbors, Dictionaries, Distances, StaticArrays, JLD2
import ERA5Analysis as ERA

include("metric_defs.jl")
include("find_most_representative_point.jl")

const windowsize = CartesianIndex(15, 5)

include(joinpath(ERA.SCRIPTPATH, "load_era_data.jl"))

network_metrics = Dictionary(ERA.networktypes,[snotelmetric, coursemetric])


for eratype in ERA.eratypes
    sd = sds[eratype]
    eratime = times[eratype]
    glaciermask = glacier_masks[eratype]
    lonlatgrid = lonlatgrids[eratype]
    lonlatballtree = BallTree(vec(lonlatgrid), Distances.Haversine{Float32}())
    elevationdata = elevations_datas[eratype]

    outdf = best_points(;eratype, sd, eratime, glaciermask, lonlatgrid, lonlatballtree, elevationdata,
    metadatas, network_metrics, searchwindow = windowsize)
    mycollect(x) = if ismissing(x) return (missing, missing) else collect(x) end
    select!(outdf, :id, :best=>ByRow(mycollect)=>[:lonidx, :latidx])

    writedir = "../cheater_data"
    CSV.write("$writedir/$(eratype)_best_ids.csv", outdf)
    for row in eachrow(outdf)
        any(ismissing.(collect(row))) && continue
        sd_at_loc = sd[row.lonidx, row.latidx, :]
        if all(ismissing.(collect(sd_at_loc)))
            println(row.id); continue
        end
        CSV.write(joinpath(writedir, "$(eratype)/$(row.id).csv"), DataFrame(; sd = sd_at_loc))
    end
    CSV.write(joinpath(writedir, "$(eratype)/times.csv"), DataFrame(; datetime = eratime))
end