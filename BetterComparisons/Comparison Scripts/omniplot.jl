using Plots

function omniplot(; basedat, landdat, basin, figtitle, stat_swe_name, era_swe_name, fom_climo_diff_name)
    l = grid(2, 2, widths=[0.8, 0.2, 0.8, 0.2])

    p1 = plot(
        basedat.datetime,
        basedat.fom_diff_mean;
        title = "Fraction of 1991-2020 Median Difference",
        xlabel = "Year",
        ylabel = "FOM Diff (unitless)",
        legend = :none,
    )
    plot!(p1, landdat.datetime, landdat.fom_diff_mean)
    plot!(p1, basedat.datetime, basedat[!, fom_climo_diff_name])
    p2 = plot(
        basedat.datetime,
        basedat[!, era_swe_name];
        label = "Base",
        title = "Fraction of Median",
        xlabel = "Year",
        ylabel = "Fraction of Median",
        legend = :none,
    )
    plot!(p2, landdat.datetime, landdat[!, era_swe_name]; label = "Land")
    plot!(p2, basedat.datetime, basedat[!, stat_swe_name]; label = "Station")
    legendp2 = plot(
        0:0,
        (1:3)';
        grid = false,
        showaxis = :hide,
        label = ["Base" "Land" "Station"],
        xaxis = nothing,
        yaxis = nothing,
    )
    legendp1 = plot(
        0:0,
        (1:3)';
        grid = false,
        showaxis = :hide,
        label = ["Base vs Station" "Land vs Station" "Station vs Climatology"],
        xaxis = nothing,
        yaxis = nothing,
    )
    bp = plot(p1, legendp1, p2, legendp2; layout = l, plot_title = figtitle, plot_titlefontsize = 13)
    return savefig(bp, "../vis/$(basin)_comp.png")
end
