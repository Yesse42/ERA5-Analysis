using Plots, RecursiveArrayTools

"The data should be input in vectors in the order base land station"
function omniplot(
    xdata1,
    ydata1,
    xdata2,
    ydata2;
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

    xdata = badhcat(xdata1...; fill = first(first(xdata1)))
    ydata = badhcat(ydata1...)
    p1 = plot(
        xdata,
        ydata;
        title = "Fraction of 1991-2020 Median Difference",
        xlabel = "Year",
        ylabel = "FOM Diff (unitless)",
        legend = :none,
        c=baselandstationcolors
    )
    scatter!(p1, xdata, 
                 ydata, label="", 
                 c=baselandstationcolors, ms=2)
    
    xdata = badhcat(xdata2...; fill = first(first(xdata2)))
    ydata = badhcat(ydata2...)
    p2 = plot(
        xdata,
        ydata;
        title = "Fraction of Median",
        xlabel = "Year",
        ylabel = "Fraction of Median",
        legend = :none,
        c=baselandstationcolors
    )
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
    scatter!(p2, xdata, 
                 ydata, label="", 
                 c=baselandstationcolors, ms=2)
    legendp1 = plot(
        0:0,
        (1:3)';
        grid = false,
        showaxis = :hide,
        label = ["Base vs Station" "Land vs Station" "Station vs Climatology"],
        xaxis = nothing,
        yaxis = nothing,
        c=baselandstationcolors,
        legendfontsize = 5
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
