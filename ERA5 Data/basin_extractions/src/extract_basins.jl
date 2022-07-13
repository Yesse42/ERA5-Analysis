cd(@__DIR__)
burrowactivate()
using DataFrames, CSV, NCDatasets, Dictionaries, PolygonOps, StaticArrays, JLD2
import ERA5Analysis as ERA

HUC6_path, HUC8_path =
    joinpath.("$(ERA.BASINDATA)/HUC_Shapes", "WBDHU" .* ["6", "8"] .* ".shp")

eratypes = ERA.eratypes
eradirs = ERA.erafiles
era5dirs = "$(ERA.ERA5DATA)/" .* eratypes .* "/" .* eradirs
#Load in the netcdf data now
datasets = Dictionary(eratypes, NCDataset.(era5dirs, "r"))
lats = getindex.(getindex.(datasets, "latitude"), :)
lons = getindex.(getindex.(datasets, "longitude"), :)
sds = getindex.(getindex.(datasets, "sd"), :)
for sd in sds
    sd[ismissing.(sd)] .= NaN
end
function isglacier(sd_arr; glacier_thresh = 0.95)
    return glacier_mask = (sum(sd_arr .> 0; dims = 3) ./ size(sd_arr, 3)) .>= glacier_thresh
end
glacierarrs = Dictionary(eratypes, isglacier.(sds))
#Set missing areas to show as glacier so they are excluded as well
for (glaciermask, sd) in zip(glacierarrs, sds)
    glaciermask[ismissing.(sd[:, :, 1]), 1] .= true
end
lonlats = Dictionary(eratypes, [SVector.(lon, lat') for (lon, lat) in zip(lons, lats)])

basin_to_polys = jldopen(joinpath(ERA.BASINDATA, "basin_to_polys.jld2"))["basin_to_polys"]

function kernel_func!(allowed_points, erapoints, polys, glacier_mask)
    for era_point_idx in CartesianIndices(erapoints)
        if any(inpolygon.(Ref(erapoints[era_point_idx]), polys) .== 1) &&
           !glacier_mask[era_point_idx]
            push!(allowed_points, SVector(Tuple(era_point_idx)...))
        end
    end
end

#For each eratype, extract the indices of valid era5 points in the basin using a point in lat-lon polygon method
for eratype in eratypes
    for basin in ERA.basin_names
        allowed_points = SVector{2, Int}[]
        polys = basin_to_polys[basin]

        #And now loop through every point and check if it's in the basin
        erapoints = lonlats[eratype]
        glacier_mask = glacierarrs[eratype]
        kernel_func!(allowed_points, erapoints, polys, glacier_mask)
        CSV.write(
            "../$eratype/$(basin)_era_points.csv",
            DataFrame(; lonidx = first.(allowed_points), latidx = last.(allowed_points)),
        )
    end
end
