havd(ang) = sind(ang / 2)^2

"Points should be in (lon, lat) form IN DEGREES, distance is given in meters"
function great_circ_dist(p1, p2; r_sphere = 6.378e6)
    return 2r_sphere *
           asin(havd(p2[2] - p1[2]) + cosd(p1[2]) * cosd(p2[2]) * havd(p2[1] - p1[1]))
end

function brute_nearest_neighbor_idx(p, grid; dist = great_circ_dist)
    mindist = dist(first(grid), p)
    idx = nothing
    for I in CartesianIndices(grid)
        if (d = dist(grid[I], p)) <= mindist
            mindist = d
            idx = I
        end
    end
    return idx
end
