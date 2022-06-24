cd(@__DIR__)
cd("..")
using CSV, DataFrames, Dates, StatsBase

huc = "19080306"
station_metadata = filter!(row->row.Network ≠ "SNOTEL", CSV.read("../NRCS Cleansing/data/cleansed/Relevant_Stations.csv", DataFrame))
station_data = CSV.read("../NRCS Cleansing/data/cleansed/Snow_Course_Data.csv", DataFrame)
#Select only SWE data
select!(station_data, :Date=>ByRow(x->parse(DateTime, x, dateformat"u yyyy"))=>:datetime, r"SWE")

#Now analyze every station in the Chena Basin
point_data_dir = "../ERA5 Data/extracted_points/Land/"

eratime = CSV.read("$point_data_dir/times.csv", DataFrame)

#Round to the nearest day for the ERA5 data
eratime.datetime .-= Hour(12)

basin_dfs = []
for row in eachrow(station_metadata)
    if !occursin(Regex("^$huc"), string(row.HUC)) continue end
    #Load in the era5 data
    era5_data = hcat(CSV.read("$point_data_dir/$(row.ID).csv", DataFrame), eratime)
    #Convert to mm
    era5_data.sd .*= 1e3
    rename!(era5_data, [:era_swe, :datetime])

    #Now get the station data
    this_stations_data = select(station_data, Regex("_$(row.ID)"), :datetime)

    if names(this_stations_data) == ["datetime"] continue end

    rename!(this_stations_data, [:station_swe, :datetime])

    #Do an innerjoin on available data
    combined = innerjoin(era5_data, this_stations_data; on=:datetime)
    dropmissing!(combined)
    filter!(row->month(row.datetime)==4, combined)
    push!(basin_dfs, combined)
end

mean_diffs = [mean(df.era_swe .- df.station_swe) for df in basin_dfs]

rmse = [sqrt(sum((df.era_swe .- df.station_swe).^2)/(nrow(df))) for df in basin_dfs]

#Mean anomaly relative to median
mean_anom_diffs =[mean(df.era_swe .- df.station_swe) - median(df.era_swe) + median(df.station_swe) for df in basin_dfs]

rmse_anom = [sqrt(sum((df.era_swe .- df.station_swe .- median(df.era_swe) .+ median(df.station_swe)).^2)/(nrow(df))) for df in basin_dfs]

#Mean difference in percent of median
mean_pom_diffs =  [mean(df.era_swe./median(df.era_swe) .- df.station_swe./median(df.station_swe)) for df in basin_dfs]

println("There are 8 Snow Course stations with data in the Chena River Subbasin. All stats below are for (nominally) April 1st")
println("POR Length")
display([nrow(df) for df in basin_dfs])
println("The mean difference (over all April 1sts) between ERA5 Land and Snow Course raw values in mm")
display(mean_diffs)
println("Sqrt of quotient of sum of squared differences between raw values and (#obs-1), in mm")
display(rmse)
println("Mean difference over all Aprils for anomalies in mm")
display(mean_anom_diffs)
println("Sqrt of quotient of sum of squared differences between anomalies and (#obs-1), in mm")
display(rmse_anom)
println("The mean difference in fraction of median over all years (unitless)")
display(mean_pom_diffs)