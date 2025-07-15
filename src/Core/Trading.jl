module Trading

using HTTP
using JSON3
using URIs
using Dates

using ..Auth
using ..Config
using ..API

export submit_order, cancel_order, modify_order, get_account_balance, 
       get_positions, get_order_history, get_today_orders, get_order_detail

"""
submit_order(config::APIConfig, symbol::String, order_type::String, side::String, 
            submitted_quantity::Int; submitted_price::Union{Float64, Nothing}=nothing,
            time_in_force::String="DAY", remark::String="")

提交订单。

# Arguments
- `symbol::String`: 股票代码
- `order_type::String`: 订单类型 ("MO"=市价单, "LO"=限价单, "LIT"=增强限价单等)
- `side::String`: 买卖方向 ("Buy", "Sell")
- `submitted_quantity::Int`: 委托数量
- `submitted_price::Union{Float64, Nothing}`: 委托价格（市价单可为 nothing）
- `time_in_force::String`: 订单有效期 ("DAY", "GTC", "IOC", "FOK")
- `remark::String`: 订单备注
"""
function submit_order(config::APIConfig, symbol::String, order_type::String, side::String, 
                     submitted_quantity::Int; submitted_price::Union{Float64, Nothing} = nothing,
                     time_in_force::String = "DAY", remark::String = "")
    
    body_data = Dict(
        "symbol" => symbol,
        "order_type" => order_type,
        "side" => side,
        "submitted_quantity" => string(submitted_quantity),
        "time_in_force" => time_in_force
    )
    
    # 添加价格（如果不是市价单）
    if !isnothing(submitted_price)
        body_data["submitted_price"] = string(submitted_price)
    end
    
    # 添加备注
    if !isempty(remark)
        body_data["remark"] = remark
    end
    
    body_json = JSON3.write(body_data)
    return API.post("/v1/trade/order"; body = body_json, config = config)
end

"""
cancel_order(config::APIConfig, order_id::String)

取消订单。
"""
function cancel_order(config::APIConfig, order_id::String)
    body_data = Dict("order_id" => order_id)
    body_json = JSON3.write(body_data)
    return API.post("/v1/trade/order/cancel"; body = body_json, config = config)
end

"""
modify_order(config::APIConfig, order_id::String; 
            submitted_quantity::Union{Int, Nothing}=nothing,
            submitted_price::Union{Float64, Nothing}=nothing,
            trigger_price::Union{Float64, Nothing}=nothing)

修改订单。
"""
function modify_order(config::APIConfig, order_id::String; 
                     submitted_quantity::Union{Int, Nothing} = nothing,
                     submitted_price::Union{Float64, Nothing} = nothing,
                     trigger_price::Union{Float64, Nothing} = nothing)
    
    body_data = Dict("order_id" => order_id)
    
    # 添加要修改的字段
    if !isnothing(submitted_quantity)
        body_data["submitted_quantity"] = string(submitted_quantity)
    end
    
    if !isnothing(submitted_price)
        body_data["submitted_price"] = string(submitted_price)
    end
    
    if !isnothing(trigger_price)
        body_data["trigger_price"] = string(trigger_price)
    end
    
    body_json = JSON3.write(body_data)
    return API.post("/v1/trade/order/replace"; body = body_json, config = config)
end

"""
get_account_balance(config::APIConfig; currency::String="")

获取账户余额。

# Arguments
- `currency::String`: 货币代码（空字符串表示获取所有货币）
"""
function get_account_balance(config::APIConfig; currency::String = "")
    params = Dict{String, String}()
    
    if !isempty(currency)
        params["currency"] = currency
    end
    
    return API.get("/v1/asset/account"; params = params, config = config)
end

"""
get_positions(config::APIConfig; symbol::String="")

获取持仓信息。

# Arguments
- `symbol::String`: 股票代码（空字符串表示获取所有持仓）
"""
function get_positions(config::APIConfig; symbol::String = "")
    params = Dict{String, String}()
    
    if !isempty(symbol)
        params["symbol"] = symbol
    end
    
    return API.get("/v1/asset/stock"; params = params, config = config)
end

"""
get_order_history(config::APIConfig; symbol::String="", status::Vector{String}=String[],
                 side::String="", market::String="", start_at::String="", 
                 end_at::String="", page::Int=1, size::Int=50)

获取历史订单。
"""
function get_order_history(config::APIConfig; symbol::String = "", status::Vector{String} = String[],
                          side::String = "", market::String = "", start_at::String = "", 
                          end_at::String = "", page::Int = 1, size::Int = 50)
    params = Dict(
        "page" => string(page),
        "size" => string(size)
    )
    
    # 添加可选参数
    !isempty(symbol) && (params["symbol"] = symbol)
    !isempty(status) && (params["status"] = join(status, ","))
    !isempty(side) && (params["side"] = side)
    !isempty(market) && (params["market"] = market)
    !isempty(start_at) && (params["start_at"] = start_at)
    !isempty(end_at) && (params["end_at"] = end_at)
    
    return API.get("/v1/trade/order/history"; params = params, config = config)
