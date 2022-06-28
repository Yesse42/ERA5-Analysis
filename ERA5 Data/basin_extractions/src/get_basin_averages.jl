cd(@__DIR__)
using CSV, DataFrames, NCDatasets, Dates, StatsBase
include("../../../NRCS Cleansing/data/wanted_stations.jl")

eratypes = ["Base","Land"]
eradirs = ["ERA5-SD-1979-2022-CREATE-2022-06-16.nc", "ERA5-Land-SD-1979-2022-DL-2022-6-15.nc"]
era5dirs = "../../".*eratypes.*"/".*eradirs

for (eratype, eradir) in zip(eratypes, era5dirs)
    #Load in the snow depth data and the associated times
    ds = Dataset(eradir, "r")
    sd = ds["sd"][:]
    times = ds["time"][:]
    for basin in basin_names
        #Now extract the data for each basin and calculate the daily basin mean
        basin_coord_df = CSV.read("../$eratype/$(basin)_era_points.csv", DataFrame)
        idxs = CartesianIndex.(basin_coord_df.lonidx, basin_coord_df.latidx)
        averages = [mean(skipmissing(sd[idxs, i])) for i in axes(sd, 3)]
        CSV.write("../$eratype/$(basin)_sd_avgs.csv", DataFrame(datetime=times, sd_avg=averages))
    end
    close(ds)
end