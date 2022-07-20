burrowactivate()
import ERA5Analysis as ERA

@enum SnowOffType::Int8 AlwaysSnow NeverSnow DoesntEstablish TooMuchMissing

function snow_off_single_year(sd_data, dates; min_snowy_days = 30, is_snow_thresh = 2e-3, max_days_missing = 5)
    snow_bool = sd_data .> is_snow_thresh
    diffs = snow_bool[2:end] .- snow_bool[1:(end - 1)]
    possible_snow_off_idxs = findall(==(-1), diffs)
    sort!(possible_snow_off_idxs)

    #If there are no snow off idxs, determine if it's always or never snowy
    if isempty(possible_snow_off_idxs)
        if first(snow_bool) == 1
            return AlwaysSnow
        else
            return NeverSnow
        end
    end

    #Now check if they fulfill the min_snowy_days criterion
    #This iterates through the possible snow_off dates from earliest to latest as findall finds the earliest ones first
    current_off = DoesntEstablish
    for idx in possible_snow_off_idxs
        if idx < min_snowy_days
            continue
        end
        snowy_before_tally = sum(ERA.skipnaormiss(snow_bool[(idx - min_snowy_days + 1):idx] .== 1))
        n_miss_before_tally = count(ERA.na_or_miss, snow_bool[(idx - min_snowy_days + 1):idx])
        if n_miss_before_tally > max_days_missing
            current_off = TooMuchMissing
        elseif snowy_before_tally >= (min_snowy_days - n_miss_before_tally)
            #It doesn't count if it happens after August
            month(dates[idx + 1]) >= 9 && continue
            current_off = idx
        end
    end
    !isa(current_off, SnowOffType) && return dayofyear(dates[current_off + 1])
    return current_off
end
