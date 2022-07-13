cd(@__DIR__)
burrowactivate()
datadir(paths...) = joinpath("../data/", paths...)
using CSV, DataFrames, Dates, Missings
import ERA5Analysis as ERA

snotelpath = datadir("raw", "AK_SNOTEL.csv")
snowcoursepath = datadir("raw", "AK_SNOW_COURSE.csv")
metapath = datadir("raw", "Map metadata export.csv")

outdir = datadir("cleansed")

#Read out the data
metadata = CSV.read(metapath, DataFrame)
#Remove the tab from the id column
metadata.ID .= strip.(metadata.ID, '\t')
metadata.Network[occursin.("Snow Course", metadata.Network)] .= "Snow_Course"
select!(
    metadata,
    :Elevation_ft => ByRow(x -> x * 0.3048) => :Elevation_m,
    Not(:Elevation_ft),
)
snotel = CSV.read(snotelpath, DataFrame; header = 107)
snow_course = CSV.read(snowcoursepath, DataFrame; header = 251)

#Now extract the names of the locations and use the metadata to get the Hydrologic Unit Code
#Names are lines 25-97
snotel_names = readlines(open(snotelpath))[25:75]
#Lines 25-218
course_names = readlines(open(snowcoursepath))[25:218]
#Now transform these into more amenable forms
snotel_regex = r"(?:SNOTEL )([0-9]*)"
snotel_ids = unique([match(snotel_regex, name).captures[1] for name in snotel_names])

course_regex = r"(?:AERIAL MARKER )([0-9A-Z]*)"
course_ids = unique([match(course_regex, name).captures[1] for name in course_names])

#Now finally rename the columns of the raw data with these ids
rename!(snotel, ["Date"; "SWE_".*snotel_ids])
rename!(snow_course, ["Date"; (["SWE_", "datetime_"].*permutedims(course_ids))[:]])
snow_course.Date = parse.(DateTime, snow_course.Date, dateformat"u YYYY")
years = year.(snow_course.Date)
for id in course_ids
    incomplete_date = (passmissing(parse)).(DateTime, (passmissing(*)).(string.(years), " ",snow_course[!, "datetime_$id"]), dateformat"Y u dd")
    snow_course[!, "datetime_$id"] = (passmissing(DateTime)).(years, (passmissing(month)).(incomplete_date), passmissing(day).(incomplete_date))
end
for df in [snotel, snow_course]
    select!(df, :Date=>:datetime, Not(:Date))
    #Remove any columns that are entirely missing
    notallmissing_col = [!all(ismissing.(col)) for col in eachcol(df)]
    select!(df, names(df)[notallmissing_col])
end

display(snotel)
display(snow_course)

#Now save the new stuff
CSV.write(joinpath(outdir, "Metadata.csv"), metadata)
CSV.write(joinpath(outdir, "SNOTEL_Data.csv"), snotel)
CSV.write(joinpath(outdir, "Snow_Course_Data.csv"), snow_course)
