# 参照Python SDK的QuoteContext实现
module Quote

using ProtoBuf, JSON3, Dates
using ..Config, ..QuoteTypes, ..Push, ..Client, ..QuoteProtocol
using ..QuoteProtocol: CandlePeriod, AdjustType, TradeSession
using ..Client: HttpClient, WSClient
using ..Constant: Language
using ..Cache: SimpleCache, CacheWithKey, get_or_update
using ..Utils: to_namedtuple

export QuoteContext, 
       connect!, disconnect!, get_quote, subscribe, unsubscribe, candlesticks, 
       set_on_quote, static_info, depth, brokers, trades,
       intraday, option_quote, warrant_quote, participants, subscriptions,
       member_id, Quote_level, realtime_quote, realtime_depth, realtime_brokers,
       realtime_trades, realtime_candlesticks

"""
# Examples
```julia
# 加载配置
config = Config.from_toml()

# 创建QuoteContext
ctx = QuoteContext(config)

# 获取基础信息
resp = get_quote(["700.HK", "AAPL.US", "TSLA.US"])
println(resp)

# 订阅行情
set_on_quote(on_quote)
subscribe(["700.HK"], [SubType.QUOTE], is_first_push=true)
```
"""
mutable struct QuoteContext
    config::Config.config
    callbacks::Push.Callbacks
    language::Language
    ws_client::Union{WSClient, Nothing}
    
    # 缓存
    cache_participants::SimpleCache{Vector{Any}}
    cache_issuers::SimpleCache{Vector{Any}}
    cache_option_chain_expiry_dates::CacheWithKey{String, Vector{String}}
    cache_option_chain_strike_info::CacheWithKey{String, Vector{Any}}
    cache_trading_sessions::SimpleCache{Vector{Any}}
    
    # 实时数据存储
    realtime_quotes::Dict{String, Any}
    realtime_depths::Dict{String, Any}
    realtime_trades::Dict{String, Vector{Any}}
    realtime_brokers::Dict{String, Any}
    realtime_candlesticks::Dict{String, Dict{String, Vector{Any}}}
    
    function QuoteContext(config::Config.config)
        new(
            config, 
            Push.Callbacks(),
            config.language,
            nothing,  # ws_client初始为空
            # 缓存 - 30分钟TTL
            SimpleCache{Vector{Any}}(30.0 * 60),
            SimpleCache{Vector{Any}}(30.0 * 60),
            CacheWithKey{String, Vector{String}}(30.0 * 60),
            CacheWithKey{String, Vector{Any}}(30.0 * 60),
            SimpleCache{Vector{Any}}(2.0 * 60 * 60), # 2小时TTL
            # 实时数据存储
            Dict{String, Any}(),
            Dict{String, Any}(),
            Dict{String, Vector{Any}}(),
            Dict{String, Any}(),
            Dict{String, Dict{String, Vector{Any}}}()
        )
    end
end

"""
Returns the language setting
"""
function get_language(ctx::QuoteContext)::Language
    return ctx.language
end

"""
Connect to WebSocket server
"""
function connect!(ctx::QuoteContext)
    if !isnothing(ctx.ws_client) && ctx.ws_client.connected
        return
    end
    
    # 创建并连接WSClient
    ctx.ws_client = WSClient(ctx.config.quote_ws_url)
    
    # 设置推送回调
    ctx.ws_client.on_push = (cmd, body) -> dispatch_push(ctx, cmd, body)

    # 创建认证请求
    ctx.ws_client.auth_data = Client.create_auth_request(ctx.config) 
    
    # 建立连接
    try
        Client.connect!(ctx.ws_client)
    catch e
        @error "行情服务器连接失败" exception=e
        ctx.ws_client = nothing
        rethrow(e)
    end
end

"""
Disconnect from WebSocket server
"""
function disconnect!(ctx::QuoteContext)
    if isnothing(ctx.ws_client)
        return
    end
    
    try
        Client.disconnect!(ctx.ws_client)
        @info "行情服务器已断开"
    catch e
        @warn "断开行情服务器时发生错误" exception=e
    end
    
    ctx.ws_client = nothing
end


