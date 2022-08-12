using Plots, RecursiveArrayTools

"The data should be input in vectors in the order base land station"
function omniplot(
    xdata2,
    ydata2;
    basin,
    figtitle,
    savedir = "../vis",
    corrs = []
)

    function badhcat(args...; fill = NaN)
        maxlen = maximum(length.(args))
        return reduce(
            hcat,
            [vcat(arr, repeat([fill], maxlen - length(arr))) for arr in args],
        )
    end

    baselandstationcolors = [:blue :purple :orange]

    xdata = badhcat(xdata2...; fill = first(first(xdata2)))
    ydata = badhcat(ydata2...)
    p2 = plot(
        xdata,
        ydata;
        title = "",
        xlabel = "Year",
        ylabel = "Basin Averaged Fraction of Median",
        legend = :topleft,
        label = ["Base" "Land" "Station"],
        c = baselandstationcolors,
    )
    if !isempty(corrs)
        ypos = 0.95
        for (key, value) in pairs(corrs)
            annotate!(p2, [(0.9, ypos), Plots.text("$key: $value", 8)])
            ypos -= 0.05
        end
    end
    scatter!(p2, xdata, ydata; label = "", c = baselandstationcolors, ms = 2)
    bp = plot(
        p2,
        plot_title = figtitle,
        plot_titlefontsize = 13,
    )
    return savefig(bp, joinpath(savedir, "$(basin)_comp.png"))
end
