#=As the geopotential grids and the snow depth grids are both just subsets of the same regular lat-lon grids, in this 
script I will create new geopotential grids which are aligned=#
cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dictionaries, NCDatasets, JLD2
import ERA5Analysis as ERA

offestarr = []
for (era_type, era_file) in zip(ERA.eratypes, ERA.erafiles)
    geopotential = NCDataset(
        "../../elevation_data/unaligned_geopotentials/$(era_type)_geopotentials.nc",
        "r",
    )
    sd_data = NCDataset("$(ERA.ERA5DATA)/$(era_type)/$era_file")
    geolon, geolat = geopotential["longitude"][:], geopotential["latitude"][:]
    sdlon, sdlat = sd_data["longitude"][:], sd_data["latitude"][:]

    #For some reason the ERA land geopotentials has lat go from 0 to 360 as opposed to snow depth's -180 to 180
    geolon[geolon .> 180] .-= 360

    #Now determine the offset of the geopotential lat lon from the snow depth lat lon
    #These algorithms use the fact that I know the geopotential arrays contain the snow depth ones
    lonoffset = findfirst(==(sdlon[1]), geolon) - 1
    latoffset = findfirst(==(sdlat[1]), geolat) - 1
    offset = CartesianIndex(lonoffset, latoffset)

    #Now get the indices of the snow_depth array, and then use those to index into the 
    #geopotential array to get the elevation
    sd_indices = CartesianIndices(sd_data["sd"][:, :, 1])
    associated_geopotential_indices = sd_indices .+ offset
    associated_geopotentials = geopotential["z"][:][associated_geopotential_indices]

    era_constant_gravity = 9.80665
    associated_heights = associated_geopotentials ./ era_constant_gravity

    #Also get the associated latitude and longitude
    latinds = (1 + latoffset):(latoffset + length(sdlat))
    loninds = (1 + lonoffset):(lonoffset + length(sdlon))
    outlat = geolat[latinds]
    outlon = geolon[loninds]

    #And now save to a NetCDF
    filename = "../../elevation_data/$(era_type)_aligned_elevations.nc"
    if isfile(filename)
        rm(filename)
    end
    ds = Dataset(filename, "c")
    defDim.(Ref(ds), ("longitude", "latitude"), length.((outlon, outlat)))
    defVar.(
        Ref(ds),
        ("longitude", "latitude"),
        (outlon, outlat),
        tuple.(("longitude", "latitude")),
    )
    defVar(ds, "elevation_m", associated_heights, ("longitude", "latitude"))
    close.([ds, sd_data, geopotential])
end