"""
Returns the member ID
"""
function member_id(ctx::QuoteContext)
    # 这里需要实现具体的API调用
    throw(LongportException("member_id not yet implemented"))
end

"""
Returns the Quote level
"""
function Quote_level(ctx::QuoteContext)
    # 这里需要实现具体的API调用
    throw(LongportException("Quote_level not yet implemented"))
end

"""
Clear all caches
"""
function clear_caches!(ctx::QuoteContext)
    Cache.clear_cache!(ctx.cache_participants)
    Cache.clear_cache!(ctx.cache_issuers)
    Cache.clear_cache!(ctx.cache_option_chain_expiry_dates)
    Cache.clear_cache!(ctx.cache_option_chain_strike_info)
    Cache.clear_cache!(ctx.cache_trading_sessions)
    @info "所有缓存已清空"
end

"""
Clear realtime data storage
"""
function clear_realtime_data!(ctx::QuoteContext)
    empty!(ctx.realtime_quotes)
    empty!(ctx.realtime_depths)
    empty!(ctx.realtime_trades)
    empty!(ctx.realtime_brokers)
    empty!(ctx.realtime_candlesticks)
    @info "实时数据存储已清空"
end

"""
Set Quote callback, after receiving the Quote data push, it will call back to this function.
"""
function set_on_quote(ctx::QuoteContext, callback::Function)
    Push.set_on_quote!(ctx.callbacks, callback)
    @info "Quote回调函数已设置"
end

"""
Set depth callback, after receiving the depth data push, it will call back to this function.
"""
function set_on_depth(ctx::QuoteContext, callback::Function)
    Push.set_on_depth!(ctx.callbacks, callback)
    @info "depth回调函数已设置"
end

"""
Set brokers callback, after receiving the brokers data push, it will call back to this function.
"""
function set_on_brokers(ctx::QuoteContext, callback::Function)
    Push.set_on_brokers!(ctx.callbacks, callback)
    @info "brokers回调函数已设置"
end

"""
Set trades callback, after receiving the trades data push, it will call back to this function.
"""
function set_on_trades(ctx::QuoteContext, callback::Function)
    Push.set_on_trades!(ctx.callbacks, callback)
    @info "trades回调函数已设置"
end

"""
Set candlestick callback, after receiving the candlestick updated event, it will call back to this function.
"""
function set_on_candlestick(ctx::QuoteContext, callback::Function)
    Push.set_on_candlestick!(ctx.callbacks, callback)
    @info "candlestick回调函数已设置"
end

# 内部通用的请求函数
function serialize_request(ctx::QuoteContext, command_code::UInt8, request::T) where T
    # 序列化请求
    io_buf = IOBuffer()
    encoder = ProtoBuf.ProtoEncoder(io_buf)
    ProtoBuf.encode(encoder, request)
    request_body = take!(io_buf)

    # 发送WebSocket请求
    return ws_request(ctx.ws_client, command_code, request_body)
end


"""
Subscribe
"""
function subscribe(ctx::QuoteContext, symbols::Vector{String}, sub_types::Vector{SubType.T}; is_first_push::Bool=false)
    if isempty(symbols)
        throw(ArgumentError("Symbols list cannot be empty"))
    end
    
    connect!(ctx)
    
    try
        # 构建订阅请求消息
        request = QuoteSubscribeRequest(symbols, sub_types, is_first_push)
        
        # 发送WebSocket序列化请求
        serialize_request(ctx, UInt8(QuoteCommand.Subscribe), request)
        
        # @info "订阅请求成功" symbols=symbols sub_types=sub_types is_first_push=is_first_push
        return [(symbol = s, sub_types = sub_types) for s in symbols]
    catch e
        @error "订阅请求失败" symbols=symbols sub_types=sub_types exception=e
        rethrow(e)
    end
end

"""
Unsubscribe
"""
function unsubscribe(ctx::QuoteContext, symbols::Vector{String}, sub_types::Vector{SubType.T})
    if isempty(symbols)
        throw(ArgumentError("Symbols list cannot be empty"))
    end
    
    connect!(ctx)
    
    try
        # 构建取消订阅请求消息
        request = QuoteUnsubscribeRequest(symbols, sub_types, false)
        
        # 发送WebSocket序列化请求
        serialize_request(ctx, UInt8(QuoteCommand.Unsubscribe), request)
        
        # @info "取消订阅请求成功" symbols=symbols sub_types=sub_types
        return [(symbol = s, sub_types = sub_types) for s in symbols]
    catch e
        @error "取消订阅请求失败" symbols=symbols sub_types=sub_types exception=e
        rethrow(e)
    end
