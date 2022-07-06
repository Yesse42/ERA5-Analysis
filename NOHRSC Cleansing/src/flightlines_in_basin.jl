cd(@__DIR__)
burrowactivate()
using CSV,
    DataFrames, Dates, NCDatasets, Dictionaries, JLD2, Shapefile, PolygonOps, StaticArrays
import ERA5Analysis as ERA

swe_data = CSV.read("../data/ak_gamma.csv", DataFrame)

flines = unique(swe_data.station_id)

fline_shapefile = DataFrame(Shapefile.Table("../data/flines.shp"))

transform!(
    fline_shapefile,
    :NAME => ByRow(x -> strip(x, '\0')) => :ID,
    :geometry => ByRow(x -> ERA.shape_to_sarr(x; close = true)) => :polygon,
)

basin_shape_paths = "$(ERA.BASINDATA)/HUC_Shapes/WBDHU" .* string.([6, 8]) .* ".shp"

basin_shapes = Dictionary([6, 8], DataFrame.(Shapefile.Table.(basin_shape_paths)))

basin_polys = Dictionary{String, Vector{SVector{2, Float64}}}()
for (basin_huc, basin) in zip(ERA.allowed_hucs, ERA.basin_names)
    basin_huc = only(basin_huc)
    basin_shapefile = basin_shapes[length(basin_huc)]
    basin_idx = findfirst(==(basin_huc), basin_shapefile[!, "huc$(length(basin_huc))"])
    #and use that to grab the polygon
    my_polygon = basin_shapefile[basin_idx, :geometry]
    insert!(basin_polys, basin, ERA.shape_to_sarr(my_polygon; close = true))
end

for eratype in ERA.eratypes
    basin_to_flines = Dictionary(ERA.basin_names, [String[] for _ in ERA.basin_names])
    for fline in flines
        fline_idx = findfirst(==(fline), fline_shapefile.ID)
        if isnothing(fline_idx)
            println(fline)
            continue
        end
        fline_points = ERA.shape_to_sarr(fline_shapefile[fline_idx, :geometry])
        for (basin_huc, basin) in zip(ERA.allowed_hucs, ERA.basin_names)
            basin_poly = basin_polys[basin]
            if any(inpolygon.(fline_points, Ref(basin_poly)) .== 1)
                push!(basin_to_flines[basin], fline)
            end
        end
    end
    display(basin_to_flines)
    jldsave("../data/$(eratype)_basin_to_flines.jld2"; basin_to_flines)
end
