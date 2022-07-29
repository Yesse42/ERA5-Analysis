cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, NearestNeighbors, Dictionaries, Distances, StaticArrays, JLD2
import ERA5Analysis as ERA

include("../metric_defs.jl")
include("../find_most_representative_point.jl")

const windowsize = CartesianIndex(6,2)

include(joinpath(ERA.SCRIPTPATH, "load_era_data.jl"))

basin_to_id = jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

savedir = "../../elevation_weight_data/"

outdict = Dictionary{NTuple{2, String}, DataFrame}()

for eratype in ERA.eratypes
    sd = sds[eratype]
    eratime = times[eratype]
    glaciermask = glacier_masks[eratype]
    lonlatgrid = lonlatgrids[eratype]
    lonlatballtree = BallTree(vec(lonlatgrid), Distances.Haversine{Float32}())
    elevationdata = elevations_datas[eratype]

    for basin in ERA.basin_names
        #We only want to do this with snow courses
        course_ids = basin_to_id[basin]
        only_this_basin = filter(x->string(x.ID) in course_ids, metadatas["Snow_Course"])
        mymetadatas = Dictionary(ERA.networktypes, [DataFrame(), only_this_basin])

        #And now we get the dataframe containing the rmsd's at nearby points
        nn_points = best_points(;eratype, sd, eratime, glaciermask, lonlatgrid, lonlatballtree, elevationdata,
        metadatas = mymetadatas, network_metrics = Dict(ERA.networktypes.=>coursemetric), searchwindow = windowsize)

        #And now fold this thing out into a long dataframe containing the station id, the rmsd, the distance, and the elevation diff
        outdfs = DataFrame[]
        for row in eachrow(nn_points)
            outdata = DataFrame(id=String[], eldiff = Float32[], dist = Float32[], rmsd = Float32[])
            ismissing(row.best) && continue
            scores = row.score_array
            indices = row.idx_array
            elevations = elevationdata[indices]
            lonlats = lonlatgrid[indices]

            station_data = only_this_basin[findfirst(==(string(row.id)), only_this_basin.ID), :]
            station_elevation = station_data.Elevation_m
            station_loc = SVector(station_data.Longitude, station_data.Latitude)
            for i in eachindex(scores)
                isinf(scores[i]) && continue
                push!(outdata, (id = row.id, eldiff = abs(station_elevation - elevations[i]),
                        dist = Haversine{Float64}()(station_loc, lonlats[i]),
                        rmsd = scores[i]))
            end
            push!(outdfs, outdata)
        end
        outdf = reduce(vcat, outdfs)
        #And save
        insert!(outdict, (basin, eratype), outdf)
    end
end

jldsave(joinpath(savedir, "rmsd_data.jld2"), rmsd_data = outdict)
outdict