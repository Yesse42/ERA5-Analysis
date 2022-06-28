cd(@__DIR__)
using Shapefile, DataFrames, CSV, NCDatasets, Dictionaries, PolygonOps, StaticArrays

HUC6_path = "../data/HUC_Shapes/WBDHU6.shp"
HUC8_path = "../data/HUC_Shapes/WBDHU8.shp"

eratypes=["Base","Land"]
eradirs = ["ERA5-SD-1979-2022-CREATE-2022-06-16.nc", "ERA5-Land-SD-1979-2022-DL-2022-6-15.nc"]
era5dirs = "../../".*eratypes.*"/".*eradirs
#Load in the netcdf data now
datasets = Dictionary(eratypes, NCDataset.(era5dirs, "r"))
lats =  getindex.(getindex.(datasets, "latitude"),:)
lons =  getindex.(getindex.(datasets, "longitude"),:)
sds = getindex.(getindex.(datasets, "sd"),:)
for sd in sds sd[ismissing.(sd)] .= NaN end
function isglacier(sd_arr; glacier_thresh=0.95)
    glacier_mask = (sum(sd_arr .> 0; dims=3) ./ size(sd_arr, 3)) .>= glacier_thresh
end
glacierarrs = Dictionary(eratypes, isglacier.(sds))
#Set missing areas to show as glacier so they are excluded as well
for (glaciermask, sd) in zip(glacierarrs, sds) glaciermask[ismissing.(sd[:,:,1]), 1] .= true end
lonlats = Dictionary(eratypes, [SVector.(lon, lat') for (lon,lat) in zip(lons,lats)])

shapes = Dictionary([6,8],DataFrame.(Shapefile.Table.([HUC6_path, HUC8_path])))

include("../../../NRCS Cleansing/data/wanted_stations.jl")

#For each eratype, extract the indices of valid era5 points in the basin using a point in lat-lon polygon method
for eratype in eratypes
    for (basins, basinname) in zip(allowed_ids, basin_names)
        allowed_points = SVector{2, Int}[]
        for basin in basins
            basinlen = length(basin)
            basinshapes = shapes[basinlen]
            #Now find the specific basin in the shapetable
            basin_idx = findfirst( ==(basin), basinshapes[!, "huc$basinlen"])
            #and use that to grab the polygon
            my_polygon = basinshapes[basin_idx, :geometry]
            #And extract the lat and lon of the polygon
            poly_verts = SVector{2, Float32}.(getproperty.(my_polygon.points, :x), getproperty.(my_polygon.points, :y))
            if poly_verts[end] ≠ poly_verts[begin]
                push!(poly_verts, poly_verts[1])
            end

            #And now loop through every point and check if it's in the basin
            erapoints = lonlats[eratype]
            glacier_mask = glacierarrs[eratype]
            for era_point_idx in CartesianIndices(erapoints)
                if inpolygon(erapoints[era_point_idx], poly_verts) == 1 && !glacier_mask[era_point_idx]
                    push!(allowed_points, SVector(Tuple(era_point_idx)...))
                end
            end
        end
        CSV.write("../$eratype/$(basinname)_era_points.csv", DataFrame(lonidx = first.(allowed_points), latidx = last.(allowed_points)))
    end
end