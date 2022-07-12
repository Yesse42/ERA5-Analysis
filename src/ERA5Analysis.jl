module ERA5Analysis

for file in [
    "filepath_helpers.jl",
    "constants.jl",
]
    include("useful_scripts/$file")
end

end # module
