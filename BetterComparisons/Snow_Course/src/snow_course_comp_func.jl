burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "omniplot.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "comparison_machinery.jl"))

snow_course_from_basin =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

default_compare_args = (;
    load_data_func = load_snow_course,
    comparecolnames = [:snow_course_swe, :era_swe],
    timecol = "datetime",
    groupfunc = shifted_monthperiod,
    median_group_func = shifted_month,
    eradatadir = joinpath(ERA.ERA5DATA, "extracted_points"),
)

default_omniplot_args = (;
    savedir = "../vis",
)

function snow_course_comp_lineplot(;
    era_load_func,
    savedir,
    diffsym = :fom_diff_mean,
    climodiffsym = :climo_fom_diff_mean,
    era_swe_name = :era_swe_fom_mean,
    station_swe_name = :snow_course_swe_fom_mean,
    timepick = 4,
    basin_to_station = snow_course_from_basin,
    station_compare_args = default_compare_args,
    figtitle_func = (basin -> "$basin ERA5 vs Snow Course (Mar 16th - Apr 15th)"),
    omniplot_args = default_omniplot_args,
)
    for basin in ERA.usable_basins
        eradata = Union{DataFrame, Missing}[]

        for eratype in ERA.eratypes
            courses = basin_to_station[basin]
            basinmean = general_station_compare(
                eratype,
                courses;
                load_era_func = era_load_func,
                station_compare_args...,
            )
            if ismissing(basinmean)
                push!(eradata, missing)
            else
                push!(eradata, basinmean.basindata)
            end
        end

        any(ismissing.(eradata)) && continue

        #Now plot the difference in percent of median and the anomaly difference on separate axes,
        #for both era5 land and base
        #Filter for end of march/beginning of april
        eradata = [
            filter(
                x -> (station_compare_args[:median_group_func])(x.datetime) == timepick,
                d,
            ) for d in eradata
        ]
        basedat, landdat = eradata
        #Now get the percent of median and anomaly diff
        any(isempty.(eradata)) && continue
        ⊙(df, sym) = df[!, sym]
        omniplot(
            [basedat.datetime, landdat.datetime, basedat.datetime],
            [basedat ⊙ diffsym, landdat ⊙ diffsym, basedat ⊙ climodiffsym],
            [basedat.datetime, landdat.datetime, basedat.datetime],
            [basedat ⊙ era_swe_name, landdat ⊙ era_swe_name, basedat ⊙ station_swe_name];
            basin,
            figtitle = figtitle_func(basin),
            omniplot_args...,
        )
    end
end
