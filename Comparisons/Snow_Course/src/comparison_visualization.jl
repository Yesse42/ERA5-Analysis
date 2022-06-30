using CSV, DataFrames, Dates, Dictionaries, DimensionalData, StatsBase, JLD2, Plots
cd(@__DIR__)
burrowactivate()
import ERA5_Analysis as ERA

#Load in the data
course_data = jldopen("../data/snow_course_monthly_data.jld2","r")["snow_course_data"]
EraType, Station = jldopen("../data/snow_course_monthly_data.jld2","r")["dims"]
basin_data = jldopen("../data/basin_mean_snow_course.jld2")["basin_means"]
mydims = jldopen("../data/basin_mean_snow_course.jld2")["dims"]
Basin, EraType, AnalysisType = mydims

april_summary_df = DataFrame(eratype = [], basin=[], Mean_diff=[], Mean_anom_diff=[], Mean_pom_diff=[],
                    RMSD_diff=[], RMSD_anom_diff=[], RMSD_pom_diff=[])
for eratype in ERA.eratypes
    for basin in ERA.basin_names
        #First generate some summary statistics
        data = basin_data[Basin(At(basin)), EraType(At(eratype)), AnalysisType(At("Averages"))]
        data = data[findfirst(==(4), data.month), :]
        aprildata = select!(DataFrame(data),:month=>(x->eratype)=>:eratype, :month=>(x->basin)=>:basin, Not(:month))
        push!(april_summary_df, only(eachrow((aprildata))))

        #Now I want a histogram of fraction of median
        if basin in ("Chena", "Kenai")
            data = basin_data[Basin(At(basin)), EraType(At(eratype)), AnalysisType(At("Monthly"))]
            hist_data = collect(skipmissing(data.pom_diff))
            hist_bins = -1:0.05:1
            hist_plot_points = hist_bins[1:end-1].+0.025
            histo = fit(Histogram, hist_data, hist_bins; closed=:left)
            myplot = bar(hist_plot_points, histo.weights; title="April 1st $basin basin ERA $eratype Fraction of Median Difference (Basin-ERA)",
                    xlabel="Fraction of Median Difference", ylabel="Count", titlefontsize=10)
            save("../vis/frac_median_hists/$basin basin ERA $eratype.png",myplot)
        end
    end
end

#This is the source of my summary table
display(april_summary_df)

#Now get the snow course data by station for each chena basin station
chena_huc = ERA.chena_basin_ids[1]
station_metadata = CSV.read("$(ERA.NRCSDATA)/cleansed/Relevant_Stations.csv", DataFrame)
ids = first.(DimPoints(course_data))[:,1]
filter!(id->occursin(chena_huc, string(station_metadata[findfirst(==(id), station_metadata.ID), :HUC])), ids)


#Now select the relevant stations from the Array
for eratype in ERA.eratypes 
    #Now get the elevation differences
    el_diff_arr = CSV.read(ERA.ERA5DATA*"/extracted_points/data/$(eratype)_elevations.csv", DataFrame)
    transform!(el_diff_arr, [:stat_el,:era_el]=>ByRow((x,y)->x-y)=>:stat_minus_era)
    station_eldiffs = el_diff_arr[findall(id->id in ids, el_diff_arr.ID), :stat_minus_era]
    dataframes = course_data[Station(At(ids)), EraType(At(eratype))]
    pom_diff = []
    for dataframe in dataframes
        filter!(row->row.month==4, dataframe)
        push!(pom_diff, dataframe[1, :pon_diff_Mean])
    end
    eldiff_scatterplot = scatter(station_eldiffs, pom_diff, title="ERA $eratype Chena Basin April 1st",
                        xlabel = "Station minus ERA Gridpoint Elevation Difference (m)", ylabel="Station Minus ERA Fraction of Median difference",
                        label="")

                        save("../vis/elevation_bias_scatterplots/Chena basin ERA $eratype.png",eldiff_scatterplot)
end
