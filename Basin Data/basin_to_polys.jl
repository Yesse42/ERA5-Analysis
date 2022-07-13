cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA
using Dictionaries, DataFrames, Shapefile, JLD2, StaticArrays

polydict = Dictionary{String, Vector{Vector{SVector{2, Float32}}}}()

huc_paths = "HUC_Shapes/WBDHU".*string.([6,8]).*".shp"
shapes = Dictionary([6,8],Shapefile.Table.(huc_paths))

for (basin, hucs) in zip(ERA.basin_names, ERA.allowed_hucs)
    basinpolys = Vector{SVector{2, Float32}}[]
    for huc in hucs
        shapefile = shapes[length(huc)]
        huc_idx = findfirst( ==(huc), getproperty(shapefile, Symbol("huc$(length(huc))")))
        #and use that to grab the polygon
        my_polygon = shapefile.geometry[huc_idx]
        points = my_polygon.points
        xpoints, ypoints = getproperty.(points, :x), getproperty.(points, :y)
        partitions = my_polygon.parts 
        #Now loop through each part and construct the polygons
        for part_idx in eachindex(partitions)
            #Account for 1 based indexing
            upper_idx = if part_idx == length(partitions) length(points) else partitions[part_idx+1] end
            idxs = (partitions[part_idx] + 1):upper_idx
            bpoints = SVector{2, Float32}.(xpoints[idxs], ypoints[idxs])
            if bpoints[end] ≠ bpoints[begin] push!(bpoints, bpoints[begin]) end
            push!(basinpolys, bpoints)
        end
    end
    insert!(polydict, basin, basinpolys)
end

jldsave("basin_to_polys.jld2", basin_to_polys = polydict)