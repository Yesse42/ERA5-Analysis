include(joinpath(@__DIR__, "../comparison_constants.jl"))

const snotel_data = CSV.read(joinpath(ERA.NRCSDATA, "cleansed", "SNOTEL_Data.csv"), DataFrame)

function load_snotel(id)
    cols = ["datetime", "SWE_$id"]
    outdata = rename(snotel_data[:, cols], ["datetime", "snotel_swe"])
    transform!(outdata, :datetime=>ByRow(Date)=>:datetime)
end