"""
缓存机制模块

提供基于时间的缓存功能，用于提高API调用性能。
"""
module Cache

using Dates

export SimpleCache, CacheWithKey, get_or_update

"""
CacheItem

缓存项，包含数据和过期时间。
"""
mutable struct CacheItem{T}
    data::T
    expires_at::DateTime
    
    function CacheItem(data::T, ttl_seconds::Float64) where {T}
        new{T}(data, now() + Second(floor(Int, ttl_seconds)))
    end
end

"""
SimpleCache

简单缓存，用于缓存单个值。
"""
mutable struct SimpleCache{T}
    item::Union{Nothing, CacheItem}
    ttl_seconds::Float64
    
    function SimpleCache{T}(ttl_seconds::Float64) where T
        new(nothing, ttl_seconds)
    end
end

"""
CacheWithKey

带键的缓存，用于缓存多个值。
"""
mutable struct CacheWithKey{K, V}
    items::Dict{K, CacheItem{V}}
    ttl_seconds::Float64
    
    function CacheWithKey{K, V}(ttl_seconds::Float64) where {K, V}
        new(Dict{K, CacheItem{V}}(), ttl_seconds)
    end
end

"""
is_expired(item::CacheItem) -> Bool

检查缓存项是否过期。
"""
function is_expired(item::CacheItem)::Bool
    return now() > item.expires_at
end

"""
get_or_update(cache::SimpleCache{T}, update_func::Function) -> T

获取缓存值或更新缓存。

# Arguments
- `cache::SimpleCache{T}`: 缓存对象
- `update_func::Function`: 更新函数，应该返回新的值

# Returns
- `T`: 缓存的值

# Examples
```julia
cache = SimpleCache{Vector{String}}(300.0)  # 5分钟TTL
result = get_or_update(cache) do
    # 获取数据的耗时操作
    ["AAPL.US", "GOOGL.US", "MSFT.US"]
end
```
"""
function get_or_update(update_func::Function, cache::SimpleCache{T})::T where T
    # 检查是否有缓存且未过期
    if !isnothing(cache.item) && !is_expired(cache.item)
        return cache.item.data
    end
    
    # 缓存过期或不存在，更新缓存
    try
        new_data = update_func()
        cache.item = CacheItem(new_data, cache.ttl_seconds)
        return new_data
    catch e
        # 如果更新失败，且有旧缓存，则返回旧缓存
        if !isnothing(cache.item)
            @warn "Cache update failed, using stale data" exception=(e, catch_backtrace())
            return cache.item.data
        else
            rethrow(e)
        end
    end
end

"""
get_or_update(cache::CacheWithKey{K, V}, key::K, update_func::Function) -> V

获取带键缓存的值或更新缓存。

# Arguments
- `cache::CacheWithKey{K, V}`: 缓存对象
- `key::K`: 缓存键
- `update_func::Function`: 更新函数，接收key作为参数，返回新的值

# Returns
- `V`: 缓存的值

# Examples
```julia
cache = CacheWithKey{String, Vector{String}}(300.0)  # 5分钟TTL
result = get_or_update(cache, "AAPL.US") do symbol
    # 获取该股票相关数据的耗时操作
    get_related_symbols(symbol)
end
```
"""
function get_or_update(cache::CacheWithKey{K, V}, key::K, update_func::Function)::V where {K, V}
    # 检查是否有缓存且未过期
    if haskey(cache.items, key) && !is_expired(cache.items[key])
        return cache.items[key].data
    end
    
    # 缓存过期或不存在，更新缓存
    try
        new_data = update_func(key)
        cache.items[key] = CacheItem(new_data, cache.ttl_seconds)
        return new_data
    catch e
        # 如果更新失败，且有旧缓存，则返回旧缓存
        if haskey(cache.items, key)
            @warn "Cache update failed for key $key, using stale data" exception=(e, catch_backtrace())
            return cache.items[key].data
        else
            rethrow(e)
        end
    end
end

"""
clear_cache!(cache::SimpleCache)

清空简单缓存。
"""
function clear_cache!(cache::SimpleCache)
    cache.item = nothing
end

"""
clear_cache!(cache::CacheWithKey)

清空带键缓存。
"""
function clear_cache!(cache::CacheWithKey)
    empty!(cache.items)
end

"""
clear_cache!(cache::CacheWithKey, key)

清空带键缓存中指定键的值。
"""
function clear_cache!(cache::CacheWithKey, key)
    delete!(cache.items, key)
end

"""
cleanup_expired!(cache::CacheWithKey)

清理带键缓存中过期的项。
"""
function cleanup_expired!(cache::CacheWithKey)
    expired_keys = []
    for (key, item) in cache.items
        if is_expired(item)
            push!(expired_keys, key)
        end
    end
    
    for key in expired_keys
        delete!(cache.items, key)
    end
    
    return length(expired_keys)
end

"""
cache_stats(cache::SimpleCache) -> NamedTuple

获取简单缓存的统计信息。
"""
function cache_stats(cache::SimpleCache)
    has_data = !isnothing(cache.item)
    is_valid = has_data && !is_expired(cache.item)
    
    return (
        has_data = has_data,
        is_valid = is_valid,
        ttl_seconds = cache.ttl_seconds
    )
end

"""
cache_stats(cache::CacheWithKey) -> NamedTuple

获取带键缓存的统计信息。
"""
function cache_stats(cache::CacheWithKey)
    total_items = length(cache.items)
    expired_items = count(is_expired, values(cache.items))
    valid_items = total_items - expired_items
    
    return (
        total_items = total_items,
        valid_items = valid_items,
        expired_items = expired_items,
        ttl_seconds = cache.ttl_seconds
    )
end

end # module Cache
