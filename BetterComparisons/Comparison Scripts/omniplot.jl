using Plots, RecursiveArrayTools

function omniplot(;
    basedat,
    landdat,
    basin,
    figtitle,
    stat_swe_name,
    era_swe_name,
    fom_climo_diff_name,
    savedir = "../vis"
)
    l = grid(2, 2; widths = [0.8, 0.2, 0.8, 0.2])

    function badhcat(args...; fill = NaN)
        maxlen = maximum(length.(args))
        return reduce(hcat, [vcat(arr, repeat([fill], maxlen-length(arr))) for arr in args])
    end

    baselandstationcolors = [:blue :purple :orange]

    p1 = plot(
        basedat.datetime,
        basedat.fom_diff_mean;
        title = "Fraction of 1991-2020 Median Difference",
        xlabel = "Year",
        ylabel = "FOM Diff (unitless)",
        legend = :none,
        c=:blue
    )
    plot!(p1, landdat.datetime, landdat.fom_diff_mean, c=:purple)
    plot!(p1, basedat.datetime, basedat[!, fom_climo_diff_name], c=:orange)
    scatter!(p1, badhcat(basedat.datetime, landdat.datetime, basedat.datetime; fill=first(basedat.datetime)), 
                 badhcat(basedat.fom_diff_mean, landdat.fom_diff_mean, basedat[!, fom_climo_diff_name]), label="", 
                 c=baselandstationcolors, ms=2)
    p2 = plot(
        basedat.datetime,
        basedat[!, era_swe_name];
        label = "Base",
        title = "Fraction of Median",
        xlabel = "Year",
        ylabel = "Fraction of Median",
        legend = :none,
        c=:blue
    )
    plot!(p2, landdat.datetime, landdat[!, era_swe_name]; label = "Land", c=:purple)
    plot!(p2, basedat.datetime, basedat[!, stat_swe_name]; label = "Station", c=:orange)
    legendp2 = plot(
        0:0,
        (1:3)';
        grid = false,
        showaxis = :hide,
        label = ["Base" "Land" "Station"],
        xaxis = nothing,
        yaxis = nothing,
        c=baselandstationcolors
    )
    scatter!(p2, badhcat(basedat.datetime, landdat.datetime, basedat.datetime; fill=first(basedat.datetime)), 
                 badhcat(basedat[!, era_swe_name], landdat[!, era_swe_name], basedat[!, stat_swe_name]), label="", 
                 c=baselandstationcolors, ms=2)
    legendp1 = plot(
        0:0,
        (1:3)';
        grid = false,
        showaxis = :hide,
        label = ["Base vs Station" "Land vs Station" "Station vs Climatology"],
        xaxis = nothing,
        yaxis = nothing,
        c=baselandstationcolors
    )
    bp = plot(
        p1,
        legendp1,
        p2,
        legendp2;
        layout = l,
        plot_title = figtitle,
        plot_titlefontsize = 13,
    )
    return savefig(bp, joinpath(savedir,"$(basin)_comp.png"))
end
