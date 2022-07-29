burrowactivate()
import ERA5Analysis as ERA
using NCDatasets, CSV, DataFrames, Dictionaries, StaticArrays, Dates, InlineStrings

if !isdefined(Main, :all_metadatas)

    function isglacier(era_sd; glacier_thresh = 0.95, min_snow = 1e-3)
        era_sd[ismissing.(era_sd)] .= NaN
        return ((sum(era_sd .> min_snow; dims = 3) ./ size(era_sd, 3)) .>= glacier_thresh) .||
            isnan.(era_sd[:, :, 1])
    end

    #Pre-load some stuff
    sds = Dictionary{String, Array{Float32, 3}}()
    glacier_masks = Dictionary{String, Array{Bool, 2}}()
    elevations_datas = Dictionary{String, Array{Float32, 2}}()
    lonlatgrids = Dictionary{String, Array{SVector{2, Float32}, 2}}()
    lons = Dictionary{String, Vector{Float64}}()
    lats = Dictionary{String, Vector{Float64}}()
    times = Dictionary{String, Vector{Date}}()

    for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
        sd_data = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
        sd = sd_data["sd"][:]
        replace!(sd, missing=>NaN32)
        elev_data = Dataset(
            "$(ERA.ERA5DATA)/better_extracted_points/elevation_data/$(eratype)_aligned_elevations.nc",
            "r",
        )
        elevations = elev_data["elevation_m"][:]
        glacier_mask = isglacier(sd_data["sd"][:])
        lonlatgrid = SVector.(sd_data["longitude"][:], sd_data["latitude"][:]')
        time = Date.(sd_data["time"][:])
        lon = range(sd_data["longitude"][begin], sd_data["longitude"][end], length = length(sd_data["longitude"]))
        lat = range(sd_data["latitude"][begin], sd_data["latitude"][end], length = length(sd_data["latitude"]))
        insert!.(
            [glacier_masks, elevations_datas, lonlatgrids, times, sds, lons, lats],
            eratype,
            [glacier_mask[:, :], elevations, lonlatgrid, time, sd, lon, lat],
        )
        close(sd_data)
        close(elev_data)
    end

    metadatas = all_metadatas = Dictionary(ERA.networktypes, 
    CSV.read.(joinpath.(ERA.NRCSDATA, "cleansed", ERA.networktypes.*"_Metadata.csv"), DataFrame))
    transform!.(metadatas, :ID=>ByRow(x->String7(string(x)))=>:ID)
end