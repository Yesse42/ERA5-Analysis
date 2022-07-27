burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "comparison_machinery.jl"))

def_basin_to_station =
jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

station_compare_args = pairs((;load_data_func = load_snow_course,
                                comparecolnames = [:snow_course_swe, :era_swe],
                                timecol = "datetime",
                                groupfunc = shifted_month,
                                median_group_func = shifted_month,
                                n_obs_weighting = true,
                                eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")))

function land_vs_base_datagen(; basin_to_stations = def_basin_to_station,
    base_stat_name, land_stat_name = base_stat_name, climo_stat_name,
    station_compare_args = station_compare_args, time_to_pick = 4,
    load_era_func)
    land_stat = Float64[]
    base_stat = Float64[]
    climo_stat = Float64[]
    for basin in ERA.usable_basins
        eradata = DataFrame[]
        for eratype in ERA.eratypes
            

            courses = basin_to_stations[basin]
            basinmean = general_station_compare(
                eratype,
                courses;
                load_era_func,
                station_compare_args...
            )
            ismissing(basinmean) && break
            push!(eradata, basinmean.basindata)
        end

        length(eradata) < length(ERA.eratypes) && continue

        #Now plot the difference in percent of median and the anomaly difference on separate axes,
        #for both era5 land and base
        #Filter for the time to pick
        eradata = [filter(x -> x.datetime == time_to_pick, d) for d in eradata]
        #Now get the percent of median and anomaly diff
        ..(df, sym) = df[!, sym]
        push!(land_stat, only(eradata[2]..land_stat_name))
        push!(base_stat, only(eradata[1]..base_stat_name))
        push!(climo_stat, only(eradata[1]..climo_stat_name))
    end

    #Now return a vector of the vectors
    return collect((land_stat, climo_stat, base_stat))
end

function raw_anom_fom_comp_datagen(; eratype,
    basin_to_stations = def_basin_to_station,
    stats_to_extract = ["raw", "anom", "normed_anom", "fom"] .* "_rmsd",
    station_compare_args = station_compare_args, time_to_pick = 4, T=Float64)
    datastore = [T[] for _ in 1:length(stats_to_extract)]
    for basin in ERA.usable_basins

        courses = basin_to_stations[basin]
        basinmean = general_station_compare(
            eratype,
            courses;
            station_compare_args...
        )
        
        ismissing(basinmean) && continue

        basinmean = filter(x -> x.datetime == time_to_pick, basinmean.basindata)
        #Now get the wanted statistics
        for (statname, datavec) in zip(stats_to_extract, datastore)
            push!(datavec, only(basinmean[:, statname]))
        end
    end
    return datavec
end

const default_style = (;legend = :topleft, rotation=45, dpi = 300, ylim = (0,1))

"Default datavec should have land's data, then climo and then base"
function error_bar_plot(datavec, savedir; cvec = [:purple, :orange, :blue], xticklabels = ERA.usable_basins, 
    style_kwargs = default_style, labels = ["ERA5 Land","Station Climatology","ERA5 Base"],
    plotname = "basin_summary.png")
    omnidata = reduce(vcat, permutedims.(datavec))
    xvals = reshape(collect(eachindex(omnidata)), size(omnidata)) .+ (1:size(omnidata, 2))'
    fillcolors = reduce(hcat, (cvec for i in Base.axes(omnidata, 2)))
    xticks = xvals[cld(size(omnidata, 1), 2):size(omnidata, 1):end]

    p = bar(
        vec(xvals),
        vec(omnidata);
        fillcolor = vec(fillcolors),
        label = "",
        xticks = (xticks, xticklabels),
        style_kwargs...
    )
    bar!(
        p,
        (1:3)',
        [NaN, NaN, NaN]';
        show_axis = false,
        label = permutedims(labels),
        fillcolor = permutedims(cvec),
    )

    savefig(p, joinpath(savedir, plotname))
end