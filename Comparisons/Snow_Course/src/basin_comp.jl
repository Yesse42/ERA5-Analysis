cd(@__DIR__)
include("../../../NRCS Cleansing/data/wanted_stations.jl")
using CSV, Dates, DataFrames, DimensionalData, StatsBase, JLD2
import DimensionalData: @dim
basin_names = basin_names
eratypes = ["Base", "Land"]
analysistypes = ["Monthly", "Averages"]

@dim EraType; @dim Basin; @dim AnalysisType
analysis_holder = DimArray(fill(DataFrame(), 5, 2, 2), (Basin(basin_names), EraType(eratypes), AnalysisType(analysistypes)))

for eratype in eratypes
    for basin in basin_names
        eradata, stationdata = CSV.read.(("../../../ERA5 Data/basin_extractions/$eratype/$(basin)_sd_avgs.csv"
        ,"../../../NRCS Cleansing/data/basin_averages/$basin-Snow Course-avgs.csv")
        , DataFrame)
        #Align with ERA5
        stationdata.datetime = DateTime.(stationdata.datetime).+Hour(12)
        rename!(stationdata,[:datetime, :station_sd])
        rename!(eradata,[:datetime, :era_sd])
        eradata.era_sd.*=1e3
        basindata = innerjoin(stationdata, eradata; on=:datetime)
        dropmissing!(basindata)
        #Restrict to the modern era
        filter!(row->1991<=year(row.datetime), basindata)

        #Now calculate the Averages
        #First get the monthly median
        mediantime = filter(row->1991<=year(row.datetime)<=2020, basindata)
        select!(mediantime, :datetime=>ByRow(month)=>:month, Not(:datetime))
        monthgroup = groupby(mediantime, :month)
        monthmedians = combine(monthgroup, valuecols(monthgroup).=>(x->median(skipmissing(x))).=>valuecols(monthgroup))
        function getmedian(time, obstype)
            idx = findfirst(==(month(time)), monthmedians.month)
            isnothing(idx) && return missing
            monthmedians[idx, obstype]
        end
        data_time_cols = [:station_sd, :era_sd, :datetime]
        diff_data = select(basindata, :datetime,
        data_time_cols=>ByRow((x,y,t)->x - y - getmedian(t, :station_sd) + getmedian(t, :era_sd))=>:anom_diff,
        data_time_cols=>ByRow((x,y,t)->x - y)=>:diff,
        data_time_cols=>ByRow((x,y,t)->x/getmedian(t, :station_sd) - y/(getmedian(t, :era_sd)))=>:pom_diff)

        analysis_holder[Basin(At(basin)), EraType(At(eratype)), AnalysisType(At("Monthly"))] = outerjoin(basindata, diff_data; on=:datetime)

        diff_data = dropmissing(diff_data)


        #Now get the means and RMSD by month
        rmsd(diffs) = sqrt(sum(diff^2 for diff in diffs)/length(collect(diffs)))
        diffcols = String.([:diff, :anom_diff, :pom_diff])
        monthdiffgroup = groupby(select!(diff_data, :datetime=>ByRow(month)=>:month, Not(:datetime)), :month)
        groupfuncnames = permutedims(["Mean", "RMSD"])
        groupfuncs = permutedims([mean, rmsd])
        monthdiffstats = combine(monthdiffgroup, (diffcols.=>groupfuncs.=>groupfuncnames .* "_" .* diffcols)...)
        analysis_holder[Basin(At(basin)), EraType(At(eratype)), AnalysisType(At("Averages"))] = monthdiffstats
    end
end

jldsave("../data/basin_mean_snow_course.jld2", basin_means = analysis_holder, dims = (Basin, EraType, AnalysisType))