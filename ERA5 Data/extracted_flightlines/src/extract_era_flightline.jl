cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, Dictionaries, JLD2, Shapefile
import ERA5Analysis as ERA

fline_data = CSV.read("$(ERA.NOHRSCDATA)/ak_gamma.csv", DataFrame)
fline_data.date = parse.(DateTime, fline_data.date, dateformat"yyyy-mm-dd HH:MM:SS")
sort!(fline_data, :date)

flines = unique(fline_data.station_id)

const meter_to_inch = 39.3701

fline_data.swe_meter .*= meter_to_inch

for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    #Load the data
    eradata = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
    sd = eradata["sd"][:]
    eratime = eradata["time"][:]
    flightline_points = jldopen(
        "$(ERA.ERA5DATA)/extracted_flightlines/data/$(eratype)_fline_nearest_neighbors.jld2",
    )["fline_nearest_neighbors"]

    out_data_dict = Dictionary{String, DataFrame}()
    for fline in flines
        #Abort if there is no shapefile
        fline_measurements = fline_data[fline_data.station_id .== fline, :]
        #Now retrieve the era5 points corresponding to each flightline, and if that flight line has been discarded then move on
        if !(fline in keys(flightline_points))
            continue
        end
        era_points = CartesianIndex.(flightline_points[fline])

        #Now get the era5 time indices corresponding to each flight's time
        time_indices = searchsorted.(Ref(eratime), fline_measurements.date)

        #Discard any out of bounds measurements
        valid_time_idxs = (!isempty).(time_indices)
        time_indices = only.(time_indices[valid_time_idxs])
        era_measurements = sd[era_points, time_indices]
        era_measurements .*= meter_to_inch

        mean_era_swe = vec(mapslices(mean, era_measurements; dims = (1,)))
        gamma_swe = fline_measurements.swe_meter[valid_time_idxs]
        times = fline_measurements.date[valid_time_idxs]

        insert!(
            out_data_dict,
            fline,
            DataFrame(; date = times, gamma = gamma_swe, mean_era_swe = mean_era_swe),
        )
    end
    jldsave(
        "../data/$(eratype)_flightline_era_data.jld2";
        flightline_era_data = out_data_dict,
    )
end
