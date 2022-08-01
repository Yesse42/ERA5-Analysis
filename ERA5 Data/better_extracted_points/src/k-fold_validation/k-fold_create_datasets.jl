cd(@__DIR__)
burrowactivate()
using CSV,
    DataFrames,
    Dates,
    NCDatasets,
    NearestNeighbors,
    Dictionaries,
    Distances,
    StaticArrays,
    InlineStrings
import ERA5Analysis as ERA

const windowsize = CartesianIndex(6, 2)

include("../metric_defs.jl")
include("../find_most_representative_point.jl")

include(joinpath(ERA.SCRIPTPATH, "load_era_data.jl"))

include.(
    joinpath.(
        ERA.COMPAREDIR,
        "Load Scripts",
        "load_" .* ["snow_course", "snotel"] .* ".jl",
    )
)

const monthfunc_by_type = (march_func, endmarch_beginapril)

function get_station_times(station)
    data = nothing
    if all(isnumeric(char) for char in string(station))
        data = load_snotel(station)
        data = data[monthfunc_by_type[1](data.datetime), :]
    else
        data = load_snow_course(station)
        data = data[monthfunc_by_type[2](data.datetime), :]
    end
    return dropmissing!(data).datetime
end

fold_types = ERA.foldtypes

const min_years = 12

"Returns true every nth year"
every_nth_year(n_folds, foldnum) = function f(timevec)
    timeyears = sort!(unique(year(t) for t in timevec))
    #This forces the later analysis to abort, as there is no data outside the fold to fit on
    length(timeyears) < min_years && return trues(length(timevec))
    year_to_in_fold = Dictionary(
        timeyears,
        ((0:(length(timeyears) - 1)) .% n_folds) .== (foldnum - 1),
    )
    return getindex.(Ref(year_to_in_fold), year.(timevec))
end

"Returns true for the foldnumth section of the n_folds the timeseries is evenly split into"
n_periods(n_folds, foldnum) = function f(timevec)
    timeyears = sort!(unique(year(t) for t in timevec))
    length(timeyears) < min_years && return trues(length(timevec))
    year_to_in_fold = Dictionary(
        timeyears,
        fld.(0:(length(timeyears) - 1), length(timeyears) / n_folds) .== (foldnum - 1),
    )
    return getindex.(Ref(year_to_in_fold), year.(timevec))
end

fold_funcs = (every_nth_year, n_periods)

broadcast_not(func) = g(x...; y...) = (!).(func(x...; y...))

const n_folds = 3

const savearea = "../../k-fold_data/"

for eratype in ERA.eratypes
    sd = sds[eratype]
    eratime = times[eratype]
    glaciermask = glacier_masks[eratype]
    lonlatgrid = lonlatgrids[eratype]
    lonlatballtree = BallTree(vec(lonlatgrid), Distances.Haversine{Float32}())
    elevationdata = elevations_datas[eratype]

    for (fold_type, fold_func) in zip(fold_types, fold_funcs)
        #Now make an array to hold the data for each fold
        foldarr = Vector{DataFrame}(undef, n_folds)
        foldtimefuncs = [fold_func(n_folds, fold_num) for fold_num in 1:n_folds]
        for fold_num in 1:n_folds
            #First generate the metric functions, with the appropriate time filters
            #Remember, we want to select all times except for this specific fold
            timefilter = broadcast_not(fold_func(n_folds, fold_num))
            network_timefilters = [function f(timevec)
                a = timefilter(timevec)
                a .= a .&& monthfunc(timevec)
                return a
            end for monthfunc in monthfunc_by_type]
            network_metrics = Dictionary(
                ERA.networktypes,
                [
                    custommetric(
                        tfilter,
                        (x...) -> pom_rmsd(x...; median_groupfunc = (y -> 1)),
                    ) for tfilter in network_timefilters
                ],
            )

            #Get the best points
            outdf = best_points(;
                eratype,
                sd,
                eratime,
                glaciermask,
                lonlatgrid,
                lonlatballtree,
                elevationdata,
                metadatas,
                network_metrics,
                searchwindow = windowsize,
            )

            foldarr[fold_num] = outdf
        end
        #And now stitch the frankenstein timeseries together for each different fold selection function,
        #creating a dict(station=>frankenseries)
        out_dict = Dictionary{
            String,
            NamedTuple{(:time, :sd), Tuple{Vector{Date}, Vector{Float32}}},
        }()
        out_locs = Dictionary{
            String,
            NamedTuple{(:foldnum, :lonlat), Tuple{Vector{Int}, Vector{NTuple{2, Int}}}},
        }()
        for (i, station) in enumerate(foldarr[1].id)
            #Check if any of the folds have no data, if so then move on
            any(ismissing(arr.best[i]) for arr in foldarr) && continue

            #Now get the relevant time periods for each fold, and then extract the era5 data at those times
            outdata = (time = Date[], sd = Float32[])
            outidxs = (foldnum = Int[], lonlat = NTuple{2, Int}[])
            for (foldnumber, (df, timefunc)) in enumerate(zip(foldarr, foldtimefuncs))
                stattime = Date.(get_station_times(station))
                allowed_times = intersect(eratime, stattime)
                timebools = timefunc(allowed_times)
                function is_allowed(time)
                    in_it = searchsorted(allowed_times, time)
                    isempty(in_it) && return false
                    return timebools[only(in_it)]
                end
                allowed_era_indices =
                    [i for (i, time) in enumerate(eratime) if is_allowed(time)]
                append!.(
                    Tuple(outdata),
                    (eratime[allowed_era_indices], sd[df.best[i]..., allowed_era_indices]),
                )
                push!.(Tuple(outidxs), (foldnumber, df.best[i]))
            end
            insert!(out_dict, station, outdata)
            insert!(out_locs, station, outidxs)
        end

        savedir = joinpath(savearea, fold_type, eratype)
        mkpath(savedir)
        jldsave(joinpath(savedir, "eradata.jld2"); station_to_data = out_dict)
        jldsave(joinpath(savedir, "indices.jld2"); station_to_indices = out_locs)
    end
end
