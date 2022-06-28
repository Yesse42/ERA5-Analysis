cd(@__DIR__)
datadir(paths...)=joinpath("../data/", paths...)

using CSV, DataFrames

#Allowed HUC's
include(datadir("wanted_stations.jl"))

allowed_ids = vcat(chena_basin_ids, copper_ids, kenai_ids, southeast_ids, remote_ids)

id_regex = [Regex("^$str") for str in allowed_ids]

snotel = CSV.read(datadir("cleansed","SNOTEL_Meta.csv"), DataFrame)
course = CSV.read(datadir("cleansed", "Snow_Course_Meta.csv"), DataFrame)

allowed_snotel = filter(row->any(occursin.(id_regex, string(row.HUC))), snotel)
allowed_snow_course = filter(row->any(occursin.(id_regex, string(row.HUC))), course)

#Remove obnoxious tabs from the snow course IDs
allowed_snow_course.ID .= rstrip.(allowed_snow_course.ID, '\t')

CSV.write(datadir("cleansed", "Relevant_Stations.csv"), vcat(allowed_snotel, allowed_snow_course))