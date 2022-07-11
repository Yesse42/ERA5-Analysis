#Threshold to be considered snowy (in m)
const is_snow_thresh = 1e-3

function snow_off_single_year(snow_bool, dates; min_snow)
    diffs = snow_bool[2:end] .- snow_bool[1:(end - 1)]
    possible_snow_off_idxs = findall(==(-1), diffs)
    sort!(possible_snow_off_idxs)

    #If there are no snow off idxs, determine if it's always or never snowy
    if isempty(possible_snow_off_idxs)
        if first(snow_bool) == 1
            return NaN
        else
            return NaN
        end
    end

    #Now check if they fulfill the min_snow criterion
    #This iterates through the possible snow_off dates from earliest to latest as findall finds the earliest ones first
    current_off = nothing
    for idx in possible_snow_off_idxs
        if idx < min_snow
            continue
        elseif all(snow_bool[(idx - min_snow + 1):idx] .== 1)
            #It doesn't count if it happens after August
            month(dates[idx + 1]) >= 9 && continue
            current_off = idx
        end
    end
    !isnothing(current_off) && return dayofyear(dates[current_off + 1])
    return NaN
end
