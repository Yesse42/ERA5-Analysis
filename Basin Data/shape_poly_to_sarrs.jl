burrowactivate()
import ERA5Analysis as ERA
using Dictionaries, DataFrames, Shapefile, JLD2, StaticArrays

function shape_poly_to_sarrs(my_polygon)
    polys = Vector{SVector{2, Float64}}[]
    points = my_polygon.points
    xpoints, ypoints = getproperty.(points, :x), getproperty.(points, :y)
    partitions = my_polygon.parts
    #Now loop through each part and construct the polygons
    for part_idx in eachindex(partitions)
        #Account for 1 based indexing
        upper_idx = if part_idx == length(partitions)
            length(points)
        else
            partitions[part_idx + 1]
        end
        idxs = (partitions[part_idx] + 1):upper_idx
        bpoints = SVector{2, Float32}.(xpoints[idxs], ypoints[idxs])
        if bpoints[end] ≠ bpoints[begin]
            push!(bpoints, bpoints[begin])
        end
        push!(polys, bpoints)
    end
    return polys
end
