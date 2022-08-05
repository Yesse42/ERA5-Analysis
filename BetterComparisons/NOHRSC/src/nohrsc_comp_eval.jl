burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_nohrsc.jl"))
include.(
    joinpath.(
        "../../Snow_Course/src",
        ("snow_course_comp_func.jl", "land_vs_base_func.jl"),
    )
)

savedir = "../vis/plain_nn"

function is_nohrsc_period(time)
    if Date(2020, 3, 20) <= Date(2020, month(time), day(time)) <= Date(2020, 4, 30)
        return true
    else
        return false
    end
end

function nohrsc_group(time)
    myyear = year(time)
    if is_nohrsc_period(time)
        return Date(myyear, 3, 20)
    else
        return Date(myyear)
    end
end

nohrsc_compare_args = (;
    load_data_func = load_nohrsc_only,
    load_era_func = load_nohrsc_era,
    comparecolnames = [:gamma, :mean_era_swe],
    timecol = "datetime",
    groupfunc = nohrsc_group,
    median_group_func = is_nohrsc_period,
    eradatadir = joinpath(ERA.ERA5DATA, "extracted_points"),
)

nohrsc_plot_args = (;
    savedir,
)

basin_to_flines =
    jldopen(joinpath(ERA.NOHRSCDATA, "Land_basin_to_flines.jld2"))["basin_to_flines"]

mkpath(savedir)
snow_course_comp_lineplot(;
    era_load_func = load_nohrsc_era,
    savedir,
    basin_to_station = basin_to_flines,
    station_compare_args = nohrsc_compare_args,
    omniplot_args = nohrsc_plot_args,
    timepick = true,
    figtitle_func = basin -> "$basin ERA5 vs NOHRSC",
    diffsym = :fom_diff_mean,
    climodiffsym = :climo_fom_diff_mean,
    era_swe_name = :mean_era_swe_fom_mean,
    station_swe_name = :gamma_fom_mean,
)
