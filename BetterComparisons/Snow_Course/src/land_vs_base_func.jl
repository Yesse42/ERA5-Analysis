burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "comparison_machinery.jl"))

function land_vs_base_bar(;load_era_func, savedir)
    land_pom_rmsd = []
    base_pom_rmsd = []
    climo_pom_rmsd = []
    for basin in ERA.usable_basins
        eradata = DataFrame[]

        for eratype in ERA.eratypes
            basin_to_courses =
                jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

            courses = basin_to_courses[basin]
            basinmean = general_station_compare(
                eratype,
                courses;
                load_data_func = load_snow_course,
                load_era_func,
                comparecolnames = [:era_swe, :snow_course_swe],
                timecol = "datetime",
                groupfunc = shifted_month,
                median_group_func = shifted_month,
                n_obs_weighting = true,
                eradatadir = joinpath(ERA.ERA5DATA, "extracted_points")
            )
            ismissing(basinmean) && break
            push!(eradata, basinmean.basindata)
        end

        length(eradata) < length(ERA.eratypes) && continue

        #Now plot the difference in percent of median and the anomaly difference on separate axes,
        #for both era5 land and base
        #Filter for end of march/beginning of april
        eradata = [filter(x -> x.datetime == 4, d) for d in eradata]
        #Now get the percent of median and anomaly diff
        push!(land_pom_rmsd, only(eradata[2].fom_diff_rmsd))
        push!(base_pom_rmsd, only(eradata[1].fom_diff_rmsd))
        push!(climo_pom_rmsd, only(eradata[1].snow_course_swe_fom_climo_diff_rmsd))
    end

    #Now barplot land vs base and land vs climatology

    omnidata = reduce(vcat, permutedims.((land_pom_rmsd, climo_pom_rmsd, base_pom_rmsd)))
    xvals = reshape(collect(eachindex(omnidata)), size(omnidata)) .+ (1:size(omnidata, 2))'
    cvec = [:purple, :orange, :blue]
    fillcolors = reduce(hcat, (cvec for i in Base.axes(omnidata, 2)))
    xticks = xvals[2:3:end]
    xticklabels = ERA.usable_basins

    p = bar(
        vec(xvals),
        vec(omnidata);
        fillcolor = vec(fillcolors),
        legend = :topleft,
        label = "",
        xticks = (xticks, xticklabels),
        rotation = 45,
        dpi = 300,
        ylim=(0,1)
    )
    plot!(
        p;
        title = "Snow Course April 1st FOM Difference RMSD",
        ylabel = "Fraction of Median RMSD (unitless)",
        xlabel = "Basin",
    )
    bar!(
        p,
        (1:3)',
        [NaN, NaN, NaN]';
        show_axis = false,
        label = ["ERA5 Land" "Station Climatology" "ERA5 Base"],
        fillcolor = permutedims(cvec),
    )

    savefig(p, joinpath(savedir, "basin_summary.png"))
end