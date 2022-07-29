cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, Dictionaries, Plots, StaticArrays, JLD2
import ERA5Analysis as ERA
pyplot()

all_data = jldopen("../../elevation_weight_data/rmsd_data.jld2")["rmsd_data"]

..(df, sym) = df[!, sym]

styleargs = (;)

for basin in ERA.basin_names
    plotmat = [plot(;styleargs...) for _ in 1:2, _ in 1:2]
    for (i, eratype) in enumerate(ERA.eratypes), (j, (diffstat, statname)) in enumerate(zip((:eldiff, :dist), ("Absolute Elevation Difference", "Great Circle Distance")))
        data = all_data[(basin, eratype)]
        diffs = data..diffstat
        rmsds = data.rmsd

        A = hcat(repeat([1], length(diffs)), diffs)

        #Now get a linear fit
        lstsq_coeffs = (A'*A)\(A'*rmsds)
        #Now get the domain
        scatter!(plotmat[i,j], diffs, rmsds; title = "$eratype $statname", label="", ms = 3, markerstrokewidth = 0, markerlpha = 0.5, 
                    xlabel = "$statname (m)", ylabel = "Frac. of Median RMSD")
        plot!(plotmat[i,j], [0, maximum(diffs)], [lstsq_coeffs[1],lstsq_coeffs[1] + lstsq_coeffs[2]*maximum(diffs)], label = "", linewidth = 2)
    end
    p = plot(plotmat...;layout = (2,2), plot_title  = "$basin April 1st RMSD Distance Dependence",size = 50 .*(16,16))
    savefig(p, "../../vis/elevation_rmsd/$basin.png")
end