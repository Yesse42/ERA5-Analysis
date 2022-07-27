burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "comparison_machinery.jl"))

function snow_course_comp_lineplot(;era_load_func, savedir,
    diffsym = :fom_diff_mean, climodiffsym = :snow_course_swe_fom_mean)
    for basin in ERA.usable_basins
        eradata = DataFrame[]

        for eratype in ERA.eratypes
            basin_to_courses =
                jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

            courses = basin_to_courses[basin]
            basinmean = general_station_compare(
                eratype,
                courses;
                load_era_func = era_load_func,
                load_data_func = load_snow_course,
                comparecolnames = [:snow_course_swe, :era_swe],
                timecol = "datetime",
                groupfunc = shifted_monthperiod,
                median_group_func = shifted_month,
                eradatadir = joinpath(ERA.ERA5DATA, "extracted_points"),
                n_obs_weighting = true
            )
            push!(eradata, basinmean.basindata)
        end

        #Now plot the difference in percent of median and the anomaly difference on separate axes,
        #for both era5 land and base
        #Filter for end of march/beginning of april
        eradata = [filter(x -> month(x.datetime) == 4, d) for d in eradata]
        basedat, landdat = eradata
        #Now get the percent of median and anomaly diff
        ⊙(df, sym) = df[!, sym]
        omniplot([basedat.datetime, landdat.datetime, basedat.datetime],
            [basedat⊙diffsym, landdat⊙diffsym, basedat⊙climodiffsym .- 1],
            [basedat.datetime, landdat.datetime, basedat.datetime],
            [basedat⊙:era_swe_fom_mean, landdat⊙:era_swe_fom_mean, basedat⊙:snow_course_swe_fom_mean];
            basin,
            figtitle = "ERA5 vs Snow Course ($basin) (Mar 16th - Apr 15th)",
            stat_swe_name = "snow_course_swe_fom_mean",
            era_swe_name = "era_swe_fom_mean",
            fom_climo_diff_name = "snow_course_swe_fom_climo_diff_mean",
            savedir
        )
    end
end
