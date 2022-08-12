include("land_vs_base_func.jl")

cd(@__DIR__)

function rmsd_of_basin_mean(stations, load_course, load_eratype; min_years_data = 6, time_filter_func = (t->shifted_month(t)==4))
    basin_data = DataFrame[]
    swecols = nothing
    for id in stations
        datas = (load_eratype(id), load_course(id))
        any(ismissing.(datas)) && continue
        combined = innerjoin(datas...; on=:datetime, makeunique = true)
        swecols = names(combined[:, Not(:datetime)])
        transform!(combined, :datetime=>ByRow(shifted_monthperiod)=>:datetime)
        combined = combine(groupby(combined, :datetime), swecols.=>mean.=>swecols, nrow=>:n_obs)
        filter!(row->time_filter_func(row.datetime), combined)
        length(unique(year(t) for t in combined.datetime)) < min_years_data && continue
        in_median_time = Date(1991) .<= combined.datetime .< Date(2021)
        for colname in swecols
            combined[!, colname] ./= median(combined[in_median_time, colname])
        end
        push!(basin_data, combined)
    end

    basinmean = basin_aggregate(basin_data)
    ismissing(basinmean) && return missing

    #And now finally calculate the rmsd
    datacols = basinmean[:, swecols]
    myrmsd(x,y) = sqrt(mean((a-b)^2 for (a,b) in zip(x,y)))
    return myrmsd(eachcol(datacols)...)
end

load_land(x) = load_plain_nn("Land", x)
load_base(x) = load_plain_nn("Base", x)
function load_climo(x)
    data = load_snow_course(x)
    data.snow_course_swe  = repeat([1.], nrow(data))
    return data
end

function basin_rmsds(;basins = ERA.usable_basins, basin_to_stations = def_basin_to_station)
    loadfuncs = Tuple((load_snow_course, other) for other in (load_land, load_climo, load_base))
    datavecs = [Float64[] for _ in 1:length(loadfuncs)]
    for basin in basins
        for (i,funcs) in enumerate(loadfuncs)
            basin_rmsd = rmsd_of_basin_mean(basin_to_stations[basin], funcs...)
            push!(datavecs[i], basin_rmsd)
        end
    end
    return datavecs
end

dir = "../vis/othervis"

mkpath(dir)
datavec = basin_rmsds()
[data[isnan.(data)] .= 0 for data in datavec]
style_kwargs = (;
    title = "Snow Course April 1st RMSD of Basin Average FOM",
    ylabel = "Fraction of Median RMSD",
    xlabel = "Basin",
    margin = 5Plots.mm,
)
error_bar_plot(
    datavec,
    dir;
    style_kwargs,
    plotname = "April rmsd of mean basin_summary.png",
    ylim = (0,1)
)