include("land_vs_base_func.jl")

using StatsBase

cd(@__DIR__)

function theil_sen(x, y)
    length(x) ≠ length(y) && throw(ArgumentError("Bad bad bad vectors not same length why make me suffer"))
    idxs = eachindex(x)
    sorted_slopes = sort!([(y[i]-y[j])/(x[i]-x[j]) for i in idxs for j in 1:(i-1)])
    #Too lazy to special case for even/odd
    theil_slope = median(sorted_slopes)

    quant = quantilerank(sorted_slopes, 0)
    quant = 2*min(quant, 1-quant)

    return (slope = theil_slope, two_sided_p_val = quant)
end

const α = Float64
struct LOBF
    slope::α 
    pval::α
    nyears::Int
end

struct BasinLOBF
    mean_slope::α
    n_sig::Int
end

..(x, sym) = getproperty.(x, sym)

function mean_basin_trend(stations, load_era, load_course; min_years_data = 20, 
    time_filter_func = (t->shifted_month(t)==4), swecols, sig_thresh = 0.05)
    slopes = Dictionary(swecols, [LOBF[] for _ in swecols])
    for id in stations
        datas = (load_era(id), load_course(id))
        any(ismissing.(datas)) && continue
        combined = innerjoin(datas...; on=:datetime)
        transform!(combined, :datetime=>ByRow(shifted_monthperiod)=>:datetime)
        combined = combine(groupby(combined, :datetime), swecols.=>mean.=>swecols)
        filter!(row->time_filter_func(row.datetime), combined)
        nyears  =length(unique(year(t) for t in combined.datetime))
        nyears < min_years_data && continue
        in_median_time = Date(1991) .<= combined.datetime .< Date(2021)
        for (i,colname) in enumerate(swecols)
            combined[!, colname] ./= median(combined[in_median_time, colname])

            #Now that we have the medians for each year we just need to fit the trends
            theil_est = theil_sen(year.(combined.datetime), combined[!, colname])
            push!(slopes[colname], LOBF(theil_est..., nyears))
        end
    end
    basin_means = Dictionary{eltype(swecols), BasinLOBF}()
    for col in swecols
        data = slopes[col]
        isempty(data) && return missing
        mean_slope = sum((data..:slope) .* (data..:nyears)) / sum(data..:nyears)
        n_sig = sum(data..:pval .<= sig_thresh)
        display(data..:pval)
        insert!(basin_means, col, BasinLOBF(mean_slope, n_sig))
    end
    return basin_means
end

load_land(id) = load_plain_nn("Land", id)
load_base(id) = load_plain_nn("Base", id)



function basin_trends(;basins = ERA.usable_basins, basin_to_stations = def_basin_to_station, swecols = [:snow_course_swe, :era_swe])
    loadfuncs = Tuple((other, load_snow_course) for other in (load_base, load_land))
    datavecs = [Float64[] for _ in 1:3]
    sigvecs = [Int[] for _ in 1:3]
    for basin in basins
        basedat, landdat = (mean_basin_trend(basin_to_stations[basin], funcs...; swecols) for funcs in loadfuncs)
        any(ismissing.((basedat, landdat))) && ([push!.(vec, 0) for vec in (datavecs, sigvecs)]; continue)
        gp = getproperty
        for (sym, vec) in zip((:mean_slope, :n_sig), (datavecs, sigvecs))
            push!(vec[1], gp(landdat[:era_swe], sym))
            push!(vec[2], gp(basedat[:snow_course_swe], sym))
            push!(vec[3], gp(basedat[:era_swe], sym))
        end
    end
    return (datavecs, sigvecs)
end

dir = "../vis/othervis"

mkpath(dir)
slopedata, sigdata = basin_trends()
style_kwargs = (;
    title = "Snow Course April 1st RMSD of Basin Average FOM",
    ylabel = "Fraction of Median RMSD",
    xlabel = "Basin",
    margin = 5Plots.mm,
)
#Empty string indicates that error_bar_plot should return the plot
myp = error_bar_plot(
    slopedata,
    "";
    style_kwargs,
    plotname = "April rmsd of mean basin_summary.png",
    ylim = :auto
)

sigdata = vec(reduce(vcat, permutedims.(sigdata)))
omnidata = reduce(vcat, permutedims.(slopedata))
xvals = reshape(collect(eachindex(omnidata)), size(omnidata)) .+ (1:size(omnidata, 2))'
xvals, yvals = vec(xvals), vec(omnidata)

annotate!(myp, [(x, y+sign(y)*0.002, "$(Int(n_sig))") for (x,y,n_sig) in zip(xvals, yvals, sigdata)])