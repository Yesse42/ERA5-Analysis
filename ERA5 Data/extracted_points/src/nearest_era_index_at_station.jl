#Get the datasets
cd(@__DIR__)

using CSV, DataFrames, Plots, Proj, Dates, NCDatasets, ColorSchemes

files = ["../../Base/ERA5-SD-1979-2022-CREATE-2022-06-16.nc", "../../Land/ERA5-Land-SD-1979-2022-DL-2022-6-15.nc"]

#And the geopotentials
geofiles = "../data/".*["base","land"].*"_geopotentials.nc"

#And load them in, converting geopotential to elevation by dividing by ERA5's constant gravity
gravity = 9.80665 
datasets = Dataset.(files, "r")
geosets = Dataset.(geofiles, "r")
times = [Hour.(ds["time"][:]) .+ DateTime(1900,1,1) for ds in datasets]
lats = [ds["latitude"][:] for ds in datasets]
lons = [ds["longitude"][:] for ds in datasets]
sds = [ds["sd"][:] for ds in datasets]
geolats = [gds["latitude"][:] for gds in geosets]
geolons = [gds["longitude"][:] for gds in geosets]
for lon in geolons
    lon[lon .> 180] .-= 360
end
elevations = [gds["z"][:] ./ gravity  for gds in geosets]

#Load in the desired stations too
stations = CSV.read("../../../NRCS Cleansing/data/cleansed/Relevant_Stations.csv", DataFrame)

#And now get the indices of the nearest neighbor for each station
dist(tup) = sqrt(sum(x^2 for x in tup))
nearest_neighbor_idxs = Vector{CartesianIndex{2}}[]
for i in 1:nrow(stations)
    s_lat = stations[i, :Latitude]
    s_lon = stations[i, :Longitude]
    #Apply the azimuthal equidistant projection so that the distances are correct, because I'm too lazy to calculate the great circle distance
    thisproj = Proj.Transformation("EPSG:4326", "+proj=aeqd +lat_0=$s_lat +lon_0=$s_lon")
    nn_idxs = [argmin(dist.(thisproj.(lat', lon))) for (lat, lon) in zip(lats, lons)]
    push!(nearest_neighbor_idxs, nn_idxs)
end

#And now go find those same point's indices in the geopotential arrays
geo_neighbor_idxs = Vector{CartesianIndex{2}}[]
for idxs in nearest_neighbor_idxs
    lonidxs, latidxs = first.(Tuple.(idxs)), last.(Tuple.(idxs))
    geolonidxs = findfirst.(isapprox.(getindex.(lons, lonidxs)), geolons)
    geolatidxs = findfirst.(isapprox.(getindex.(lats, latidxs)), geolats)
    push!(geo_neighbor_idxs, CartesianIndex.(geolonidxs, geolatidxs))
end

#Mask out glacier/permasnow areas, by finding where snow is present more than 95% of the time
function isglacier(sd_arr; glacier_thresh=0.95)
    glacier_mask = (sum(sd_arr .> 0; dims=3) ./ size(sd_arr, 3)) .>= glacier_thresh
end

glacierarrs = isglacier.(replace(ds["sd"][:], missing=>NaN) for ds in datasets)

#And now use a weight function to extract the unglaciated point with the minimum weight, if possible

dist(x...) = sqrt(sum(y^2 for y in x))
dist_height_weighter(dist, elev_diff)=dist/5000 + elev_diff/500

offset_index = CartesianIndex(1,1)
for (i, name) in enumerate(["Base", "Land"])
    out_index_df = DataFrame(ID = String[], row = [], col=[])
    out_closest_era_point_id = DataFrame(ID=String[], row=[], col=[], georow=[], geocol=[])
    for (row, nnid, geonnid) in zip(eachrow(stations), nearest_neighbor_idxs, geo_neighbor_idxs)
        #First extract the nearest neighbor to save it away for later use
        true_nn = Tuple(nnid[i])
        true_geo_nn = Tuple(geonnid[i])
        push!(out_closest_era_point_id, (ID=row.ID, row=true_nn[1], col=true_nn[2], georow=true_geo_nn[1], geocol=true_geo_nn[2]))
        #Get the 3x3 elevation array
        elarr = elevations[i][geonnid[i]-offset_index:geonnid[i]+offset_index]
        #Get the 3x3 index array for the snow depth + glacier mask data
        idarr = nnid[i]-offset_index:nnid[i]+offset_index
        #Get the glacier Mask
        glacier_mask = glacierarrs[i][idarr]
        #Mask out the glaciers by setting to NaN
        elarr[glacier_mask] .= NaN
        #Mask out sea level by setting to NaN
        elarr[elarr .== 0] .= NaN
        #Mask out missing data by also setting to NaN
        elarr[sds[i][idarr, 1] .≡ missing] .= NaN

        #Now project the cooredinate
        latlon = tuple.(lats[i]', lons[i])[nnid[i]-offset_index:nnid[i]+offset_index]
        thisproj = Proj.Transformation("EPSG:4326", "+proj=aeqd +lat_0=$(latlon[2,2][1]) +lon_0=$(latlon[2,2][2])")
        projcoords = thisproj.(latlon)
        x,y = first.(projcoords), last.(projcoords)

        weight_arr = dist_height_weighter.(dist.(x,y), abs.(elarr.-row.Elevation_ft*0.3048))
        ordering = sortperm(weight_arr[:])
        #Now examine the 4 "closest" points according to my distance+height weight function; take the first one that isn't glacier
        outidx = nothing
        for idx in ordering[1:4]
            if elarr[idx] ≢ NaN
                outidx = Tuple(idarr[idx])
                push!(out_index_df, (ID=row.ID, row = outidx[1], col=outidx[2]))
                break
            end
        end
        if outidx ≡ nothing
            push!(out_index_df, (ID=row.ID, row = missing, col=missing))
        end
    end
    CSV.write("../data/"*name*"_nearby_point_idx.csv", out_index_df)
    CSV.write("../data/"*name*"_true_nearest_neighbor.csv", out_closest_era_point_id)
end



