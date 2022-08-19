burrowactivate()
import ERA5Analysis as ERA
cd(@__DIR__)
using Plots, DataFrames, CSV, StatsBase
gr()

include(joinpath(ERA.COMPAREDIR, "SNOTEL", "src", "water_year.jl"))

import Base.Iterators as Itr

slopes(x,y,idxs) = Itr.filter(!isnan, (y[i]-y[j])/(x[i]-x[j]) for i in idxs for j in 1:(i-1))

function theil_sen(x, y; bootstrap_size  = 10000, null = 0)
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

    return (;slope, p_val = quant, intercept = median(y - slope .* x))
end

savedir = "../vis/basin_trends"
mkpath(savedir)

for basin in ERA.usable_basins
    data = Dict{String, DataFrame}()
    my_plot = plot(;title="$basin Basin Average Peak SWE Trends", ylabel = "Percent of 1991-2020 Median Peak SWE", xlabel = "Water Year")
    yval = 0.9
    for eratype in ERA.eratypes
        basin_data = CSV.read(joinpath(ERA.ERA5DATA, "basin_extractions", eratype, "$(basin)_sd_avgs.csv"), DataFrame)

        if eratype == "Base" filter!(x->water_year(x.datetime) > 1978, basin_data) end

        basin_data.sd_avg .*= ERA.meter_to_inch

        #Now groupby water year
        transform!(basin_data, :datetime=>ByRow(water_year)=>:water_year)

        water_year_data = groupby(basin_data, :water_year)

        #Take the max swe
        water_year_data = combine(water_year_data, :sd_avg=>maximum=>:peak_swe)

        mask_1991_2020 = 1990 .<= water_year_data.water_year .<= 2019

        median_peak = median(water_year_data.peak_swe[mask_1991_2020])

        water_year_data[!, :pom_peak_swe] = 100 .* water_year_data.peak_swe ./ median_peak

        #And now plot the data
        plot!(my_plot, water_year_data.water_year, water_year_data.pom_peak_swe; label = eratype)

        #Get the trend line
        slope, p_val, intercept = theil_sen(water_year_data.water_year, water_year_data.pom_peak_swe)
        extremes = collect(extrema(water_year_data.water_year))
        plot!(my_plot, extremes, intercept .+ slope .* extremes; label = "$eratype Trend")

        annotate!(my_plot,[((0.1,yval), Plots.text("$eratype pval: $(round(p_val, digits=5))", 6, :left))])
        yval -= 0.05
    end

    display(my_plot)

end