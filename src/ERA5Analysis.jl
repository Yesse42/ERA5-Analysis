module ERA5Analysis

for file in [
    "analysis_helpers.jl",
    "filepath_helpers.jl",
    "netcdf_helpers.jl",
    "shapefile_helpers.jl",
    "constants.jl",
]
    include("useful_scripts/$file")
end

end # module
