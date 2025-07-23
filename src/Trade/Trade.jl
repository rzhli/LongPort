module Trade

using ..Config
using ..TradeTypes
using JSON3
using Dates

# Include the Push module
include("Push.jl")
using .Push

export TradeContext, submit_order, get_orders, set_on_order_changed, set_on_order_status

"""
TradeContext

参照Python SDK的TradeContext，提供交易API接口。

# Examples
```julia
# 加载配置
config = Config.from_toml(path="config.toml")

# 创建TradeContext
ctx = TradeContext(config)

# 提交订单
resp = ctx.submit_order("700.HK", OrderType.LO, OrderSide.Buy, 100, TimeInForceType.Day)
```
"""
mutable struct TradeContext
    config::Config.config
    callbacks::Push.Callbacks
    
    function TradeContext(config::Config.config)
        new(config, Push.Callbacks())
    end
end

"""
submit_order(ctx::TradeContext, symbol::String, order_type, side, quantity, time_in_force; kwargs...)

提交订单，类似Python SDK的ctx.submit_order()
"""
function submit_order(ctx::TradeContext, symbol::String, order_type, side, quantity, time_in_force; kwargs...)
    # 这里需要实现具体的订单提交逻辑
    throw(LongportException("submit_order not yet implemented"))
end

"""
get_orders(ctx::TradeContext)

获取订单列表，类似Python SDK的ctx.get_orders()
"""
function get_orders(ctx::TradeContext)
    # 这里需要实现具体的订单查询逻辑
    throw(LongportException("get_orders not yet implemented"))
end

"""
set_on_order_changed(ctx::TradeContext, callback::Function)

设置订单变更推送回调函数，参照Python SDK
"""
function set_on_order_changed(ctx::TradeContext, callback::Function)
    Push.set_on_order_changed!(ctx.callbacks, callback)
    @info "订单变更推送回调函数已设置"
end

"""
set_on_order_status(ctx::TradeContext, callback::Function)

设置订单状态推送回调函数，参照Python SDK
"""
function set_on_order_status(ctx::TradeContext, callback::Function)
    Push.set_on_order_status!(ctx.callbacks, callback)
    @info "订单状态推送回调函数已设置"
end

"""
处理WebSocket推送事件
参照Python版本的handle_push_event
"""
function handle_push_event!(ctx::TradeContext, json_data::String)
    result = Push.parse_push_event(json_data)
    if !isnothing(result)
        event_type, data = result
        Push.handle_push_event!(ctx.callbacks, event_type, data)
    end
end

# 为TradeContext添加方法调用的便利函数，类似Python对象方法
Base.getproperty(ctx::TradeContext, name::Symbol) = begin
    if name == :submit_order
        return (symbol::String, order_type, side, quantity, time_in_force; kwargs...) -> submit_order(ctx, symbol, order_type, side, quantity, time_in_force; kwargs...)
    elseif name == :get_orders
        return () -> get_orders(ctx)
    elseif name == :set_on_order_changed
        return (callback::Function) -> set_on_order_changed(ctx, callback)
    elseif name == :set_on_order_status
        return (callback::Function) -> set_on_order_status(ctx, callback)
    else
        return getfield(ctx, name)
    end
end

end # module TradeContext