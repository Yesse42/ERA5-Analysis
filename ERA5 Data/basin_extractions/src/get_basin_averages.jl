cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, NCDatasets, Dates, StatsBase
import ERA5Analysis as ERA

eratypes = ERA.eratypes
eradirs = ERA.erafiles
era5dirs = joinpath.(ERA.ERA5DATA, eratypes, era5dirs)

for (eratype, eradir) in zip(eratypes, era5dirs)
    #Load in the snow depth data and the associated times
    ds = Dataset(eradir, "r")
    sd = ds["sd"][:]
    times = ds["time"][:]
    for basin in ERA.basin_names
        #Now extract the data for each basin and calculate the daily basin mean
        basin_coord_df = CSV.read("../$eratype/$(basin)_era_points.csv", DataFrame)
        idxs = CartesianIndex.(basin_coord_df.lonidx, basin_coord_df.latidx)
        averages = [mean(skipmissing(sd[idxs, i])) for i in axes(sd, 3)]
        CSV.write(
            "../$eratype/$(basin)_sd_avgs.csv",
            DataFrame(; datetime = times, sd_avg = averages),
        )
    end
    close(ds)
end
