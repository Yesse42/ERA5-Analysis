cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, Dictionaries, JLD2, Shapefile
import ERA5Analysis as ERA
include("../../nearest_geodetic_neighbor.jl")

#Some functions to be used later; this one detects a glacier or missing data
function isglacier(era_sd; glacier_thresh=0.95)
    era_sd[ismissing.(era_sd)] .= NaN
    #The ! and <= here is because NaN is less than any number
    return (!).((sum(era_sd .> 0; dims=3) ./ size(era_sd, 3)) .<= glacier_thresh)
end

#First get a list of Alaska flightlines with data
akflightlines = CSV.read("$(ERA.NOHRSCDATA)/ak_gamma.csv", DataFrame).station_id

#Load in the flightline's shapefile too, and make a dictionary
flightlines = DataFrame(Shapefile.Table("$(ERA.NOHRSCDATA)/flines.shp"))
select!(flightlines, :geometry=>:path, :NAME=>ByRow(str->String7(strip(str, '\0')))=>:station_id)
filter!(row->row.station_id in akflightlines, flightlines)

#This script will find the nearest ERA5 grid points to each flight line
for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    sd_data = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile","r")
    sd = sd_data["sd"][:]
    glacier_mask = isglacier(sd_data["sd"][:])
    lonlatgrid = tuple.(sd_data["longitude"][:], sd_data["latitude"][:]')

    #Now iterate through each flightline
    fline_to_nearest_neighbor = Dictionary{String, Vector{Tuple{Int,Int}}}()
    for flightline in eachrow(flightlines)
        points = flightline.path.points
        flightline_points = tuple.(getproperty.(points, :x), getproperty.(points, :y))
        close_points = Tuple{Int,Int}[]
        #Find the closest ERA5 grid point for each point of the flightline, and ensure that it is not glacier
        for point in flightline_points
            closest_idx = brute_nearest_neighbor_idx(point, lonlatgrid)
            !glacier_mask[closest_idx] && push!(close_points, Tuple(closest_idx))
        end
        close_points = unique(close_points)
        insert!(fline_to_nearest_neighbor, flightline.station_id, close_points)
    end

    display(fline_to_nearest_neighbor)
    #Now save the data of the nearest neighbors. I don't feel like formatting this into a CSV, so it gets JLD2'd
    jldsave("../data/$(eratype)_fline_nearest_neighbors.jld2", fline_nearest_neighbors=fline_to_nearest_neighbor)
end





