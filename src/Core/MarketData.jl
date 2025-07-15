module MarketData

using HTTP
using JSON3
using URIs
using SHA
using Dates

using ..Auth
using ..Config
using ..API

export get_quote_candlestick, get_quote_history_candlestick_by_offset, get_quote_history_candlestick_by_date,
       get_quote_intraday, get_quote_option_chain_expiry_date_list, get_quote_option_chain_info_by_date,
       get_quote_warrant_issuers, get_quote_warrant_list, get_quote_capital_flow_intraday,
       get_quote_capital_distribution, get_quote_calc_indexes, get_market_trading_session,
       get_market_trading_days

"""
get_quote_candlestick(config::APIConfig, symbol::String, period::String; 
                     count::Int=1000, adjust_type::String="NONE")
    
获取股票 K 线数据。

# Arguments
- `symbol::String`: 股票代码
- `period::String`: 时间周期 (1m, 5m, 15m, 30m, 1h, 4h, 1d, 1w, 1M)
- `count::Int`: 数据量 (最大 1000)
- `adjust_type::String`: 复权类型 ("NONE", "FORWARD", "BACKWARD")
"""
function get_quote_candlestick(config::APIConfig, symbol::String, period::String; 
                              count::Int = 1000, adjust_type::String = "NONE")
    params = Dict(
        "symbol" => symbol,
        "period" => period,
        "count" => string(count),
        "adjust_type" => adjust_type
    )
    return API.get("/v1/quote/candlestick"; params = params, config = config)
end

"""
get_quote_history_candlestick_by_offset(config::APIConfig, symbol::String, period::String; 
                                       count::Int=1000, offset::Int=0, adjust_type::String="NONE")
    
通过偏移量获取历史 K 线数据。
"""
function get_quote_history_candlestick_by_offset(config::APIConfig, symbol::String, period::String; 
                                                count::Int = 1000, offset::Int = 0, adjust_type::String = "NONE")
    params = Dict(
        "symbol" => symbol,
        "period" => period,
        "count" => string(count),
        "offset" => string(offset),
        "adjust_type" => adjust_type
    )
    return API.get("/v1/quote/history/candlestick"; params = params, config = config)
end

"""
get_quote_history_candlestick_by_date(config::APIConfig, symbol::String, period::String,
                                     start_at::String, end_at::String; adjust_type::String="NONE")
    
通过日期范围获取历史 K 线数据。

# Arguments
- `start_at::String`: 开始时间 (格式: "2023-01-01" 或 "2023-01-01 09:30:00")
- `end_at::String`: 结束时间
"""
function get_quote_history_candlestick_by_date(config::APIConfig, symbol::String, period::String,
                                              start_at::String, end_at::String; adjust_type::String = "NONE")
    params = Dict(
        "symbol" => symbol,
        "period" => period,
        "start_at" => start_at,
        "end_at" => end_at,
        "adjust_type" => adjust_type
    )
    return API.get("/v1/quote/history/candlestick"; params = params, config = config)
end

"""
get_quote_intraday(config::APIConfig, symbol::String; count::Int=1000)
    
获取股票当日分时数据。
"""
function get_quote_intraday(config::APIConfig, symbol::String; count::Int = 1000)
    params = Dict(
        "symbol" => symbol,
        "count" => string(count)
    )
    return API.get("/v1/quote/intraday"; params = params, config = config)
end

"""
get_quote_option_chain_expiry_date_list(config::APIConfig, symbol::String)
    
获取期权链到期日列表。
"""
function get_quote_option_chain_expiry_date_list(config::APIConfig, symbol::String)
    params = Dict("symbol" => symbol)
    return API.get("/v1/quote/option/chain/expiry-date"; params = params, config = config)
end

"""
get_quote_option_chain_info_by_date(config::APIConfig, symbol::String, expiry_date::String)
    
根据到期日获取期权链信息。
"""
function get_quote_option_chain_info_by_date(config::APIConfig, symbol::String, expiry_date::String)
    params = Dict(
        "symbol" => symbol,
        "expiry_date" => expiry_date
    )
    return API.get("/v1/quote/option/chain/info"; params = params, config = config)
end

