cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, NearestNeighbors, Dictionaries, Distances, StaticArrays, JLD2
import ERA5Analysis as ERA

all_data = jldopen("../../elevation_weight_data/rmsd_data.jld2")["rmsd_data"]

optimal_search_weights = Dictionary{NTuple{2,String}, Float64}()

for eratype in ERA.eratypes
    for basin in ERA.basin_names
        rmsd_data = all_data[(basin, eratype)]
        rmsd_data = rmsd_data[mapslices(row->all((!isnan).(row[2:end])), Array(rmsd_data), dims=2)[:], :]

        #Use the normal equations to fit a plane solution
        b = rmsd_data.rmsd
        A = hcat(rmsd_data.dist, rmsd_data.eldiff, repeat([1], length(rmsd_data.eldiff)))
        lstsq_plane = (A'*A)\(A'*b)
        elevation_distance_rel_weight = lstsq_plane[2]/lstsq_plane[1]
        insert!(optimal_search_weights, (basin, eratype), elevation_distance_rel_weight)
    end
end

jldsave("../../elevation_weight_data/optimal_relative_weights.jld2", optimal_relative_weights = optimal_search_weights)