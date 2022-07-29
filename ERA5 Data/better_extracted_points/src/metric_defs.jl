using DataFrames, StatsBase

custommetric(timefilterfunc, deviationfunc) = 
function metric(;eratype, stationmetadata, glacierbool, eralonlat, 
    eraelevation, eravals, stationvals, times)

    #Get the quick stuff out of the way first
    (isempty(eravals) || glacierbool || all(val==0 for val in eravals)) && return Inf

    #Now the messier stuff. For this metric I first filter for the desired times, and then calculate the 
    #percent of median rmsd
    t_mask = timefilterfunc(times)

    return @views deviationfunc(times[t_mask], eravals[t_mask], stationvals[t_mask])
end

myrmsd(x,y) = sqrt(mean((a-b)^2 for (a,b) in zip(x,y)))

function pom_rmsd(time, era, stat; median_groupfunc)
    isempty(time) && return Inf
    #First calculate the medians by grouping by median_groupfunc
    data=DataFrame(;time, era, stat, copycols = false)
    groupcol = transform!(data, :time=>ByRow(median_groupfunc)=>:groupcol)
    datacols = [:era, :stat]
    medians = combine(groupby(groupcol, :groupcol), datacols.=>median.=>datacols)
    pom(colname) = 
    function f(val, time)    
        idx = findfirst(==(median_groupfunc(time)), medians.groupcol)
        val/medians[idx, colname]
    end
    datacols_time = [[col, :time] for col in datacols]
    poms = select(data, (datacols_time.=>ByRow.(pom.(datacols)).=>datacols)...)
    return myrmsd(poms.stat, poms.era)
end

march_func(time) = month.(time) .== 3
endmarch_beginapril(time) = month.(time.+Day(16)).==4

snotelmetric = custommetric(march_func, (x...)->pom_rmsd(x...; median_groupfunc = month))
coursemetric = custommetric(endmarch_beginapril, (x...)->pom_rmsd(x...; median_groupfunc = (x->1)))
