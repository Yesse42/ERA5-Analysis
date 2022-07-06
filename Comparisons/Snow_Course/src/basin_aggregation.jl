using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays, JLD2
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA

analysis_data = jldopen("../data/snow_course_monthly_data.jld2")["snow_course_monthly_data"]
basin_to_stations =
    jldopen("$(ERA.NRCSDATA)/cleansed/Snow_Course_basin_to_id.jld2")["basin_to_id"]

include("../../basin_agg_funcs.jl")

data = basin_agg(analysis_data, basin_to_stations, ERA.basin_names)