end

"""
get_today_orders(config::APIConfig; symbol::String="", status::Vector{String}=String[],
                side::String="", market::String="", page::Int=1, size::Int=50)

获取当日订单。
"""
function get_today_orders(config::APIConfig; symbol::String = "", status::Vector{String} = String[],
                         side::String = "", market::String = "", page::Int = 1, size::Int = 50)
    params = Dict(
        "page" => string(page),
        "size" => string(size)
    )
    
    # 添加可选参数
    !isempty(symbol) && (params["symbol"] = symbol)
    !isempty(status) && (params["status"] = join(status, ","))
    !isempty(side) && (params["side"] = side)
    !isempty(market) && (params["market"] = market)
    
    return API.get("/v1/trade/order/today"; params = params, config = config)
end

"""
get_order_detail(config::APIConfig, order_id::String)

获取订单详情。
"""
function get_order_detail(config::APIConfig, order_id::String)
    params = Dict("order_id" => order_id)
    return API.get("/v1/trade/order"; params = params, config = config)
end

"""
get_order_fills(config::APIConfig, order_id::String)

获取订单成交明细。
"""
function get_order_fills(config::APIConfig, order_id::String)
    params = Dict("order_id" => order_id)
    return API.get("/v1/trade/execution"; params = params, config = config)
end

"""
get_cash_flow(config::APIConfig; start_at::String="", end_at::String="", 
             business_type::String="", symbol::String="", page::Int=1, size::Int=50)

获取资金流水。
"""
function get_cash_flow(config::APIConfig; start_at::String = "", end_at::String = "", 
                      business_type::String = "", symbol::String = "", page::Int = 1, size::Int = 50)
    params = Dict(
        "page" => string(page),
        "size" => string(size)
    )
    
    # 添加可选参数
    !isempty(start_at) && (params["start_at"] = start_at)
    !isempty(end_at) && (params["end_at"] = end_at)
    !isempty(business_type) && (params["business_type"] = business_type)
    !isempty(symbol) && (params["symbol"] = symbol)
    
    return API.get("/v1/asset/cashflow"; params = params, config = config)
end

"""
get_fund_positions(config::APIConfig; symbol::String="")

获取基金持仓。
"""
function get_fund_positions(config::APIConfig; symbol::String = "")
    params = Dict{String, String}()
    
    if !isempty(symbol)
        params["symbol"] = symbol
    end
    
    return API.get("/v1/asset/fund"; params = params, config = config)
end

"""
get_stock_positions(config::APIConfig; symbol::String="")

获取股票持仓（详细版本）。
"""
function get_stock_positions(config::APIConfig; symbol::String = "")
    params = Dict{String, String}()
    
    if !isempty(symbol)
        params["symbol"] = symbol
    end
    
    return API.get("/v1/asset/stock"; params = params, config = config)
end

"""
get_margin_ratio(config::APIConfig, symbol::String)

获取保证金比例。
"""
function get_margin_ratio(config::APIConfig, symbol::String)
    params = Dict("symbol" => symbol)
    return API.get("/v1/risk/margin-ratio"; params = params, config = config)
end

"""
OrderSide

订单买卖方向枚举。
"""
module OrderSide
    const BUY = "Buy"
    const SELL = "Sell"
end

"""
OrderType

订单类型枚举。
"""
module OrderType
    const MARKET = "MO"           # 市价单
    const LIMIT = "LO"            # 限价单
    const ENHANCED_LIMIT = "LIT"  # 增强限价单
    const AT_AUCTION_LIMIT = "AL" # 竞价限价单
    const AT_AUCTION = "AO"       # 竞价单
    const ODD_LOTS = "OL"         # 碎股单
    const STOP_LOSS = "SL"        # 止损单
    const STOP_LIMIT = "SLO"      # 止损限价单
    const SPECIAL_LIMIT = "SLT"   # 特别限价单
end

"""
TimeInForce

订单有效期枚举。
"""
module TimeInForce
    const DAY = "DAY"             # 当日有效
    const GOOD_TILL_CANCELED = "GTC"  # 撤销前有效
    const IMMEDIATE_OR_CANCEL = "IOC"  # 立即成交或撤销
    const FILL_OR_KILL = "FOK"         # 全部成交或撤销
end

"""
OrderStatus

订单状态枚举。
"""
module OrderStatus
    const UNKNOWN = "Unknown"
    const NEW = "New"
    const PARTIAL_FILLED = "PartialFilled"
    const FILLED = "Filled"
    const CANCELED = "Canceled"
    const REJECTED = "Rejected"
    const PARTIAL_WITHDRAWAL = "PartialWithdrawal"
end

end # module