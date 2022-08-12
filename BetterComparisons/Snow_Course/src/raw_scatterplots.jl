burrowactivate()
cd(@__DIR__)
import ERA5Analysis as ERA
using CSV, DataFrames, Plots, JLD2, StatsBase, Dates

include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_era.jl"))
include(joinpath(ERA.COMPAREDIR, "Load Scripts", "load_snow_course.jl"))
include(joinpath(ERA.COMPAREDIR, "Comparison Scripts", "comparison_machinery.jl"))

basin_to_courses =
    jldopen(joinpath(ERA.NRCSDATA, "cleansed", "Snow_Course_basin_to_id.jld2"))["basin_to_id"]

function get_all_basin_medians(stations, load_eratype, load_station; timecol = :datetime, swecols = [:era_swe, :snow_course_swe])
    outdfs = DataFrame[]
    for id in stations
        era = load_eratype(id)
        stat = load_station(id)
        any(ismissing.((era, stat))) && continue
        comboed = innerjoin(era, stat; on=timecol)
        filter!(x->shifted_month(x.datetime)==4, comboed)
        median_times = Date(1991) .<= comboed[!, timecol] .< Date(2021)
        broken = false
        for col in swecols
            median_data = comboed[median_times, col]
            isempty(median_data) && (broken = true; break)
            med = median(median_data)
            comboed[!, col] ./= med
        end
        broken && continue
        push!(outdfs, comboed)
    end
    return reduce(vcat, outdfs)
end

savedir = "../vis/othervis/raw_scatter"
mkpath(savedir)

for eratype in ERA.eratypes
    for basin in ERA.usable_basins
        load_eratype(id) = load_plain_nn(eratype, id)
        data = get_all_basin_medians(basin_to_courses[basin], load_eratype, load_snow_course)
        xdata, ydata = data.era_swe, data.snow_course_swe
        myp = scatter(xdata, ydata; title = "ERA5 $eratype $basin Basin April 1st ", label = "",
                      xlabel = "ERA5 FOM", ylabel = "Snow Course FOM", aspect_ratio = :equal)
        bounds = [minimum(minimum.((xdata, ydata))), maximum(maximum.((xdata, ydata)))]
        plot!(myp, bounds, bounds; label = "y=x")
        swe_cor = cor(xdata, ydata)
        annotate!(myp, [((0.2, 0.9), "corr: $(round(swe_cor; digits=2))")])
        savefig(myp, joinpath(savedir, "$basin $eratype"))
    end
end