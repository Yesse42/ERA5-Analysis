using DataFrames, Dates, NearestNeighbors, Dictionaries, StaticArrays

include.(joinpath.(ERA.COMPAREDIR, "Load Scripts", "load_".*["snow_course","snotel"].*".jl"))

"""
The specification of the metric function is important. It is passed many keyword args,
with eratype, stationmetadata, glacierbool, eralonlat, eraelevation, eravals, stationvals, and times as fields.
It should return some type which can be sorted with the less than func, with smaller values better;
the default lt is Base.isless.
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
    lt = isless,
)

    station_loc = SVector(stationmetadata.Longitude, stationmetadata.Latitude)

    nn_id = getindex(CartesianIndices(lonlatgrid), nn(lonlatballtree, station_loc)[1])

    used_ids = CartesianIndex{2}[]
    neighbor_scores = nothing
    #Now loop through the search window, evaluating the metric at each point and storing the value
    for I in max(nn_id-searchwindow, CartesianIndex(1,1)):min(nn_id+searchwindow, CartesianIndex(size(lonlatgrid)))
        push!(used_ids, I)

        eravals = @view sd[I, :]
        stationload_func = if stationmetadata.Network == "SNOTEL" load_snotel else load_snow_course end
        stationvals = stationload_func(stationmetadata.ID)
        rename!(stationvals, [:datetime, :station])
        eradata = DataFrame(;datetime = eratime, era = eravals, copycols = false)

        combo = dropmissing!(innerjoin(eradata, stationvals; on=:datetime))

        score = metric_func(;stationmetadata, glacierbool = glaciermask[I],
        eralonlat = lonlatgrid[I], eraelevation = elevationdata[I], eratype, eravals = combo.era, 
        stationvals = combo.station, times = combo.datetime)
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
        return (;best = used_ids[return_idx], used_ids, neighbor_scores)
    end
end