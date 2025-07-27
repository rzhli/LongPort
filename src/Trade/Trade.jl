module Trade

using ..Config
using ..TradeTypes
using ..Client
using JSON3
using Dates

# Include the Push module
include("Push.jl")
using .Push

export TradeContext, submit_order, get_orders, set_on_order_changed, set_on_order_status,
       cancel_order, replace_order, get_account_balance, get_cash_flow, get_fund_positions,
       get_positions, get_margin_ratio, estimate_max_purchase_quantity


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

# Arguments
- `symbol::String`: 股票代码
- `order_type`: 订单类型 (OrderType enum)
- `side`: 买卖方向 (OrderSide enum)  
- `quantity::Int`: 数量
- `time_in_force`: 时效性 (TimeInForceType enum)
- `price::Float64=0.0`: 价格(市价单可为0)
- `outside_rth::OutsideRTH=RTH`: 盘前盘后
- `remark::String=""`: 备注

# Returns
- `SubmitOrderResponse`: 包含订单ID的响应
"""
function submit_order(
    ctx::TradeContext, 
    symbol::String, 
    order_type, 
    side, 
    quantity::Int, 
    time_in_force; 
    price::Float64=0.0,
    outside_rth=TradeTypes.RTH,
    remark::String=""
)
    # 构建订单参数
    params = Dict{String, Any}(
        "symbol" => symbol,
        "order_type" => Int(order_type),
        "side" => Int(side),
        "submitted_quantity" => quantity,
        "time_in_force" => Int(time_in_force),
        "remark" => remark,
        "outside_rth" => Int(outside_rth)
    )
    
    # 只有限价单需要价格
    if order_type != TradeTypes.MO  # 不是市价单
        params["submitted_price"] = string(price)
    end
    
    try
        # 使用POST方法提交订单
        result = Client.post(ctx.config, "/v1/trade/order", params)
        
        if haskey(result, "data")
            return TradeTypes.SubmitOrderResponse(result.data)
        else
            throw(LongportException("提交订单失败: 响应格式异常"))
        end
    catch e
        @error "提交订单失败" symbol=symbol exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
get_orders(ctx::TradeContext; symbol::String="", status::Vector{OrderStatus}=OrderStatus[], side::OrderSide=OrderSide.UnknownSide, market::String="", order_id::String="")

获取订单列表，类似Python SDK的ctx.get_orders()

# Arguments  
- `symbol::String=""`: 股票代码过滤
- `status::Vector{OrderStatus}=[]`: 订单状态过滤
- `side::OrderSide=OrderSide.UnknownSide`: 买卖方向过滤
- `market::String=""`: 市场过滤
- `order_id::String=""`: 订单ID过滤

# Returns
- `Vector`: 订单列表
"""
function get_orders(
    ctx::TradeContext; 
    symbol::String="", 
    status::Vector{OrderStatus}=OrderStatus[], 
    side::OrderSide=OrderSide.UnknownSide,
    market::String="", 
    order_id::String=""
)
    # 构建查询参数
    params = Dict{String, String}()
    
    !isempty(symbol) && (params["symbol"] = symbol)
    !isempty(status) && (params["status"] = join([string(Int(s)) for s in status], ","))
    side != OrderSide.UnknownSide && (params["side"] = string(Int(side)))
    !isempty(market) && (params["market"] = market)
    !isempty(order_id) && (params["order_id"] = order_id)
    
    try
        # 使用GET方法查询订单
        result = Client.get(ctx.config, "/v1/trade/orders"; params=params)
        
        if haskey(result, "data") && haskey(result.data, "orders")
            return result.data.orders
        else
            @warn "获取订单列表: 响应格式异常" result=result
            return []
        end
    catch e
        @error "获取订单列表失败" exception=(e, catch_backtrace())
        rethrow(e)
    end
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

# --- Additional Trade Functions ---

"""
cancel_order(ctx::TradeContext, order_id::String)

取消订单
"""
function cancel_order(ctx::TradeContext, order_id::String)
    params = Dict("order_id" => order_id)
    
    try
        result = Client.post(ctx.config, "/v1/trade/order/cancel", params)
        return haskey(result, "data") ? result.data : nothing
    catch e
        @error "取消订单失败" order_id=order_id exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
