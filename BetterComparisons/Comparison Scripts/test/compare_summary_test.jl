cd(@__DIR__)
using CSV, DataFrames, Dates, Dictionaries, AxisArrays, StatsBase, JLD2, Missings, Plots
burrowactivate()
import ERA5Analysis as ERA, Base.Iterators as Itr

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include("../compare_summary.jl")
include("../comparison_machinery.jl")

load_plain_nn(_, eratype, id) = load_era(joinpath(ERA.ERA5DATA, "better_extracted_points", "plain_nn"), eratype, id)

#Load in the snow course and ERA5
basin_to_courses = jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]
basin = "Kenai"
eratype = "Land"
outdict = Dictionary()
outera = Dictionary()
dataframe_storage = []
for stat in basin_to_courses[basin]
    nn = load_plain_nn(nothing, eratype, stat)
    course = load_snow_course(stat)
    (ismissing(nn) || ismissing(course)) && (println("$stat No Data"); continue)
    comboed = innerjoin(nn, course; on = :datetime)
    dropmissing!(comboed)

    #Now see if it's actually calculating stuff right
    #First get the median by month
    datacols = string.([:snow_course_swe, :era_swe])
    mediangroup = groupby(filter(x->1991<=year(x.datetime)<=2020, transform(comboed, :datetime=>ByRow(shifted_month)=>:shiftmonth)), :shiftmonth)
    mymedian(x) = if isempty(x) return missing else median(x) end
    medians = combine(mediangroup, datacols.=>mymedian.=>datacols.*"median")
    function getmedian(time, datasource)
        idx = findfirst(==(shifted_month(time)), medians.shiftmonth)
        isnothing(idx) && return missing
        return medians[idx, datasource*"median"]
    end

    #Now calculate the fractions of median
    fomfuncs = [(x,t)->x/getmedian(t, datacol) for datacol in datacols]
    datacols_time = [[col, "datetime"] for col in datacols]
    fomcols = datacols.*"fom"
    transform!(comboed, (datacols_time.=>ByRow.(fomfuncs).=>fomcols)...)

    dropmissing!(comboed)

    #Now get the rmsd over the month period, with the number of obs
    group_shiftmonth = groupby(transform(comboed, :datetime=>ByRow(shifted_month)=>:shiftmonth), :shiftmonth)
    #And now get the rmsd
    rmsd_data = combine(group_shiftmonth, fomcols=>StatsBase.rmsd=>:rmsd, nrow=>:n_obs)

    #And push just the 3th time to the basin mean
    filter!(x->x.shiftmonth == 3,rmsd_data)
    if isempty(rmsd_data) continue end
    insert!(outdict, stat, (rmsd = only(rmsd_data[:, :rmsd]), n_obs = only(rmsd_data[:, :n_obs])))

    comp_sum_data = comparison_summary(
        comboed,
        datacols,
        "datetime";
        anom_stat = "median",
        groupfunc = shifted_month,
        median_group_func = shifted_month,
    ).grouped_data
    month_idx = findfirst(==(3), comp_sum_data.shifted_month)
    era_rmsd = comp_sum_data[month_idx, :fom_rmsd]
    era_nobs = comp_sum_data[month_idx, :n_obs]
    insert!(outera, stat, (rmsd = era_rmsd, n_obs = era_nobs))
    push!(dataframe_storage, comp_sum_data[[month_idx], :])
end

for (dict, name) in zip((outdict, outera), ("Mine", "Comp Summary"))
    display(name)
    errors = getproperty.(dict, :rmsd)
    n_obs = getproperty.(dict, :n_obs)
    display(sum(errors.*n_obs)/sum(n_obs))
    display(mean(errors))
end

basin_agg = basin_aggregate(dataframe_storage; timecol = :shifted_month, n_obs_weighting = true)
display(basin_agg[:, r"fom_rmsd"])