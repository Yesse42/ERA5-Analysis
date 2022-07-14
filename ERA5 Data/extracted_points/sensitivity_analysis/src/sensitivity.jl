cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, Plots, StaticArrays, Dictionaries, ColorSchemes, JLD2
import ERA5Analysis as ERA

include(joinpath(ERA.COMPAREDIR, "Snow_Course", "src", "comparison_machinery.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.ERA5DATA, "extracted_points", "src", "nearest_era_index_machinery.jl"))

basin_to_ids = jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]
snow_course_stations = CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_Metadata.csv"), DataFrame)
era_datas = Dictionary(ERA.eratypes, Dataset.(joinpath.(ERA.ERA5DATA, ERA.eratypes, ERA.erafiles)))
era_sds = (x->x.*1e3).(getindex.(getindex.(era_datas, "sd"), :))
era_times = (x->Date.(x)).(getindex.(getindex.(era_datas, "time"), :))
close.(era_datas)

"""An analysis of how sensitive the outcome of our experiment is to different weighting functions and the size of the
'best nearby grid point' search window"""
function sensitivity(eratype, erafile, basin, offset, weight_func)
    #Bring in the stations for this basin
    ids = basin_to_ids[basin]
    stations = filter(row->row.ID in ids, snow_course_stations)

    #Bring in the ERA data too
    
    sd = era_sds[eratype]
    time = era_times[eratype]

    #Now get the nearest neighbor indices
    nn_df = era_best_neighbors(eratype, stations; offset, weight_func)
    id_to_nn_dict = Dictionary(nn_df.stat_id, CartesianIndex.(nn_df.lonidx, nn_df.latidx))
    id_to_nn(id) = get(id_to_nn_dict, id, missing)

    #Make a function to give the era5 data associated with a station
    function era5_from_id(_, _, id)
        era_idx = id_to_nn(id)
        ismissing(era_idx) && return missing
        era_df = DataFrame(datetime = time, era_swe = @view(sd[era_idx, :]); copycols = false)
        return era_df
    end

    #Now pass each station, along with the above functions, into the basin summary generator
    summary_stats = general_course_compare(eratype, ids; load_course_func = load_snow_course, load_era_func = era5_from_id, groupfunc = mymonth)

    ismissing(summary_stats) && return missing

    #And grab the Percent of Median diff RMSD for the March 16th-April 15th period, and return it
    return (pom_diff_rmsd = only(summary_stats[summary_stats.datetime .== 4, :pom_diff_rmsd]), nmissing = length(ids)-nrow(nn_df))
end

#The offsets of the bounding box used to search for the best fit
offsets = CartesianIndex.([(0,0), (3, 1), (6, 2), (9,3), (12,4), (15, 5), (18, 6)])
#The number of meters of distance needed to be equivalent to 1 meter of elevation in the weighting function
relweights = [40, 100, 500, 1500, 3000, 5000, 10000]
weight_funcs = [f(eldiff, dist) = eldiff + dist/weight for weight in relweights]

enu=enumerate

best_weight_offset_dict = Dictionary()

for basin in ERA.basin_names
    for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
        println((basin, eratype))
        rmsd_arr = fill(NaN, length(offsets), length(relweights))
        nmiss_arr = deepcopy(rmsd_arr)
        for (i,offset) in enu(offsets)
            for (j, (weight, weight_func)) in enu(zip(relweights, weight_funcs))
                offset == CartesianIndex(0,0) && weight ≠ first(relweights) && continue
                run_data = sensitivity(eratype, erafile, basin, offset, weight_func)
                ismissing(run_data) && continue
                rmsd_arr[i,j] = run_data.pom_diff_rmsd
                nmiss_arr[i,j] = run_data.nmissing
            end
        end
        #Get the best rmsd for this basin
        best_idxs = getindex.(Ref(CartesianIndices(rmsd_arr)), sortperm(vec(rmsd_arr)))
        #Choose the idx with the lowest rmsd with no missing stations
        best_idx = Tuple(first(best_index for best_index in best_idxs if nmiss_arr[best_index] == 0))

        #Now put them in a dict
        insert!(best_weight_offset_dict, (basin, eratype), (offset = offsets[best_idx[1]], weight = relweights[best_idx[2]]))

        #Now plot the results too
        pretty_offsets = string.(Tuple.(offsets))
        pretty_weights = string.(relweights)
        myc = :Spectral_11
        p1 = heatmap(pretty_weights,pretty_offsets,rmsd_arr; title="% of Median Diff RMSD", c = myc, ylabel="Offset", xlabel = "1m of elevation equivalent to this many meters of distance")
        p2 = heatmap(pretty_weights,pretty_offsets,nmiss_arr; title="# Missing", c = myc, ylabel="Offset", xlabel = "1m of elevation equivalent to this many meters of distance")
        p = plot(p1, p2, layout = (2,1), plot_title="ERA5-$eratype S. Course in $basin Basin")
        savefig(p, "../vis/$eratype/$(basin)_$(eratype)_sensitivity_summary.png")
    end
end

#Now save the dict
jldsave("../data/best_weight_offset_dict.jld2"; best_weight_offset_dict)
display(best_weight_offset_dict)