end

"""
Get subscription information
"""
function subscriptions(ctx::QuoteContext)
    # 这里需要实现具体的API调用
    throw(LongportException("subscriptions not yet implemented"))
end

"""
Get basic information of securities
"""
function static_info(ctx::QuoteContext, symbols::Vector{String})
    if isempty(symbols)
        throw(ArgumentError("Symbols list cannot be empty"))
    end
    
    try
        req = MultiSecurityRequest(symbols)
        response = request(ctx, UInt8(QuerySecurityStaticInfo), req, SecurityStaticInfoResponse)
        
        @info "static_info查询成功" symbols=symbols count=length(response.secu_static_info)
        return response.secu_static_info
        
    catch e
        @error "static_info API调用失败" symbols=symbols exception=e
        rethrow(e)
    end
end



"""
Get Quote of securities
"""
function get_quote(ctx::QuoteContext, symbols::Vector{String})
    if isempty(symbols)
        throw(ArgumentError("Symbols list cannot be empty"))
    end
    
    connect!(ctx)

    try
        req = MultiSecurityRequest(symbols)
        response_body = serialize_request(ctx, UInt8(QuoteCommand.QuerySecurityQuote), req)
        
        @info "收到响应数据" length=length(response_body) 
        # @show hex_bytes=bytes2hex(response_body)
        
        if length(response_body) == 0
            @warn "收到空响应"
            return NamedTuple[]
        end
        
        io = IOBuffer(response_body)
        decoder = ProtoBuf.ProtoDecoder(io)
        
        # @info "ProtoBuf解码开始" position=position(io)
        response = decode(decoder, SecurityQuoteResponse)
        # @info "Quote查询成功" symbols=symbols count=length(response.secu_quote)
        return to_namedtuple(response.secu_quote)
    catch e
        @error "Quote API调用失败" symbols=symbols exception=e
        rethrow(e)
    end
end

"""
Get Quote of option securities
"""
function option_quote(ctx::QuoteContext, symbols::Vector{String})
    if isempty(symbols)
        throw(ArgumentError("Symbols list cannot be empty"))
    end
    
    # 这里需要实现具体的API调用
    throw(LongportException("option_quote not yet implemented"))
end

"""
Get Quote of warrant securities
"""
function warrant_quote(ctx::QuoteContext, symbols::Vector{String})
    if isempty(symbols)
        throw(ArgumentError("Symbols list cannot be empty"))
    end
    
    # 这里需要实现具体的API调用
    throw(LongportException("warrant_quote not yet implemented"))
end

"""
Get security depth
"""
function depth(ctx::QuoteContext, symbol::String)
    try
        req = SecurityRequest(symbol)
        response = request(ctx, UInt8(QueryDepth), req, SecurityDepthResponse)
        
        @info "depth查询成功" symbol=symbol ask_count=length(response.ask) bid_count=length(response.bid)
        return response
        
    catch e
        @error "depth API调用失败" symbol=symbol exception=e
        rethrow(e)
    end
end

"""
Get security brokers
"""
function brokers(ctx::QuoteContext, symbol::String)
    # 创建HTTP客户端
    client = HttpClient(ctx.config)
    
    # 构建请求参数
    params = Dict(
        "symbol" => symbol
    )
    
    try
        # 调用API - 获取证券经纪商信息
        response = get("/v1/quote/brokers", params=params, headers=Dict{String,String}(), config=ctx.config)
        
        # 解析响应
        if haskey(response, "data")
            return response["data"]
        else
            return response
        end
    catch e
        @error "brokers API调用失败" symbol=symbol exception=e
        rethrow(e)
    end
end

"""
Get participants
"""
function participants(ctx::QuoteContext)
    # 这里需要实现具体的API调用
    throw(LongportException("participants not yet implemented"))
end

