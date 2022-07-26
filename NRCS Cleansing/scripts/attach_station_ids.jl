cd(@__DIR__)
burrowactivate()
datadir(paths...) = joinpath("../data/", paths...)
using CSV, DataFrames, Dates
import ERA5Analysis as ERA

snotelpath = datadir("raw", "AK_SNOTEL.csv")
snowcoursepath = datadir("raw", "AK_SNOW_COURSE.txt")
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
snotel = CSV.read(snotelpath, DataFrame; header = 109, delim = ',')
snow_course = CSV.read(snowcoursepath, DataFrame; header = 391, delim = ',')

#Now extract the names of the locations and use the metadata to get the Hydrologic Unit Code
#Names are lines 25-97
function extract_colname(colname)
    colname == "Date" && return colname
    id = match(r"(?:\()([0-9]+[A-Z]*[0-9]+)", colname)
    id = only(id.captures)
    dtype = 
    if occursin("Snow Water Equivalent Collection Date Start of Month Values", colname)
        "datetime"
    elseif occursin("Snow Water Equivalent (mm)", colname)
        "SWE"
    end
    return "$(dtype)_$(id)"
end
course_ids = extract_colname.(names(snow_course))
rename!(snow_course, course_ids)
snotel_ids = extract_colname.(names(snotel))
rename!(snotel, snotel_ids)
course_ids = course_ids[2:end]
snotel_ids = snotel_ids[2:end]

"They give a Date column of 'Apr 1958' and a collection date formatted like 'Apr 28'"
function nasty_date_parser(monthday, monthyear)
    (ismissing(monthday) || monthday == "\t")&& return missing
    str_to_month = Dates.LOCALES["english"].month_abbr_value
    numregex = r"[0-9]+"
    year = parse(Int, match(numregex, monthyear).match)
    collection_month = str_to_month[monthday[1:3]]
    day = parse(Int, match(numregex, monthday).match)
    report_month = str_to_month[monthyear[1:3]]
    #Snow course results for January could possibly have been taken at the end of december
    if report_month == 1 && collection_month == 12
        year -= 1
    end
    return Date(year, collection_month, day)
end

#Now handle the atrocious date formatting
timenames = filter!(str->occursin("datetime", str), course_ids)
date_parse_cols = [[name, "Date"] for name in timenames]
select!(snow_course, Not(timenames), 
    date_parse_cols.=>ByRow(nasty_date_parser).=>timenames)

for df in [snotel, snow_course]
    select!(df, :Date => :datetime, Not(:Date))
    #Remove any columns that are entirely missing
    notallmissing_col = [!all(ismissing.(col)) for col in eachcol(df)]
    select!(df, names(df)[notallmissing_col])
end

filter!(row->any(occursin.(row.ID, [names(snow_course); names(snotel)])), metadata)

#Now save the new stuff
CSV.write(joinpath(outdir, "Metadata.csv"), metadata)
CSV.write(joinpath(outdir, "SNOTEL_Data.csv"), snotel)
CSV.write(joinpath(outdir, "Snow_Course_Data.csv"), snow_course)
