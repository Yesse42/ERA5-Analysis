burrowactivate()
import ERA5Analysis as ERA
using CSV, DataFrames, JLD2, Dictionaries, Interpolations

include("../water_year.jl")

"""Accepts a year of swe and time values, and returns the dayofyear at which specific
Please filter out all missings and NaN's from swe"""
function swe_shape(swe, daysofyear, ascending_fractions, descending_fractions = reverse(ascending_fractions); snow_on_thresh = 0.01)

    #First get the date of peak swe
    peak_swe, peak_idx = findmax(swe)

    #Now get the snow on and off dates
    @views begin
    snow_on = findlast(<=(snow_on_thresh), swe[begin:peak_idx])
    snow_off = findfirst(<=(snow_on_thresh), swe[peak_idx:end]) 
    any(isnothing.((snow_on, snow_off))) && return missing
    snow_off += peak_idx - 1
    end
    any(isnothing.((snow_on, snow_off))) && return missing

    #Now partition the dataset in two
    @views ascending_swe, ascending_days = swe[snow_on:peak_idx], daysofyear[snow_on:peak_idx]
    @views descending_swe, descending_days = swe[peak_idx:snow_off], daysofyear[peak_idx:snow_off]
    T=eltype(daysofyear)
    ascending_vals = zeros(T, length(ascending_fractions))
    descending_vals = zeros(T, length(descending_fractions))

    for (i, frac) in enumerate(ascending_fractions)
        ascending_vals[i] = ascending_days[findfirst(>=(frac * peak_swe), ascending_swe)]
    end

    for (i, frac) in enumerate(descending_fractions)
        descending_vals[i] = descending_days[findlast(>=(frac * peak_swe), descending_swe)]
    end
    
    return (fracs = [ascending_fractions; 1; descending_fractions]', days = [ascending_vals; daysofyear[peak_idx]; descending_vals]')
end

function deduplicate(xvals, peak_idx)
    to_keep = trues(length(xvals))
   
    for i in LinearIndices(to_keep)
        if 1 < i < peak_idx
            if xvals[i] == xvals[i-1]
                to_keep[i-1] = false
            end
        elseif peak_idx < i < length(to_keep)
            if xvals[i] == xvals[i+1]
                to_keep[i+1] = false
            end
        elseif i == peak_idx
            if xvals[i] == xvals[i-1]
                to_keep[i-1] = false
            end
            if xvals[i] == xvals[i+1]
                to_keep[i+1] = false
            end
        end
    end

    to_keep
end

function swe_shape_output_to_interpolated_values(output)

    xvals = output.days
    yvals = output.fracs

    daysofyear = range(extrema(xvals)...)

    peak_idx = findfirst(==(1), vec(yvals))

    to_keep = deduplicate(xvals, peak_idx)

    count(to_keep) < 2 && return missing

    swe_interpolator = LinearInterpolation(vec(xvals[to_keep]), vec(yvals[to_keep]))
    swe_interped = swe_interpolator.(daysofyear)
    return (;daysofyear, swe_interped)
end

function pad_to_full_year(interped_cycle)
    ismissing(interped_cycle) && return missing
    start, finish = extrema(interped_cycle.daysofyear)
    return(daysofyear = 1:366, swe_interped = [zeros(start-1); interped_cycle.swe_interped; zeros(366-finish)])
end