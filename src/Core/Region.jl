module Region
    
    using ..Constant: PING_URL, CACHE_EXPIRE_SECONDS
    using HTTP, Dates

    export is_cn, region
    """
    用于地区检测，判断是否在中国大陆
    """
    # Internal mutable state
    const _region_cache = Ref{Union{Nothing, String}}(nothing)
    const _last_check_time = Ref{Union{Nothing, DateTime}}(nothing)

    """
    region() -> Union{Nothing, String}
    尝试检测当前网络区域（如 "CN" 表示中国）。使用缓存机制，避免重复请求。
    返回值：
    - 区域标识字符串（例如 "CN", "US", "HK"）
    - 如果无法识别或请求失败，返回 `nothing`
    """
    function region()::Union{Nothing, String}
        # Step 1: Check if we can reuse the cached result
        now = Dates.now()
        # Check cache validity
        if !isnothing(_region_cache[]) && !isnothing(_last_check_time[])
            if (now - _last_check_time[]) <= Dates.Second(CACHE_EXPIRE_SECONDS)
                return _region_cache[]
            end
        end

        # Step 2: Send request
        try
            resp = HTTP.get(PING_URL; readtimeout = 1000)
            headers_dict = Dict(resp.headers)
            region_header = get(headers_dict, "X-Ip-Region", nothing)
            if !isnothing(region_header)
                region_str = String(region_header)
                _region_cache[] = lowercase(region_str)  # Normalize to lowercase
                _last_check_time[] = now
                return region_str
            end
        catch e
            @warn "Failed to detect region due to network error" exception=(e, catch_backtrace())
        end
        return nothing
    end

    """
    is_cn() -> Bool
    Return true if the detected region is "CN" (China Mainland).
    """
    function is_cn()::Bool
        r = region()
        return r !== nothing && lowercase(r) == "cn"
    end
end # module
