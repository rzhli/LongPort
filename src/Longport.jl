module Longport

    using HTTP
    
    # 导入所有子模块
    include("Core/ControlPB.jl")
    include("Core/Constant.jl")
    include("Core/Region.jl") 
    include("Core/Config.jl")
    include("Rest/Client.jl")
    include("Rest/Auth.jl")
    include("Rest/API.jl")
    include("Core/Quotes.jl")
    include("Core/MarketData.jl")
    include("Core/Trading.jl")

    # 使用子模块
    using .Constant
    using .Region
    using .Config
    using .Client
    using .Auth
    using .ControlPB
    using .API
    using .Quotes
    using .MarketData
    using .Trading

    # 导出主要接口
    export 
        # Config
        APIConfig, from_toml, load_config, refresh_access_token!,
        
        # Client
        LongportClient, connect!, disconnect!, is_connected,
        
        # Auth
        get_otp, create_auth_request,
        
        # API
        get_request, post_request,
        
        # Quotes
        subscribe_quotes, unsubscribe_quotes, get_static_info,
        
        # MarketData - 新增的市场数据接口
        get_quote_candlestick, get_quote_history_candlestick_by_offset, 
        get_quote_history_candlestick_by_date, get_quote_intraday,
        get_quote_option_chain_expiry_date_list, get_quote_option_chain_info_by_date,
        get_quote_warrant_issuers, get_quote_warrant_list,
        get_quote_capital_flow_intraday, get_quote_capital_distribution,
        get_quote_calc_indexes, get_market_trading_session, get_market_trading_days,
        
        # Constants
        Language, PushCandlestickMode

    """
    LongportClient
        
    长桥 API 客户端，提供统一的接口访问 HTTP API 和 WebSocket 服务。

    # Fields
    - `config::APIConfig`: API 配置
    - `quote_ws::Union{Nothing, Client.WSClient}`: 行情 WebSocket 连接
    - `trade_ws::Union{Nothing, Client.WSClient}`: 交易 WebSocket 连接
    - `authenticated::Bool`: 认证状态
    - `callbacks::Dict{String, Function}`: 回调函数映射

    # Examples
    ```julia
    # 从配置文件创建客户端
    client = LongportClient("config.toml")

    # 连接并认证
    connect!(client)

    # 订阅行情
    subscribe_quotes(client, ["AAPL.US", "00700.HK"])

    # 获取股票静态信息
    info = get_static_info(client, ["AAPL.US"])

    # 断开连接
    disconnect!(client)
    ```
    """
    mutable struct LongportClient
        config::APIConfig
        quote_ws::Union{Nothing, Client.WSClient}
        trade_ws::Union{Nothing, Client.WSClient}
        authenticated::Bool
        callbacks::Dict{String, Function}
        
        function LongportClient(config::APIConfig)
            new(
                config,
                nothing,
                nothing,
                false,
                Dict{String, Function}()
            )
        end
    end

    """
    LongportClient(config_path::String)
        
    从配置文件路径创建客户端实例。
    """
    function LongportClient(config_path::String)
        config = load_config(config_path)
        return LongportClient(config)
    end

    """
    connect!(client::LongportClient; quote::Bool=true, trade::Bool=false)
        
    连接到长桥服务器并进行认证。

    # Arguments
    - `client::LongportClient`: 客户端实例
    - `quote::Bool=true`: 是否连接行情服务
    - `trade::Bool=false`: 是否连接交易服务
    """

    function connect!(client::LongportClient; Quote::Bool = true, trade::Bool = false)

        try
            
            if Quote && isnothing(client.quote_ws)
                @info "连接行情服务..."
                
                # 创建认证请求（自动获取OTP令牌）
                @info "正在认证行情服务..."
                auth_body = Auth.create_auth_request(client.config)
                
                # 连接时传递认证数据
                client.quote_ws = Client.connect(client.config.quote_ws, auth_body)
            end
            
            # 连接交易 WebSocket
            if trade && isnothing(client.trade_ws)
                @info "连接交易服务..."
                
                # 创建认证请求
                @info "正在认证交易服务..."
                auth_body = Auth.create_auth_request(client.config)
                
                # 连接时传递认证数据
                client.trade_ws = Client.connect(client.config.trade_ws, auth_body)
            end
            
            client.authenticated = true
            @info "长桥客户端连接成功"
        catch e
            @error "连接失败" exception=(e, catch_backtrace())
            rethrow(e)
        end
    end

    """
    disconnect!(client::LongportClient)
        
    断开所有连接。
    """
    function disconnect!(client::LongportClient)
        try
            if !isnothing(client.quote_ws)
                Client.disconnect!(client.quote_ws)
                client.quote_ws = nothing
                @info "行情服务已断开"
            end
            
            if !isnothing(client.trade_ws)
                Client.disconnect!(client.trade_ws)
                client.trade_ws = nothing
                @info "交易服务已断开"
            end
            
            client.authenticated = false
            @info "长桥客户端已断开连接"
            
        catch e
            @error "断开连接时发生错误" exception=(e, catch_backtrace())
        end
    end

    """
    is_connected(client::LongportClient) -> Bool
        
    检查客户端是否已连接并认证。
    """
    function is_connected(client::LongportClient)::Bool
        return client.authenticated
    end

    """
    set_callback!(client::LongportClient, event::String, callback::Function)
        
    设置事件回调函数。

    # Arguments
    - `client::LongportClient`: 客户端实例
    - `event::String`: 事件名称（如 "quote", "order_update" 等）
    - `callback::Function`: 回调函数
    """
    function set_callback!(client::LongportClient, event::String, callback::Function)
        client.callbacks[event] = callback
    end

    """
    get_request(client::LongportClient, path::String; params::Dict=Dict())
        
    发送 GET 请求。
    """
    function get_request(client::LongportClient, path::String; params::Dict = Dict())
        return API.get(path, params = params, config = client.config)
    end

    """
    post_request(client::LongportClient, path::String; body::String="", headers::Dict=Dict())
        
    发送 POST 请求。
    """
    function post_request(client::LongportClient, path::String; body::String="", headers::Dict=Dict())
        return API.post(path, body=body, headers=headers, config=client.config)
    end

    """
    subscribe_quotes(client::LongportClient, symbols::Vector{String})
        
    订阅股票行情。
    """
    function subscribe_quotes(client::LongportClient, symbols::Vector{String})
        if isnothing(client.quote_ws)
            throw(ArgumentError("行情服务未连接，请先调用 connect!(client, quote=true)"))
        end
        
        return Quotes.subscribe(client.quote_ws, symbols)
    end

    """
    unsubscribe_quotes(client::LongportClient, symbols::Vector{String})
        
    取消订阅股票行情。
    """
    function unsubscribe_quotes(client::LongportClient, symbols::Vector{String})
        if isnothing(client.quote_ws)
            throw(ArgumentError("行情服务未连接"))
        end
        
        return Quotes.unsubscribe(client.quote_ws, symbols)
    end

    """
    get_static_info(client::LongportClient, symbols::Vector{String})
        
    获取股票静态信息。
    """
    function get_static_info(client::LongportClient, symbols::Vector{String})
        params = Dict("symbols" => join(symbols, ","))
        return get_request(client, "/v1/quote/static", params = params)
    end

    # 新增的市场数据便利方法
    """
    get_candlestick(client::LongportClient, symbol::String, period::String; 
                   count::Int=1000, adjust_type::String="NONE")
        
    获取股票 K 线数据。
    """
    function get_candlestick(client::LongportClient, symbol::String, period::String; 
                           count::Int = 1000, adjust_type::String = "NONE")
        return MarketData.get_quote_candlestick(client.config, symbol, period; 
                                               count = count, adjust_type = adjust_type)
    end

    """
    get_history_candlestick_by_date(client::LongportClient, symbol::String, period::String,
                                   start_at::String, end_at::String; adjust_type::String="NONE")
        
    通过日期范围获取历史 K 线数据。
    """
    function get_history_candlestick_by_date(client::LongportClient, symbol::String, period::String,
                                            start_at::String, end_at::String; adjust_type::String = "NONE")
        return MarketData.get_quote_history_candlestick_by_date(client.config, symbol, period, 
                                                               start_at, end_at; adjust_type = adjust_type)
    end

    """
    get_intraday(client::LongportClient, symbol::String; count::Int=1000)
        
    获取股票当日分时数据。
    """
    function get_intraday(client::LongportClient, symbol::String; count::Int = 1000)
        return MarketData.get_quote_intraday(client.config, symbol; count = count)
    end

    """
    get_option_chain_dates(client::LongportClient, symbol::String)
        
    获取期权链到期日列表。
    """
    function get_option_chain_dates(client::LongportClient, symbol::String)
        return MarketData.get_quote_option_chain_expiry_date_list(client.config, symbol)
    end

    """
    get_warrant_list(client::LongportClient, symbol::String; kwargs...)
        
    获取窝轮筛选列表。
    """
    function get_warrant_list(client::LongportClient, symbol::String; kwargs...)
        return MarketData.get_quote_warrant_list(client.config, symbol; kwargs...)
    end

    """
    get_capital_flow(client::LongportClient, symbol::String)
        
    获取股票当日资金流向。
    """
    function get_capital_flow(client::LongportClient, symbol::String)
        return MarketData.get_quote_capital_flow_intraday(client.config, symbol)
    end

    """
    get_trading_session(client::LongportClient, market::String, date::String)
        
    获取市场交易时段。
    """
    function get_trading_session(client::LongportClient, market::String, date::String)
        return MarketData.get_market_trading_session(client.config, market, date)
    end

    """
    get_trading_days(client::LongportClient, market::String, start::String, end_::String)
        
    获取交易日历。
    """
    function get_trading_days(client::LongportClient, market::String, start::String, end_::String)
        return MarketData.get_market_trading_days(client.config, market, start, end_)
    end

    # 包的初始化函数
    function __init__()
        @info "Longport Julia SDK 已加载"
        @info "版本: $(Constant.DEFAULT_CLIENT_VERSION)"
    end

end # module Longport
