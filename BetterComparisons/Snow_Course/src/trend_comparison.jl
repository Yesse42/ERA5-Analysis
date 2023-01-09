include("land_vs_base_func.jl")

using StatsBase, GLM, Distributions
import Base.Iterators as Itr

cd(@__DIR__)

slopes(x,y,idxs) = Itr.filter(!isnan, (y[i]-y[j])/(x[i]-x[j]) for i in idxs for j in 1:(i-1))

function theil_sen(x, y; bootstrap_size  = 600, null = 0)
    length(x) ≠ length(y) && throw(ArgumentError("Bad bad bad vectors not same length why make me suffer"))
    idxs = eachindex(x)
    slope = median(slopes(x,y,idxs))
    #Too lazy to special case for even/odd
    boot_arr = Vector{typeof(first(x)/first(y))}(undef, bootstrap_size)
    boot_sample_idxs = Vector{Int}(undef, length(x))
    for i in 1:bootstrap_size
        boot_sample_idxs .= rand.(Ref(idxs))
        boot_x, boot_y = (@view(data[boot_sample_idxs]) for data in (x, y))
        boot_arr[i] = median(slopes(boot_x, boot_y, idxs))
    end
    quant = quantilerank(boot_arr, null)
    quant = min(quant, 1-quant)

    return (;slope, p_val = quant)
end

function lstsq(x,y)
    xdata = hcat(ones(eltype(x),length(x)), x)
    fit = lm(xdata, y)
    std = stderror(fit)[2]
    myT = TDist(length(x)-2)
    slope = coef(fit)[2]
    p_val = cdf(myT, slope/std)
    p_val = 2*min(p_val, 1-p_val)
    return (;slope, p_val)
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
    n_tot::Int
end

..(x, sym) = getproperty.(x, sym)

function mean_basin_trend(stations, load_era, load_course; min_years_data = 20, 
    time_filter_func = (t->shifted_month(t)==4), swecols, sig_thresh = 0.05, fitfunc)
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
            theil_est = fitfunc(year.(combined.datetime), combined[!, colname])
            push!(slopes[colname], LOBF(theil_est..., nyears))
        end
    end
    basin_means = Dictionary{eltype(swecols), BasinLOBF}()
    for col in swecols
        data = slopes[col]
        isempty(data) && return missing
        mean_slope = sum((data..:slope) .* (data..:nyears)) / sum(data..:nyears)
        n_sig = sum(data..:pval .<= sig_thresh)
        insert!(basin_means, col, BasinLOBF(mean_slope, n_sig, length(data)))
    end
    return basin_means
end

load_land(id) = load_plain_nn("Land", id)
load_base(id) = load_plain_nn("Base", id)



function basin_trends(;basins = ERA.usable_basins, basin_to_stations = def_basin_to_station, swecols = [:snow_course_swe, :era_swe], fitfunc)
    loadfuncs = Tuple((other, load_snow_course) for other in (load_base, load_land))
    datavecs = [Float64[] for _ in 1:3]
    sigvecs = [Int[] for _ in 1:3]
    totvecs = [Int[] for _ in 1:3]
    for basin in basins
        basedat, landdat = (mean_basin_trend(basin_to_stations[basin], funcs...; swecols, fitfunc) for funcs in loadfuncs)
        any(ismissing.((basedat, landdat))) && ([push!.(vec, 0) for vec in (datavecs, sigvecs)]; continue)
        gp = getproperty
        for (sym, vec) in zip((:mean_slope, :n_sig, :n_tot), (datavecs, sigvecs, totvecs))
            push!(vec[1], gp(landdat[:era_swe], sym))
            push!(vec[2], gp(landdat[:snow_course_swe], sym))
            push!(vec[3], gp(basedat[:era_swe], sym))
        end
    end
    return (datavecs, sigvecs, totvecs)
end

dir = "../vis/othervis"

mkpath(dir)
for (lsfit, lsname) in zip((theil_sen, lstsq), ("Theil-Sen", "LSTSQ"))
    slopedata, sigdata, totdata = basin_trends(;fitfunc = lsfit)

    #Change to %of median, and change over 35 years
    slopedata .*= 100 * 25

    style_kwargs = (;
        title = "Snow Course April 1st Basin Avg. Trends, $lsname",
        titlefontsize=10,
        ylabel = "Theil-Sen Slope (% 1991-2020 Median / 25 years)",
        ylabelfontsize  = 8,
        xlabel = "Basin",
        margin = 5Plots.mm,
        legend = :outertopright,
        xlim = (-4, 30),
        yticks = -40:5:40
    )
    #Empty string indicates that error_bar_plot should return the plot
    myp = error_bar_plot(
        slopedata,
        "";
        style_kwargs,
        plotname = "April rmsd of mean basin_summary.png",
        ylim = (-50,50),
        labels = ["Land", "Snow Course", "Base"]
    )

    sigdata = vec(reduce(vcat, permutedims.(sigdata)))
    totdata = vec(reduce(vcat, permutedims.(totdata)))
    omnidata = reduce(vcat, permutedims.(slopedata))
    xvals = reshape(collect(eachindex(omnidata)), size(omnidata)) .+ (1:size(omnidata, 2))'
    xvals, yvals = vec(xvals), vec(omnidata)

    annotate!(myp, [(x, y+sign(y)*2, Plots.text("$n_sig", 7)) for (x,y,n_sig) in zip(xvals, yvals, sigdata)])

    annotate!(myp, [(x, -30, Plots.text("$n_tot", 7)) for (x,y,n_tot, idx) in zip(xvals, yvals, totdata, CartesianIndices(omnidata)) if (Tuple(idx)[1]-2)%3==0])

    annotate!(myp, [(-4, -30, Plots.text("# Stations:", pointsize=7, halign = :left))])

    savedir = "../vis/othervis"
    mkpath(savedir)
    savefig(myp, joinpath(savedir, "$lsname trends_by_basin.png"))
end