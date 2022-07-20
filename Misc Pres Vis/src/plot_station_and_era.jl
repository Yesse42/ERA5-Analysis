cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Dates

load_script_dir = joinpath(ERA.COMPAREDIR, "Load Scripts")
include.(joinpath.(load_script_dir, "load_" .* ["era", "snotel", "snow_course"] .* ".jl"))

plot_station_and_era = let

    eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")

    metadata = CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "Metadata.csv"), DataFrame)

    function plot_station_and_era(id, eratype, timeperiod, savedir = "../vis")
        eradata = load_era(eradatadir, eratype, id)

        meta_idx = findfirst(==(id), string.(metadata.ID))
        stationtype = metadata[meta_idx, :Network]
        stationdata = nothing
        colname = nothing
        if stationtype == "SNOTEL"
            stationdata = load_snotel(id)
            colname = :snotel_swe
        elseif stationtype == "Snow_Course"
            stationdata = load_snow_course(id)
            colname = :snow_course_swe
        else
            throw(ArgumentError("Station bad"))
        end

        combined = innerjoin(eradata, stationdata; on=:datetime)

        filter!(x->timeperiod[1] <= x.datetime <= timeperiod[2], combined)

        p = plot(combined.datetime, Array(combined[:, [:era_swe, colname]]); title = "ID $id $stationtype vs ERA5 $eratype",
        ylabel = "Monthly Mean SWE (mm)", xlabel = "Time", label = ["ERA5-$eratype" stationtype])

        savefig(p, joinpath(savedir, "$(id)_$(eratype).png"))

    end
end