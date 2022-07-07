cd(@__DIR__)
include("../../../NRCS Cleansing/data/wanted_stations.jl")
using CSV, Dates, DataFrames, DimensionalData, StatsBase
import DimensionalData: @dim
basin_names = basin_names
eratypes = ["Base", "Land"]

@dim EraType; @dim Basin
analysis_holder = DimArray(fill(DataFrame(), 5, 2), (Basin(basin_names), EraType(eratypes)))

for eratype in eratypes
    for basin in basin_names
        eradata, stationdata = CSV.read.(("../../../ERA5 Data/basin_extractions/$eratype/$(basin)_sd_avgs.csv"
        ,"../../../NRCS Cleansing/data/basin_averages/$basin-SNOTEL-avgs.csv")
        , DataFrame)
        stationdata.datetime = DateTime.(stationdata.datetime).+Hour(12)
        rename!(stationdata,[:datetime, :station_sd])
        rename!(eradata,[:datetime, :era_sd])
        eradata.era_sd.*=1e3
        basindata = innerjoin(stationdata, eradata; on=:datetime)
        dropmissing!(basindata)
        analysis_holder[Basin(At(basin)), EraType(At(eratype))] = basindata
    end
end

analysis_holder

using Plots
gr()
data = analysis_holder[EraType(At("Base")), Basin(At("Chena"))]
filter!(row-> Date(2019,9) <= row.datetime <= Date(2022,8,31), data)
plot(data.datetime, Array(data[:, [:station_sd, :era_sd]])./mean(Array(data[:, [:station_sd, :era_sd]]); dims=1); labels=["station" "era Land"], legend=:topleft)