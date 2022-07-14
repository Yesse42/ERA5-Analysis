cd(@__DIR__)
burrowactivate()
using CSV, DataFrames, Dates, NCDatasets, Plots, StaticArrays
import ERA5Analysis as ERA

"""An analysis of how sensitive the outcome of our experiment is to different weighting functions and the size of the
'best nearby grid point' search window"""
function sensitivity(eratype, erafile, basin, offset, weightfunc)
    #Bring in the stations for this basin

    #Bring in the ERA data too

    #Now get the nearest neighbor indices

    #Extract the ERA data for each basin, and make it into a time series
end