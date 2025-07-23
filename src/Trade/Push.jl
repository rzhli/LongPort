"""
Trade Push Event Handler Module

参照Python SDK的trade push事件处理机制，提供完整的交易推送事件处理。
对应Python版本的python/src/trade/push.rs
"""
module Push

using ..TradeTypes
using JSON3

export Callbacks, PushEvent, handle_push_event!, 
       set_on_order_changed!, set_on_order_status!

# 推送事件类型枚举
@enum PushEventType begin
    OrderChanged
    OrderStatus
    OrderFilled
    OrderCancelled
end

# 推送事件基类
abstract type PushEvent end

# 使用Trade/Types.jl中定义的PushOrderChanged，这里不再重复定义

"""
订单状态推送事件
"""
struct PushOrderStatus <: PushEvent
    order_id::String
    status::String
    updated_at::String
    
    function PushOrderStatus(data::Dict)
        new(
            get(data, "order_id", ""),
            get(data, "status", ""),
            get(data, "updated_at", "")
        )
    end
end

"""
回调函数存储结构
参照Python版本的Callbacks结构
"""
mutable struct Callbacks
    order_changed::Union{Function, Nothing}
    order_status::Union{Function, Nothing}
    order_filled::Union{Function, Nothing}
    order_cancelled::Union{Function, Nothing}
    
    function Callbacks()
        new(nothing, nothing, nothing, nothing)
    end
end

"""
设置订单变更回调函数
"""
function set_on_order_changed!(callbacks::Callbacks, callback::Function)
    callbacks.order_changed = callback
    @info "订单变更回调函数已设置"
end

"""
设置订单状态回调函数
"""
function set_on_order_status!(callbacks::Callbacks, callback::Function)
    callbacks.order_status = callback
    @info "订单状态回调函数已设置"
end

"""
设置订单成交回调函数
"""
function set_on_order_filled!(callbacks::Callbacks, callback::Function)
    callbacks.order_filled = callback
    @info "订单成交回调函数已设置"
end

"""
设置订单取消回调函数
"""
function set_on_order_cancelled!(callbacks::Callbacks, callback::Function)
    callbacks.order_cancelled = callback
    @info "订单取消回调函数已设置"
end

"""
处理推送事件
参照Python版本的handle_push_event函数
"""
function handle_push_event!(callbacks::Callbacks, event_type::PushEventType, data::Dict)
    try
        if event_type == OrderChanged
            handle_order_changed!(callbacks, TradeTypes.PushOrderChanged(data))
        elseif event_type == OrderStatus
            handle_order_status!(callbacks, PushOrderStatus(data))
        elseif event_type == OrderFilled
            handle_order_filled!(callbacks, data)
        elseif event_type == OrderCancelled
            handle_order_cancelled!(callbacks, data)
        else
            @warn "未知的推送事件类型" event_type
        end
    catch e
        @error "处理推送事件时发生错误" exception=e
    end
end

"""
处理订单变更事件
对应Python版本的handle_order_changed函数
"""
function handle_order_changed!(callbacks::Callbacks, order_changed::TradeTypes.PushOrderChanged)
    if !isnothing(callbacks.order_changed)
        try
            callbacks.order_changed(order_changed)
        catch e
            @error "订单变更回调函数执行失败" exception=e
        end
    end
end

"""
处理订单状态事件
"""
function handle_order_status!(callbacks::Callbacks, order_status::PushOrderStatus)
    if !isnothing(callbacks.order_status)
        try
            callbacks.order_status(order_status)
        catch e
            @error "订单状态回调函数执行失败" exception=e
        end
    end
end

"""
处理订单成交事件
"""
function handle_order_filled!(callbacks::Callbacks, data::Dict)
    if !isnothing(callbacks.order_filled)
        try
            callbacks.order_filled(data)
        catch e
            @error "订单成交回调函数执行失败" exception=e
        end
    end
end

"""
处理订单取消事件
"""
function handle_order_cancelled!(callbacks::Callbacks, data::Dict)
    if !isnothing(callbacks.order_cancelled)
        try
            callbacks.order_cancelled(data)
        catch e
            @error "订单取消回调函数执行失败" exception=e
        end
    end
end

"""
从JSON数据解析推送事件
"""
function parse_push_event(json_data::String)
    try
        data = JSON3.read(json_data)
        event_type_str = get(data, "event_type", "")
        
        event_type = if event_type_str == "order_changed"
            OrderChanged
        elseif event_type_str == "order_status"
            OrderStatus
        elseif event_type_str == "order_filled"
            OrderFilled
        elseif event_type_str == "order_cancelled"
            OrderCancelled
        else
            @warn "未知的事件类型" event_type_str
            return nothing
        end
        
        return (event_type, data)
    catch e
        @error "解析推送事件JSON数据失败" exception=e json_data
        return nothing
    end
end

end # module Push