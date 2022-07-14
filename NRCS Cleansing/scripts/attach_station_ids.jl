cd(@__DIR__)
burrowactivate()
datadir(paths...) = joinpath("../data/", paths...)
using CSV, DataFrames, Dates
import ERA5Analysis as ERA

snotelpath = datadir("raw", "AK_SNOTEL_14-06-2022.csv")
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
snotel = CSV.read(snotelpath, DataFrame; header = 130)
snow_course = CSV.read(snowcoursepath, DataFrame; header = 251)

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
snow_course.Date = begin
    #Parse the horrendous format
    month_to_num = Dates.LOCALES["english"].month_abbr_value
    "Jun 2nd Half 1981"
    function horrid_date_to_nice_date(str)
        monthnum = month_to_num[str[1:3]]
        year = parse(Int, str[14:17])
        half_ind = parse(Int, str[5])
        dayofmonth = 1 + (daysinmonth(year, monthnum)) ÷ 2 * (half_ind - 1)
        return Date(year, monthnum, dayofmonth)
    end
    horrid_date_to_nice_date.(snow_course.Date)
end
display(snow_course)
for df in [snotel, snow_course]
    select!(df, :Date => :datetime, r"SWE")
    #Remove any columns that are entirely missing
    notallmissing_col = [!all(ismissing.(col)) for col in eachcol(df)]
    select!(df, names(df)[notallmissing_col])
end

#Now save the new stuff
CSV.write(joinpath(outdir, "Metadata.csv"), metadata)
CSV.write(joinpath(outdir, "SNOTEL_Data.csv"), snotel)
CSV.write(joinpath(outdir, "Snow_Course_Data.csv"), snow_course)