"""
Get security trades
"""
function trades(ctx::QuoteContext, symbol::String, count::Int)
    # 创建HTTP客户端
    client = HttpClient(ctx.config)
    
    # 构建请求参数
    params = Dict(
        "symbol" => symbol,
        "count" => string(count)
    )
    
    try
        # 调用API - 获取证券交易信息
        response = get("/v1/quote/trades", params=params, headers=Dict{String,String}(), config=ctx.config)
        
        # 解析响应
        if haskey(response, "data")
            return response["data"]
        else
            return response
        end
    catch e
        @error "trades API调用失败" symbol=symbol count=count exception=e
        rethrow(e)
    end
end

"""
Get security intraday
"""
function intraday(ctx::QuoteContext, symbol::String)
    # 创建HTTP客户端
    client = HttpClient(ctx.config)
    
    # 构建请求参数
    params = Dict(
        "symbol" => symbol
    )
    
    try
        # 调用API - 获取证券日内分时信息
        response = get("/v1/quote/intraday", params=params, headers=Dict{String,String}(), config=ctx.config)
        
        # 解析响应
        if haskey(response, "data")
            return response["data"]
        else
            return response
        end
    catch e
        @error "intraday API调用失败" symbol=symbol exception=e
        rethrow(e)
    end
end

"""
Get security candlesticks
"""
function candlesticks(
    ctx::QuoteContext, symbol::String, period::CandlePeriod.T, count::Int, adjust_type::AdjustType.T; 
    trade_sessions::TradeSession.T = TradeSession.Intraday, subscribe_realtimes::Bool = true
    )
    # 创建HTTP客户端
    client = HttpClient(ctx.config)
    
    # 构建请求参数
    params = Dict(
        "symbol" => symbol,
        "period" => string(period),
        "count" => string(count),
        "adjust_type" => string(adjust_type)
    )
    
    if trade_sessions != TradeSession.Intraday
        params["trade_sessions"] = string(trade_sessions)
    end
    
    try
        # 调用API - 获取证券K线
        response = Client.get("/v1/quote/candlesticks"; params=params, config=ctx.config)
        
        # 解析响应
        candlestick_data = if haskey(response, "data") && haskey(response["data"], "candlesticks")
            @info "Candlesticks查询成功" symbol=symbol count=length(response["data"]["candlesticks"])
            response["data"]["candlesticks"]
        else
            @error "Candlesticks查询失败或响应格式不正确" symbol=symbol response=response
            []
        end

        if subscribe_realtimes && !isempty(candlestick_data)
            @info "自动订阅实时行情以更新K线" symbol=symbol
            try
                subscribe(ctx, [symbol], [SubType.QUOTE, SubType.TRADE], is_first_push=true)
            catch e
                @warn "为K线自动订阅实时行情失败" symbol=symbol exception=e
            end
        end

        return to_namedtuple(candlestick_data)
    catch e
        @error "candlesticks API调用失败" symbol=symbol exception=e
        rethrow(e)
    end
end

"""
Get real-time Quote
"""
function realtime_quote(ctx::QuoteContext, symbols::Vector{String})
    if isempty(symbols)
        throw(ArgumentError("Symbols list cannot be empty"))
    end
    
    results = []
    for s in symbols
        if haskey(ctx.realtime_quotes, s)
            push!(results, ctx.realtime_quotes[s])
        end
    end
    return results
end

"""
Get real-time depth
"""
function realtime_depth(ctx::QuoteContext, symbol::String)
    return get(ctx.realtime_depths, symbol, nothing)
end

"""
Get real-time brokers
"""
function realtime_brokers(ctx::QuoteContext, symbol::String)
    return get(ctx.realtime_brokers, symbol, nothing)
end

"""
Get real-time trades
"""
function realtime_trades(ctx::QuoteContext, symbol::String; count::Int=500)
    trades = get(ctx.realtime_trades, symbol, [])
    
    if length(trades) > count
        return trades[1:count]
    else
        return trades
    end
end

"""
Get real-time candlesticks
"""
function realtime_candlesticks(ctx::QuoteContext, symbol::String, period::CandlePeriod.T; count::Int=500)
    # 这里需要实现具体的API调用
    throw(LongportException("realtime_candlesticks not yet implemented"))
end

