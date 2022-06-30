function isglacier(sd_arr; glacier_thresh=0.95)
    glacier_mask = (sum(sd_arr .> 0; dims=3) ./ size(sd_arr, 3)) .>= glacier_thresh
end