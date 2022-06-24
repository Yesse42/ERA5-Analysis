using CSV, DataFrames, Dates, Dictionaries, DimensionalData, StatsBase
cd(@__DIR__)
nrcsdatadir = "../../../NRCS Cleansing/data/cleansed/"
eradatadir = "../../../ERA5 Data/extracted_points/"

stations = CSV.read(joinpath(nrcsdatadir, "Relevant_Stations.csv"), DataFrame)
filter!(row->occursin("Snow Course", row.Network), stations)

station_data = CSV.read(joinpath(nrcsdatadir, "Snow_Course_Data.csv"), DataFrame)
select!(station_data, Not(:Date), :Date=>ByRow(x->parse(DateTime, x, dateformat"u YYYY"))=>:datetime)
station_names = names(station_data)
eratypes = ["Land","Base"]
data_by_station = Dictionary()
for id in stations.ID

    #Skip if there is no extracted point there due to glaciation for either ERA5 type
    if !isfile(joinpath(eradatadir,"Land","$id.csv")) continue end
    if !isfile(joinpath(eradatadir,"Base","$id.csv")) continue end

    #Now filter for the name of the column we want; it should have SWE and this ID in it
    colname = [name for name in station_names if name == "SWE_$id"]

    #There are more stations in metadata than what I've donwloaded, skip if we've found one of those
    if isempty(colname) 
        continue 
    else 
        colname = only(colname) 
    end
    this_station_data = select(station_data, :datetime, colname=>:Station)

    eras=DataFrame[]
    for eratype in ["Land","Base"]
        times = CSV.read(joinpath(eradatadir,eratype,"times.csv"), DataFrame)
        data = CSV.read(joinpath(eradatadir,eratype,"$id.csv"), DataFrame)
        #Set to midnight for later joining
        times.datetime .-= Hour(12)
        #Convert to mm
        data.sd .*= 1e3
        eradata = rename!(hcat(times, data), [:datetime, Symbol(eratype)])
        push!(eras, eradata)
    end

    outdf = dropmissing(innerjoin(this_station_data, eras...; on=:datetime))
    if isempty(outdf) continue end
    insert!(data_by_station, id, outdf)
end

#Load in the NRCS medians for each station too
raw_NRCS_median = CSV.read(joinpath(nrcsdatadir, "Snow_Course_Medians_1991-2020.csv"), DataFrame)
median_names = filter(x->x≠"month", names(raw_NRCS_median))
mediandict = Dictionary(median_names, [raw_NRCS_median[:, ["month",name]] for name in median_names])

#Now that we've loaded everything in we can start analyzing

#Things we'll be analyzing
analysisarray = Array{Any}(undef, length.((data_by_station, eratypes)))
import DimensionalData: @dim
@dim EraType; @dim Station
labeled_data_array = DimArray(analysisarray, (Station(collect(keys(data_by_station))), EraType(eratypes)))

rmsd(diffarr) = sqrt(sum(x^2 for x in diffarr)/length(diffarr))


data_source_pairings = [ [groupingcols[j], groupingcols[i]] for i in eachindex(groupingcols) for j in 1:i if i≠j]

for (i,(station, data)) in enumerate(zip(keys(data_by_station), data_by_station))
    for (j,eratype) in enumerate(eratypes)
        groupingcols = ["Station",eratype]
        withmonth = transform(data, :datetime=>ByRow(month)=>:month)
        #1991-2020 normals
        filter!(row-> 1991<=year(row.datetime)<=2020, withmonth)
        #Skip this station if it's empty
        if isempty(withmonth) analysisarray[i,j]=missing; continue end
        groupmonth = groupby(withmonth, :month)

        #Now get mean and median values
        monthstats = combine(groupmonth, groupingcols.=>mean.=>groupingcols.*"_Mean", groupingcols.=>median.=>groupingcols.*"_Median")
        #Make a convenience function to get means and medians by month
        function getmonthstat(time, datasource, stat="Median")
            idx = findfirst(==(month(time)), monthstats.month)
            if isnothing(idx) return missing end
            return monthstats[idx, "$(datasource)_$stat"]
        end
        #Now calculate the differences, differences in anomalies, and differences in percent of normal
        groupcolswithtime = vcat(groupingcols, ["datetime"])
        diffdata = transform(data, groupingcols=>ByRow(-)=>:era_station_diff, 
                        groupcolswithtime=>ByRow((x,y,t)->x-y + getmonthstat(t, eratype) - getmonthstat(t, "Station"))=>:anomaly_diff,
                        groupcolswithtime=>ByRow((x,y,t)->100*(x/getmonthstat(t, eratype) - y/getmonthstat(t, "Station")))=>:pon_diff)
        dropmissing!(diffdata)
        #Now calculate the mean differences and RMSD by month, for all available times, not just 1991-2020
        diffdata_withmonth = transform(diffdata, :datetime=>ByRow(month)=>:month)
        group_diff = groupby(diffdata_withmonth, :month)
        groupcols = String.([:era_station_diff, :anomaly_diff, :pon_diff])
        month_diff_stats = combine(group_diff, groupcols.=>mean.=>groupcols.*"_Mean", groupcols.=>rmsd.=>groupcols.*"_RMSD")
        analysisarray[i,j] = outerjoin(monthstats, month_diff_stats; on=:month)
    end
end

labeled_data_array