"""
推送分派
"""
function dispatch_push(ctx::QuoteContext, cmd::UInt8, body::Vector{UInt8})
    command = QuoteCommand.T(cmd)
    io = IOBuffer(body)
    decoder = ProtoBuf.ProtoDecoder(io)

    callbacks = ctx.callbacks

    try
        if command == QuoteCommand.PushQuoteData
            data = decode(decoder, QuoteProtocol.PushQuote)
            ctx.realtime_quotes[data.symbol] = to_namedtuple(data)
            Push.handle_quote(callbacks, data.symbol, data)
        elseif command == QuoteCommand.PushDepthData
            data = decode(decoder, QuoteProtocol.PushDepth)
            ctx.realtime_depths[data.symbol] = to_namedtuple(data)
            Push.handle_depth(callbacks, data.symbol, data)
        elseif command == QuoteCommand.PushBrokersData
            data = decode(decoder, QuoteProtocol.PushBrokers)
            ctx.realtime_brokers[data.symbol] = to_namedtuple(data)
            Push.handle_brokers(callbacks, data.symbol, data)
        elseif command == QuoteCommand.PushTradeData
            data = decode(decoder, QuoteProtocol.PushTransaction)
            if !haskey(ctx.realtime_trades, data.symbol)
                ctx.realtime_trades[data.symbol] = []
            end
            
            for trade in data.transaction
                pushfirst!(ctx.realtime_trades[data.symbol], to_namedtuple(trade))
            end
            
            Push.handle_trades(callbacks, data.symbol, data)
        else
            @warn "Unknown push command" cmd=cmd
        end
    catch e
        @error "Failed to decode or dispatch push event" exception=(e, catch_backtrace())
    end
end

# 为QuoteContext添加方法调用的便利函数，类似Python对象方法
Base.getproperty(ctx::QuoteContext, name::Symbol) = begin
    if name == :Quote || name == :quote
        return (symbols::Vector{String}) -> get_quote(ctx, symbols)
    elseif name == :subscribe  
        return (symbols::Vector{String}, sub_types::Vector{SubType.T}; is_first_push::Bool=false) -> subscribe(ctx, symbols, sub_types; is_first_push=is_first_push)
    elseif name == :set_on_quote
        return (callback::Function) -> set_on_quote(ctx, callback)
    elseif name == :set_on_depth
        return (callback::Function) -> set_on_depth(ctx, callback)
    elseif name == :set_on_brokers
        return (callback::Function) -> set_on_brokers(ctx, callback)
    elseif name == :set_on_trades
        return (callback::Function) -> set_on_trades(ctx, callback)
    elseif name == :set_on_candlestick
        return (callback::Function) -> set_on_candlestick(ctx, callback)
    elseif name == :static_info
        return (symbols::Vector{String}) -> static_info(ctx, symbols)
    elseif name == :depth
        return (symbol::String) -> depth(ctx, symbol)
    elseif name == :brokers
        return (symbol::String) -> brokers(ctx, symbol)
    elseif name == :trades
        return (symbol::String, count::Int) -> trades(ctx, symbol, count)
    elseif name == :intraday
        return (symbol::String) -> intraday(ctx, symbol)
    elseif name == :candlesticks
        return (symbol::String, period::CandlePeriod.T, count::Int, adjust_type::AdjustType.T; 
        trade_sessions::TradeSession.T = TradeSession.Intraday) -> candlesticks(ctx, symbol, 
        period, count, adjust_type; trade_sessions=trade_sessions)
    elseif name == :realtime_quote
        return (symbols::Vector{String}) -> realtime_quote(ctx, symbols)
    elseif name == :realtime_depth
        return (symbol::String) -> realtime_depth(ctx, symbol)
    elseif name == :realtime_brokers
        return (symbol::String) -> realtime_brokers(ctx, symbol)
    elseif name == :realtime_trades
        return (symbol::String; count::Int=500) -> realtime_trades(ctx, symbol; count=count)
    elseif name == :realtime_candlesticks
        return (symbol::String, period::CandlePeriod.T; count::Int=500) -> realtime_candlesticks(ctx, symbol, period; count=count)
    else
        return getfield(ctx, name)
    end
end

end # module Quote
