burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dictionaries, Dates

include("../basin_agg_funcs.jl")

fragment = jldopen("fragment_of_broken_data.jld2")["broken_data"]

alldata = fragment[("Eastern Interior", "Base")]
data = alldata.basindata

sort!(data, :datetime)
data = data
plot(data.datetime, data.era_swe_fom_mean)

stationdata = alldata.stationdata

print("\n\n\n\n here \n\n\n\n")
reagged = basin_aggregate(collect(stationdata); n_obs_weighting = true)
display(reagged[:, r"(era_swe|time)"])
display(plot!(reagged.datetime, reagged.era_swe_fom_mean))
