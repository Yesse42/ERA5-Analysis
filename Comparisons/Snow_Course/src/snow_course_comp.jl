using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA
nrcsdatadir = "$(ERA.NRCSDATA)/cleansed/"
eradatadir = "$(ERA.ERA5DATA)/extracted_points/"

include("../../comparison_funcs.jl")

compare_with_ERA(;
    station_path = joinpath(nrcsdatadir, "Snow_Course_Data.csv"),
    station_meta_path = joinpath(nrcsdatadir, "Snow_Course_Metadata.csv"),
    dailyname = :snow_course_daily_data,
    monthlyname = :snow_course_monthly_data,
    eradatadir = eradatadir,
)
