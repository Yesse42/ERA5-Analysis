#Extract only the locations we are interested in

using DrWatson; @quickactivate "NRCS Cleansing"

using CSV, DataFrames

chena_basin_ids = ["19080306"]
copper_ids = ["1902"] .* "0" .* string.((1,2,3))
kenai_ids = ["190203"]
southeast_ids = ["190705"]
remote_ids = ["19050301"]

allowed_ids = vcat(chena_basin_ids, copper_ids, kenai_ids, southeast_ids, remote_ids)

id_regex = [Regex("^$str") for str in allowed_ids]

snotel = CSV.read(datadir("cleansed","SNOTEL_Meta.csv"), DataFrame)
course = CSV.read(datadir("cleansed", "Snow_Course_Meta.csv"), DataFrame)

allowed_snotel = filter(row->any(occursin.(id_regex, string(row.HUC))), snotel)
allowed_snow_course = filter(row->any(occursin.(id_regex, string(row.HUC))), course)

allowed_snow_course.ID .= rstrip.(allowed_snow_course.ID, '\t')

CSV.write(datadir("cleansed", "Relevant_Stations.csv"), vcat(allowed_snotel, allowed_snow_course))