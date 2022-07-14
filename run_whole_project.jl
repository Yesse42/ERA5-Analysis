burrowactivate()
import ERA5Analysis as ERA
NRCSSRC = joinpath(ERA.NRCSDATA, "..", "scripts")
NOHRSCSRC = joinpath(ERA.NOHRSCDATA, "..", "src")

include.(joinpath.(ERA.BASINDATA, ("basin_to_polys.jl",)))
include.(
    joinpath.(NRCSSRC, ("attach_station_ids.jl", "desired_stations.jl", "sanity_vis.jl"))
)
include(joinpath(NOHRSCSRC, "flightlines_in_basin.jl"))
include(
    joinpath(
        ERA.ERA5DATA,
        "extracted_points",
        "sensitivity_analysis",
        "src",
        "sensitivity.jl",
    ),
)
include.(
    joinpath.(
        ERA.ERA5DATA,
        "extracted_points",
        "src",
        (
            "nearest_era_index_at_station.jl",
            "extract_points.jl",
            "extracted_sanity_plot.jl",
            "plot_selected_by_basin.jl",
        ),
    )
)
include.(
    joinpath.(
        ERA.ERA5DATA,
        "extracted_flightlines",
        "src",
        ("nearest_era_index_flightline.jl", "extract_era_flightline.jl"),
    )
)
include.(
    joinpath.(
        ERA.ERA5DATA,
        "basin_extractions",
        "src",
        ("extract_basins.jl", "get_basin_averages.jl"),
    )
)
include.(
    joinpath.(
        ERA.COMPAREDIR,
        "Snow_Course",
        "src",
        ("land_vs_base.jl", "snow_course_comp.jl"),
    )
)
include.(joinpath.(ERA.COMPAREDIR, "SNOTEL", "src", ("snotel_comp.jl",)))
include.(
    joinpath.(
        ERA.COMPAREDIR,
        "NOHRSC",
        "src",
        ("nohrsc_comp.jl", "individual_fline_vis.jl"),
    )
)
include.(joinpath.(ERA.CLIMODIR, "Peak_SWE", "src", ("peak_swe.jl", "snotel_peak_swe.jl")))
include.(joinpath.(ERA.CLIMODIR, "Snow_Off", "src", ("snow_off.jl", "snow_off_snotel.jl")))
