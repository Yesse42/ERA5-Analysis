using DrWatson
@quickactivate "NRCS Cleansing"
using CSV, DataFrames

snotelpath = datadir("raw", "AK_SNOTEL_14-06-2022.csv")
snowcoursepath = datadir("raw","AK_SNOW_COURSE_14-06-2022.csv")
metapath = datadir("raw","Map metadata export.csv")

outdir = datadir("cleansed")

#Read out the data
metadata = CSV.read(metapath, DataFrame)
#Remove the tab from the id column
transform!(metadata, :ID=>ByRow(id->strip(id, '\t')=>:ID))
snow_course_meta = filter(x->occursin("Snow Course", x.Network), metadata)
snotel_meta = filter(x->occursin("SNOTEL", x.Network), metadata)
snotel = CSV.read(snotelpath, DataFrame; header=130)
snow_course = CSV.read(snowcoursepath, DataFrame; header=251)

#Now extract the names of the locations and use the metadata to get the Hydrologic Unit Code
#Names are lines 25-97
snotel_names = readlines(open(snotelpath))[25:97]
#Lines 25-218
course_names = readlines(open(snowcoursepath))[25:218]
#Now transform these into more amenable forms
snotel_regex = r"(?:SNOTEL )([0-9]*)"
snotel_ids = [match(snotel_regex, name).captures[1] for name in snotel_names]

course_regex = r"(?:AERIAL MARKER )([0-9A-Z]*)"
course_ids = [match(course_regex, name).captures[1] for name in course_names]

#Now finally rename the columns of the raw data with these ids
rename!(snotel, vcat("Date", (["SWE", "Depth"] .* "_" .* permutedims(snotel_ids))[:]))
rename!(snow_course, vcat("Date", (["SWE", "Depth"] .* "_" .* permutedims(course_ids))[:]))

#Now save the new stuff
CSV.write(joinpath(outdir, "SNOTEL_Meta.csv"), snotel_meta)
CSV.write(joinpath(outdir, "Snow_Course_Meta.csv"), snow_course_meta)
CSV.write(joinpath(outdir, "SNOTEL_Data.csv"), snotel)
CSV.write(joinpath(outdir, "Snow_Course_Data.csv"), snow_course)
