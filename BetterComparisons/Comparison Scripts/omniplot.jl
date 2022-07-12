using Plots

function omniplot(; basedat, landdat, basin, figtitle, stat_swe_name, era_swe_name)
    l = @layout [(2, 1) c{0.19w}]

    p1 = plot(
        basedat.datetime,
        basedat.pom_diff_mean;
        label = "Base",
        title = "Percent of 1991-2020 Median Difference",
        xlabel = "Year",
        ylabel = "POM Diff (%)",
        legend = :none,
    )
    plot!(p1, landdat.datetime, landdat.pom_diff_mean; label = "Land")
    p2 = plot(
        basedat.datetime,
        basedat[!, era_swe_name];
        label = "Base",
        title = "Percent of Median",
        xlabel = "Year",
        ylabel = "Percent of Median",
        legend = :none,
    )
    plot!(p2, landdat.datetime, landdat[!, era_swe_name]; label = "Land")
    plot!(p2, basedat.datetime, basedat[!, stat_swe_name]; label = "Station")
    legendp = plot(
        0:0,
        (1:3)';
        grid = false,
        showaxis = :hide,
        label = ["Base" "Land" "Station"],
        xaxis = nothing,
        yaxis = nothing,
    )
    bp = plot(p1, p2, legendp; layout = l, plot_title = figtitle)
    return savefig(bp, "../vis/$(basin)_course_comp.png")
end
