#A simple script to compare a single flight line with ERA5
cd(@__DIR__)
burrowactivate()
using JLD2, CSV, DataFrames, NCDatasets, Dictionaries, Dates, Plots, StatsBase
gr()
import ERA5Analysis as ERA

fline_data = CSV.read("$(ERA.NOHRSCDATA)/ak_gamma.csv", DataFrame)
fline_data.date = parse.(DateTime, fline_data.date, dateformat"yyyy-mm-dd HH:MM:SS")
sort!(fline_data, :date)

flines = unique(fline_data.station_id)

const meter_to_inch = 39.3701

fline_data.swe_meter.*= meter_to_inch

for (eratype, erafile) in zip(ERA.eratypes, ERA.erafiles)
    #Load the data
    eradata = Dataset("$(ERA.ERA5DATA)/$eratype/$erafile", "r")
    sd = eradata["sd"][:]
    eratime = eradata["time"][:]
    flightline_points = jldopen("$(ERA.ERA5DATA)/extracted_flightlines/data/$(eratype)_fline_nearest_neighbors.jld2")["fline_nearest_neighbors"]

    for fline in flines
        #Abort if there is no shapefile
        fline_measurements = fline_data[fline_data.station_id .== fline,:]
        #Now retrieve the era5 points corresponding to each flightline, and if that flight line has been discarded then move on
        if !(fline in keys(flightline_points)) continue end
        era_points = CartesianIndex.(flightline_points[fline])
        
        #Now get the era5 time indices corresponding to each flight's time
        begintime = first(eratime)
        timestep = Millisecond(Day(1))
        timearr = similar(fline_measurements.date)
        time_index(time) = (time-begintime)÷timestep + 1
        time_indices = time_index.(fline_measurements.date)

        #Discard any out of bounds measurements
        valid_time_idxs = 1 .<= time_indices .<= size(sd, 3)
        time_indices = time_indices[valid_time_idxs]
        era_measurements = sd[era_points, time_indices]
        era_measurements .*= meter_to_inch

        mean_era_swe = mapslices(mean, era_measurements; dims=(1,))'
        gamma_swe = fline_measurements.swe_meter[valid_time_idxs]

        if isempty(gamma_swe) continue end
        naormissornoth(kfgjh) = ismissing(kfgjh) || isnan(kfgjh)  || isnothing(kfgjh)
        if any(naormissornoth.(gamma_swe)) || any(naormissornoth.(mean_era_swe)) 
            println("$fline nana")
            continue
        end
        lims = (minimum(minimum.((gamma_swe, mean_era_swe))) -1, maximum(maximum.((gamma_swe, mean_era_swe))) +1)

        myplot = scatter(gamma_swe, mean_era_swe; title="NOHRSC vs. ERA5 $eratype SWE Scatter, Flight Line: $fline",
                    xlabel = "NOHRSC SWE (in.)", ylabel = "ERA5 SWE (in.)", label="", aspect=:equal,
                    xlims = lims, ylims = lims, titlefontsize = 12)
        annotations = tuple.(gamma_swe, mean_era_swe, year.(fline_measurements.date[valid_time_idxs]))
        plot!(myplot; annotate = annotations)
        slope1line = lims[1]:0.01:lims[2]
        plot!(myplot, slope1line, slope1line; label ="")
        save("../vis/$fline.png", myplot)
    end
end