burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, Dates, Printf

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "comparison_machinery.jl"))

def_basin_to_station =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

station_compare_args = pairs((;
    load_data_func = load_snow_course,
    comparecolnames = [:snow_course_swe, :era_swe],
    timecol = "datetime",
    groupfunc = shifted_month,
    median_group_func = shifted_month,
    eradatadir = joinpath(ERA.ERA5DATA, "extracted_points"),
))

function land_vs_base_datagen(;
    basin_to_stations = def_basin_to_station,
    base_stat_name,
    land_stat_name = base_stat_name,
    climo_stat_name,
    station_compare_args = station_compare_args,
    time_to_pick = 3,
    load_era_func,
    basins = ERA.usable_basins,
)
    land_stat = Float64[]
    base_stat = Float64[]
    climo_stat = Float64[]
    for basin in basins
        eradata = DataFrame[]
        for eratype in ERA.eratypes
            courses = basin_to_stations[basin]
            basinmean = general_station_compare(
                eratype,
                courses;
                load_era_func,
                station_compare_args...,
            )
            ismissing(basinmean) && break
            push!(eradata, basinmean.basindata)
        end

        length(eradata) < length(ERA.eratypes) && continue

        #Now plot the difference in percent of median and the anomaly difference on separate axes,
        #for both era5 land and base
        #Filter for the time to pick
        eradata = [filter(x -> x.datetime == time_to_pick, d) for d in eradata]
        if any(isempty.(eradata))
            push!.((land_stat, base_stat, climo_stat), NaN)
            continue
        end
        #Now get the percent of median and anomaly diff
        ..(df, sym) = df[!, sym]
        push!(land_stat, only(eradata[2] .. land_stat_name))
        push!(base_stat, only(eradata[1] .. base_stat_name))
        push!(climo_stat, only(eradata[1] .. climo_stat_name))
    end

    #Now return a vector of the vectors
    return collect((land_stat, climo_stat, base_stat))
end

function raw_anom_fom_comp_datagen(;
    load_era_func,
    eratype,
    basin_to_stations = def_basin_to_station,
    stats_to_extract = ["raw", "anom", "normed_anom", "fom", "rank"] .* "_rmsd",
    station_compare_args = station_compare_args,
    time_to_pick = 4,
    T = Union{Float64, Missing},
    basins = ERA.usable_basins,
)
    datastore = [T[] for _ in 1:length(stats_to_extract)]
    for basin in basins
        courses = basin_to_stations[basin]
        basinmean = general_station_compare(
            eratype,
            courses;
            load_era_func,
            station_compare_args...,
        )

        ismissing(basinmean) && continue

        basinmean = filter(x -> x.datetime == time_to_pick, basinmean.basindata)
        #Now get the wanted statistics
        for (statname, datavec) in zip(stats_to_extract, datastore)
            push!(datavec, only(basinmean[:, statname]))
        end
    end
    return datastore
end

"Default datavec should have land's data, then climo and then base"
function error_bar_plot(
    datavec,
    savedir;
    cvec = [:purple, :orange, :blue],
    xticklabels = ERA.usable_basins,
    style_kwargs = (;),
    labels = ["ERA5 Land", "Station Median", "ERA5 Base"],
    plotname = "basin_summary.png",
    legend = :topleft,
    rotation = 20,
    dpi = 300,
    ylim = (0, 1),
)
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
        legend,
        rotation,
        dpi,
        ylim,
        style_kwargs...,
    )
    bar!(
        p,
        (1:length(labels))',
        repeat([NaN], length(labels))';
        show_axis = false,
        label = permutedims(labels),
        fillcolor = permutedims(cvec),
    )
    if !isempty(savedir)
        return savefig(p, joinpath(savedir, plotname))
    else 
        return p
    end
end

standard_formatter(x) = Plots.text(Printf.format(Printf.Format("%.2f"), x); pointsize=12)

function error_heatmap(
    datavec,
    savedir;
    data_formatter = standard_formatter,
    xlabels,
    ylabels,
    style_kwargs = (;),
    plotname = "basin_summary.png",
)
    x = length(xlabels)
    y = length(ylabels)
    omnidata = reduce(vcat, permutedims.(datavec))
    heatmap(1:x, 1:y, omnidata; xticks = (1:x, xlabels), yticks = (1:y, ylabels), style_kwargs...)
    annotate!(vec(tuple.((1:x)', (1:y), data_formatter.(omnidata))))
    savefig(joinpath(savedir, plotname))
end
