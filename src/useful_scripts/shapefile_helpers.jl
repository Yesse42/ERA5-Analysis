using Shapefile, StaticArrays

function shape_to_sarr(geometry; close = false)
    points = geometry.points
    polygon = SVector.(getproperty.(points, :x), getproperty.(points, :y))
    if (polygon[begin] ≠ polygon[end]) && close
        push!(polygon, polygon[begin])
    end
    return polygon
end
