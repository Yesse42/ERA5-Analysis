using DataFrames, Dates, NearestNeighbors, Dictionaries, StaticArrays

include.(
    joinpath.(
        ERA.COMPAREDIR,
        "Load Scripts",
        "load_" .* ["snow_course", "snotel"] .* ".jl",
    )
)

"""
The specification of the metric function is important. It is passed many keyword args,
with eratype, stationmetadata, glacierbool, eralonlat, eraelevation, eravals, stationvals, and times as fields.
It should return some type which can be sorted with sort, and the index of the best value is returned
along with the value and index of all points which were considered.
"""
function era_best_neighbor(;
    eratype,
    sd,
    eratime,
    glaciermask,
    lonlatgrid,
    lonlatballtree,
    elevationdata,
    stationmetadata,
    searchwindow,
    metric_func,
)
    station_loc = SVector(stationmetadata.Longitude, stationmetadata.Latitude)

    stationload_func = if stationmetadata.Network == "SNOTEL"
        load_snotel
    else
        load_snow_course
    end
    stationvals = stationload_func(stationmetadata.ID)
    rename!(stationvals, [:datetime, :station])

    nn_id = getindex(CartesianIndices(lonlatgrid), nn(lonlatballtree, station_loc)[1])

    used_ids = CartesianIndex{2}[]
    neighbor_scores = nothing
    #Now loop through the search window, evaluating the metric at each point and storing the value
    for I in
        max(nn_id - searchwindow, CartesianIndex(1, 1)):min(
        nn_id + searchwindow,
        CartesianIndex(size(lonlatgrid)),
    )
        push!(used_ids, I)

        eravals = @view sd[I, :]
        eradata = DataFrame(; datetime = eratime, era = eravals, copycols = false)

        combo = dropmissing!(innerjoin(eradata, stationvals; on = :datetime))

        score = metric_func(;
            stationmetadata,
            glacierbool = glaciermask[I],
            eralonlat = lonlatgrid[I],
            eraelevation = elevationdata[I],
            eratype,
            eravals = combo.era,
            stationvals = combo.station,
            times = combo.datetime,
        )
        if isnothing(neighbor_scores)
            neighbor_scores = [score]
        else
            push!(neighbor_scores, score)
        end
    end

    neighbor_scores[isnan.(neighbor_scores)] .= Inf

    return_idx = argmin(neighbor_scores)
    if isinf(neighbor_scores[return_idx])
        return missing
    else
        return (; best = used_ids[return_idx], used_ids, neighbor_scores)
    end
end

function best_points(;
    eratype,
    sd,
    eratime,
    glaciermask,
    lonlatgrid,
    lonlatballtree,
    elevationdata,
    metadatas,
    network_metrics,
    searchwindow,
)
    best_neighbor_df = DataFrame(; id = [], best = [], score_array = [], idx_array = [])
    for networktype in ERA.networktypes
        metadata = metadatas[networktype]
        metric_func = network_metrics[networktype]
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
                searchwindow,
                metric_func,
            )
            if ismissing(out)
                push!(
                    best_neighbor_df,
                    (
                        id = stationmetadata.ID,
                        best = missing,
                        score_array = missing,
                        idx_array = missing,
                    ),
                )
            else
                push!(
                    best_neighbor_df,
                    (
                        id = stationmetadata.ID,
                        best = Tuple(out.best),
                        score_array = out.neighbor_scores,
                        idx_array = out.used_ids,
                    ),
                )
            end
        end
    end
    return best_neighbor_df
end
