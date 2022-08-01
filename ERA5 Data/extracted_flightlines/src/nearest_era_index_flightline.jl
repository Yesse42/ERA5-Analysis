cd(@__DIR__)
burrowactivate()
using CSV,
    DataFrames,
    Dates,
    NCDatasets,
    Dictionaries,
    JLD2,
    Shapefile,
    NearestNeighbors,
    Distances,
    StaticArrays
import ERA5Analysis as ERA

#Some functions to be used later; this one detects a glacier or missing data
function isglacier(era_sd; glacier_thresh = 0.95, snow_thresh = 1e-3)
    era_sd[ismissing.(era_sd)] .= NaN

    return (
        (sum(era_sd .> snow_thresh; dims = 3) ./ size(era_sd, 3)) .>= glacier_thresh
    ) .|| isnan.(era_sd[:, :, 1])
end

#First get a list of Alaska flightlines with data
akflightlines = CSV.read("$(ERA.NOHRSCDATA)/ak_gamma.csv", DataFrame).station_id

#Load in the flightline's shapefile too, and make a dictionary
flightlines = DataFrame(Shapefile.Table("$(ERA.NOHRSCDATA)/flines.shp"))
select!(
    flightlines,
    :geometry => :path,
    :NAME => ByRow(str -> String7(strip(str, '\0'))) => :station_id,
)
filter!(row -> row.station_id in akflightlines, flightlines)

#This script will find the nearest ERA5 grid points to each flight line
for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    sd_data = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
    sd = sd_data["sd"][:]
    glacier_mask = isglacier(sd_data["sd"][:])
    lonlatgrid = SVector.(sd_data["longitude"][:], sd_data["latitude"][:]')
    lonlatidxs = CartesianIndices(lonlatgrid)

    nntree = BallTree(vec(lonlatgrid), Haversine{Float32}())

    #Now iterate through each flightline
    fline_to_nearest_neighbor = Dictionary{String, Vector{Tuple{Int, Int}}}()
    for flightline in eachrow(flightlines)
        points = flightline.path.points
        flightline_points = SVector.(getproperty.(points, :x), getproperty.(points, :y))
        close_points = NTuple{2, Int}[]
        #Find the closest ERA5 grid point for each point of the flightline, and ensure that it is not glacier
        for point in flightline_points
            closest_idx, _ = nn(nntree, point)
            closest_idx = lonlatidxs[closest_idx]
            !glacier_mask[closest_idx] && push!(close_points, Tuple(closest_idx))
        end
        #If there are no available points go on your merry way
        if isempty(close_points)
            continue
        end
        close_points = unique(close_points)
        #chuck any of those points which are at places where era5 may be missing
        nonmissing_idxs = mapslices(
            x -> !any(ismissing(x)),
            sd[CartesianIndex.(close_points), :];
            dims = [2],
        )[:]
        close_points = close_points[nonmissing_idxs]
        if isempty(close_points)
            continue
        end
        insert!(fline_to_nearest_neighbor, flightline.station_id, close_points)
    end

    display(fline_to_nearest_neighbor)
    #Now save the data of the nearest neighbors. I don't feel like formatting this into a CSV, so it gets JLD2'd
    jldsave(
        "../data/$(eratype)_fline_nearest_neighbors.jld2";
        fline_nearest_neighbors = fline_to_nearest_neighbor,
    )
end
