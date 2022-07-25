cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA
using Dictionaries, DataFrames, Shapefile, JLD2, StaticArrays

polydict = Dictionary{String, Vector{Vector{SVector{2, Float32}}}}()

huc_paths = "HUC_Shapes/WBDHU" .* string.(ERA.hucsizes) .* ".shp"
shapes = Dictionary(ERA.hucsizes, Shapefile.Table.(huc_paths))

include("shape_poly_to_sarrs.jl")

for (basin, hucs) in zip(ERA.basin_names, ERA.allowed_hucs)
    basinpolys = Vector{SVector{2, Float32}}[]
    for huc in hucs
        shapefile = shapes[length(huc)]
        huc_idx = findfirst(==(huc), getproperty(shapefile, Symbol("huc$(length(huc))")))
        #and use that to grab the polygon
        my_polygon = shapefile.geometry[huc_idx]
        polyvec = shape_poly_to_sarrs(my_polygon)
        append!(basinpolys, polyvec)
    end
    insert!(polydict, basin, basinpolys)
end

jldsave("basin_to_polys.jld2"; basin_to_polys = polydict)