replace_order(ctx::TradeContext, order_id::String; quantity::Int=0, price::Float64=0.0)

修改订单
"""
function replace_order(ctx::TradeContext, order_id::String; quantity::Int=0, price::Float64=0.0)
    params = Dict{String, Any}("order_id" => order_id)
    quantity > 0 && (params["quantity"] = quantity)
    price > 0.0 && (params["price"] = string(price))
    
    try
        result = Client.post(ctx.config, "/v1/trade/order/replace", params)
        return haskey(result, "data") ? result.data : nothing
    catch e
        @error "修改订单失败" order_id=order_id exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
get_account_balance(ctx::TradeContext; currency::String="")

获取账户余额
"""
function get_account_balance(ctx::TradeContext; currency::String="")
    params = isempty(currency) ? Dict{String, String}() : Dict("currency" => currency)
    
    try
        result = Client.get(ctx.config, "/v1/trade/account/balance"; params=params)
        return haskey(result, "data") ? result.data : nothing
    catch e
        @error "获取账户余额失败" exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
get_cash_flow(ctx::TradeContext, start_time::String, end_time::String; page::Int=1, size::Int=50)

获取资金流水
"""
function get_cash_flow(ctx::TradeContext, start_time::String, end_time::String; page::Int=1, size::Int=50)
    params = Dict(
        "start_time" => start_time,
        "end_time" => end_time,
        "page" => string(page),
        "size" => string(size)
    )
    
    try
        result = Client.get(ctx.config, "/v1/trade/cash-flow"; params=params)
        return haskey(result, "data") ? result.data : nothing
    catch e
        @error "获取资金流水失败" exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
get_fund_positions(ctx::TradeContext; symbols::Vector{String}=String[])

获取基金持仓
"""
function get_fund_positions(ctx::TradeContext; symbols::Vector{String}=String[])
    params = isempty(symbols) ? Dict{String, String}() : Dict("symbols" => join(symbols, ","))
    
    try
        result = Client.get(ctx.config, "/v1/trade/fund-positions"; params=params)
        return haskey(result, "data") ? result.data : nothing
    catch e
        @error "获取基金持仓失败" exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
get_positions(ctx::TradeContext; symbols::Vector{String}=String[])

获取股票持仓
"""
function get_positions(ctx::TradeContext; symbols::Vector{String}=String[])
    params = isempty(symbols) ? Dict{String, String}() : Dict("symbols" => join(symbols, ","))
    
    try
        result = Client.get(ctx.config, "/v1/trade/stock-positions"; params=params)
        return haskey(result, "data") ? result.data : nothing
    catch e
        @error "获取股票持仓失败" exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
get_margin_ratio(ctx::TradeContext, symbol::String) 

获取保证金比例
"""
function get_margin_ratio(ctx::TradeContext, symbol::String)
    params = Dict("symbol" => symbol)
    
    try
        result = Client.get(ctx.config, "/v1/trade/margin-ratio"; params=params)
        return haskey(result, "data") ? result.data : nothing
    catch e
        @error "获取保证金比例失败" symbol=symbol exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
estimate_max_purchase_quantity(ctx::TradeContext, symbol::String, order_type, side::OrderSide; price::Float64=0.0)

估算最大可买数量
"""
function estimate_max_purchase_quantity(ctx::TradeContext, symbol::String, order_type, side::OrderSide; price::Float64=0.0)
    params = Dict{String, Any}(
        "symbol" => symbol,
        "order_type" => Int(order_type),
        "side" => Int(side)
    )
    price > 0.0 && (params["price"] = string(price))
    
    try
        result = Client.get(ctx.config, "/v1/trade/estimate-max-purchase-quantity"; params=params)
        return haskey(result, "data") ? result.data : nothing
    catch e
        @error "估算最大可买数量失败" symbol=symbol exception=(e, catch_backtrace())
        rethrow(e)
    end
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