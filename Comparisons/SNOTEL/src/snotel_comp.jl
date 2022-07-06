using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, AxisArrays
cd(@__DIR__)
burrowactivate()
import ERA5Analysis as ERA
nrcsdatadir = "$(ERA.NRCSDATA)/cleansed/"
eradatadir = "$(ERA.ERA5DATA)/extracted_points/"

include("../../comparison_funcs.jl")

compare_with_ERA(;
    station_path = joinpath(nrcsdatadir, "SNOTEL_Data.csv"),
    station_meta_path = joinpath(nrcsdatadir, "SNOTEL_Metadata.csv"),
    dailyname = :snotel_daily_data,
    monthlyname = :snotel_monthly_data,
    eradatadir = eradatadir,
)
