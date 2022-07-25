cd(@__DIR__)
burrowactivate()
using CSV,
    DataFrames, Dates, NCDatasets, Dictionaries, JLD2, Shapefile, PolygonOps, StaticArrays
import ERA5Analysis as ERA

include(joinpath(ERA.BASINDATA, "shape_poly_to_sarrs.jl"))

swe_data = CSV.read("../data/ak_gamma.csv", DataFrame)

flines = unique(swe_data.station_id)

fline_shapefile = DataFrame(Shapefile.Table("../data/flines.shp"))

transform!(
    fline_shapefile,
    :NAME => ByRow(x -> strip(x, '\0')) => :ID,
    :geometry => ByRow(geom -> only(shape_poly_to_sarrs(geom))) => :polygon,
)

basin_shape_paths = "$(ERA.BASINDATA)/HUC_Shapes/WBDHU" .* string.(ERA.hucsizes) .* ".shp"

basin_shapes = Dictionary(ERA.hucsizes, DataFrame.(Shapefile.Table.(basin_shape_paths)))

basin_polys = Dictionary{String, Vector{Vector{SVector{2, Float64}}}}()
for (basin_hucs, basin) in zip(ERA.allowed_hucs, ERA.basin_names)
    all_huc_polys = Vector{SVector{2, Float64}}[]
    for basin_huc in basin_hucs
        basin_shapefile = basin_shapes[length(basin_huc)]
        basin_idx = findfirst(==(basin_huc), basin_shapefile[!, "huc$(length(basin_huc))"])
        #and use that to grab the polygon
        my_polygon = basin_shapefile[basin_idx, :geometry]
        append!(all_huc_polys, shape_poly_to_sarrs(my_polygon))
    end
    insert!(basin_polys, basin, all_huc_polys)
end

for eratype in ERA.eratypes
    basin_to_flines = Dictionary(ERA.basin_names, [String[] for _ in ERA.basin_names])
    for fline in flines
        fline_idx = findfirst(==(fline), fline_shapefile.ID)
        if isnothing(fline_idx)
            println(fline)
            continue
        end
        fline_points = only(shape_poly_to_sarrs(fline_shapefile[fline_idx, :geometry]))
        for (basin_huc, basin) in zip(ERA.allowed_hucs, ERA.basin_names)
            basin_polygons = basin_polys[basin]
            if any(inpolygon.(fline_points, permutedims(basin_polygons)) .== 1)
                push!(basin_to_flines[basin], fline)
            end
        end
    end
    display(basin_to_flines)
    jldsave("../data/$(eratype)_basin_to_flines.jld2"; basin_to_flines)
end
