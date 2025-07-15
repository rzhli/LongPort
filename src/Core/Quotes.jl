module Quotes
    
    using ..Config, ..API, ..Auth
    using JSON3
    export QuoteContext, quotes, SecurityQuote, subscribe, unsubscribe

    struct SecurityQuote
        symbol::String
        last_done::Float64
        prev_close::Float64
        open::Float64
        high::Float64
        low::Float64
        volume::Int64
        turnover::Float64
        timestamp::String
    end

    # Struct to hold callbacks
    mutable struct Callbacks
        get_quotes::Union{Function, Nothing}
        depth::Union{Function, Nothing}
        brokers::Union{Function, Nothing}
        trades::Union{Function, Nothing}
        candlestick::Union{Function, Nothing}

        Callbacks() = new(nothing, nothing, nothing, nothing, nothing)
    end
    
    mutable struct QuoteContext
        config::Config.APIConfig
        callbacks::Callbacks
        # Add WebSocket connection if needed
        # ws::Union{WebSocket.Connection, Nothing}
    end

    # Constructor
    function QuoteContext(config::Config.APIConfig)
        callbacks = Callbacks()
        return QuoteContext(config, callbacks)
    end
    
    """
        quotes(symbols::Vector{String})::Vector{SecurityQuote}
        向 `/v1/quote/quote` 发起 POST 请求，获取指定证券的实时报价。
    """
    function quotes(ctx::QuoteContext, symbols::Vector{String})::Vector{SecurityQuote}

        if isempty(symbols)
            error("Symbols list cannot be empty")
        end

        # Prepare the API request
        path = "/v1/quote/quote"
        # Construct headers within Quotes module
        headers = Dict(
            "X-Timestamp" => string(time()),
            "Authorization" => "Bearer $(ctx.config.access_token)",
            "Content-Type" => "application/json"
        )
     
        body = JSON3.write(Dict("symbols" => symbols))

        data = API.post(path, headers = headers, body = body, config = ctx.config)
        if data === nothing || !haskey(data, :quotes)
            error("Invalid response or missing 'quotes' field.")
        end
        # Convert response to SecurityQuote structs
        quotes = SecurityQuote[]
        for item in data.quotes
            result = SecurityQuote(
                get(item, :symbol, ""),
                get(item, :last_done, 0.0),
                get(item, :prev_close, 0.0),
                get(item, :open, 0.0),
                get(item, :high, 0.0),
                get(item, :low, 0.0),
                get(item, :volume, 0),
                get(item, :turnover, 0.0),
                get(item, :timestamp, "")
            )
            push!(quotes, result)
        end

        return quotes

    end

    """
    subscribe(ws_client, symbols::Vector{String})
        
    通过WebSocket订阅股票行情。
    """
    function subscribe(ws_client, symbols::Vector{String})
        if isempty(symbols)
            throw(ArgumentError("Symbols list cannot be empty"))
        end
        
        # 构建订阅消息
        # 根据Longport协议，这里需要发送订阅请求
        # 暂时返回成功消息，具体实现需要根据协议文档
        @info "订阅行情: $(join(symbols, ", "))"
        
        # TODO: 实现真正的WebSocket订阅逻辑
        # 这里应该构建订阅的protobuf消息并通过WebSocket发送
        
        return true
    end

    """
    unsubscribe(ws_client, symbols::Vector{String})
        
    取消订阅股票行情。
    """
    function unsubscribe(ws_client, symbols::Vector{String})
        if isempty(symbols)
            throw(ArgumentError("Symbols list cannot be empty"))
        end
        
        @info "取消订阅行情: $(join(symbols, ", "))"
        
        # TODO: 实现真正的WebSocket取消订阅逻辑
        
        return true
    end

end # module Quotes