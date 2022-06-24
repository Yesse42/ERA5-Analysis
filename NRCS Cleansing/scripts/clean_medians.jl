using DrWatson; @quickactivate "NRCS Cleansing"

using CSV, DataFrames, Dates

#Load in the file, which begins at line 250
medians = CSV.read(datadir("raw","NRCS-1991-2020-Medians.csv"), DataFrame; header = 250)

stations = CSV.read(datadir("cleansed","Relevant_Stations.csv"), DataFrame)
filter!(row->row.Network ≠ "SNOTEL", stations)

#Now filter for only medians, and only the stations we want
names_to_use = [name for name in names(medians) if any(occursin.(stations.ID, name))]
mymedians = medians[:, vcat(names_to_use, ["Date"])]
#The normals are only available on the 1st of the month
filter!(row->occursin("1st",row.Date), mymedians)

month_abbrs = Dates.LOCALES["english"].months_abbr
monthdict = Dict(month_abbrs .=> 1:12)

select!(mymedians, :Date=>ByRow(str-> monthdict[str[1:3]])=>:month, names_to_use)

rename!(mymedians, vcat(["month"], [match(r"(?:\()([0-9A-Z]+)(?:\))", name).captures[1] for name in names(mymedians)[2:end]]))

CSV.write(datadir("cleansed","Snow_Course_Medians_1991-2020.csv"), mymedians)