"""
get_quote_warrant_issuers(config::APIConfig)
    
获取窝轮发行商列表。
"""
function get_quote_warrant_issuers(config::APIConfig)
    return API.get("/v1/quote/warrant/issuers"; config = config)
end

"""
get_quote_warrant_list(config::APIConfig, symbol::String; 
                      sort_by::String="LAST_DONE", sort_order::String="ASC", 
                      warrant_type::String="", issuer_id::Int=0, 
                      expiry_date_min::String="", expiry_date_max::String="",
                      street_min::String="", street_max::String="",
                      conversion_ratio_min::String="", conversion_ratio_max::String="",
                      type_::Vector{String}=String[], page::Int=1, size::Int=50)
    
获取窝轮筛选列表。
"""
function get_quote_warrant_list(config::APIConfig, symbol::String; 
                               sort_by::String = "LAST_DONE", sort_order::String = "ASC", 
                               warrant_type::String = "", issuer_id::Int = 0, 
                               expiry_date_min::String = "", expiry_date_max::String = "",
                               street_min::String = "", street_max::String = "",
                               conversion_ratio_min::String = "", conversion_ratio_max::String = "",
                               type_::Vector{String} = String[], page::Int = 1, size::Int = 50)
    params = Dict(
        "symbol" => symbol,
        "sort_by" => sort_by,
        "sort_order" => sort_order,
        "page" => string(page),
        "size" => string(size)
    )
    
    !isempty(warrant_type) && (params["warrant_type"] = warrant_type)
    issuer_id > 0 && (params["issuer_id"] = string(issuer_id))
    !isempty(expiry_date_min) && (params["expiry_date_min"] = expiry_date_min)
    !isempty(expiry_date_max) && (params["expiry_date_max"] = expiry_date_max)
    !isempty(street_min) && (params["street_min"] = street_min)
    !isempty(street_max) && (params["street_max"] = street_max)
    !isempty(conversion_ratio_min) && (params["conversion_ratio_min"] = conversion_ratio_min)
    !isempty(conversion_ratio_max) && (params["conversion_ratio_max"] = conversion_ratio_max)
    !isempty(type_) && (params["type"] = join(type_, ","))
    
    return API.get("/v1/quote/warrant/list"; params = params, config = config)
end

"""
get_quote_capital_flow_intraday(config::APIConfig, symbol::String)
    
获取股票当日资金流向。
"""
function get_quote_capital_flow_intraday(config::APIConfig, symbol::String)
    params = Dict("symbol" => symbol)
    return API.get("/v1/quote/capital-flow/intraday"; params = params, config = config)
end

"""
get_quote_capital_distribution(config::APIConfig, symbol::String)
    
获取股票资金分布。
"""
function get_quote_capital_distribution(config::APIConfig, symbol::String)
    params = Dict("symbol" => symbol)
    return API.get("/v1/quote/capital-distribution"; params = params, config = config)
end

"""
get_quote_calc_indexes(config::APIConfig, symbols::Vector{String}, indexes::Vector{String})
    
获取股票指标计算结果。

# Arguments
- `symbols::Vector{String}`: 股票代码列表
- `indexes::Vector{String}`: 指标名称列表 (如 ["last_done", "change_val", "change_rate"])
"""
function get_quote_calc_indexes(config::APIConfig, symbols::Vector{String}, indexes::Vector{String})
    params = Dict(
        "symbols" => join(symbols, ","),
        "indexes" => join(indexes, ",")
    )
    return API.get("/v1/quote/calc-index"; params = params, config = config)
end

"""
get_market_trading_session(config::APIConfig, market::String, date::String)
    
获取市场交易时段。

# Arguments
- `market::String`: 市场 ("US", "HK", "CN", "SG")
- `date::String`: 日期 (格式: "2023-01-01")
"""
function get_market_trading_session(config::APIConfig, market::String, date::String)
    params = Dict(
        "market" => market,
        "date" => date
    )
    return API.get("/v1/market/trading-session"; params = params, config = config)
end

"""
get_market_trading_days(config::APIConfig, market::String, start::String, end_::String)
    
获取交易日历。
"""
function get_market_trading_days(config::APIConfig, market::String, start::String, end_::String)
    params = Dict(
        "market" => market,
        "start" => start,
        "end" => end_
    )
    return API.get("/v1/market/trading-days"; params = params, config = config)
end

end # module