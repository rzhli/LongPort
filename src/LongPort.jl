module LongPort

    using TOML, Dates
    # Core Modules
    include("Core/Constant.jl")
    include("Core/Errors.jl")
    include("Core/QuoteProtocol.jl")
    include("Core/ControlProtocol.jl")
    include("Config.jl")
    include("Core/Utils.jl")
    include("Core/Cache.jl")
    include("Client.jl")

    include("Quote/Push.jl")
    include("Quote/Quote.jl")
    include("Trade/Types.jl")
    include("Trade/Trade.jl")

    using .Constant: Market 
    using .QuoteProtocol
    using .ControlProtocol
    using .Cache
    using .Config
    using .Errors
    using .Client
    using .Trade
    using .Push
    using .Quote
    
            # Config 模块    Constant 模块    
    export config, from_toml, Market, 
           # QuoteProtocol模块
           QuoteContext, PushQuote, PushDepth, PushBrokers, PushTrade,                     # 结构体类型Struct
           SubType, CandlePeriod, AdjustType, Direction, WarrantSortBy, SortOrderType,     # 枚举类型Enums
           TradeSession, Granularity, SecuritiesUpdateMode, SecurityListCategory,

           # Quote 模块
           try_new, disconnect!, realtime_quote, subscribe, unsubscribe, 
           static_info, depth, brokers, trades, candlesticks,                       # 函数
           history_candlesticks_by_offset, history_candlesticks_by_date,
           option_chain_expiry_date_list, option_chain_info_by_date,
           warrant_list, trading_session, trading_days, 
           set_on_quote, set_on_depth, set_on_brokers, set_on_trades, set_on_candlestick,
           
           intraday, option_quote, warrant_quote, participants, subscriptions,
           option_chain_dates, option_chain_strikes, warrant_issuers, warrant_filter,
           capital_flow, capital_distribution, calc_indexes, market_temperature,
           history_market_temperature, member_id, quote_level,
           watchlist, create_watchlist_group, delete_watchlist_group, update_watchlist_group,  # 自选股
           security_list,

           # Trade module
           TradeContext,
           # Assuming function names from a typical trade API, might need adjustment
           submit_order, cancel_order, get_orders, get_positions, get_account_balance
    const VERSION = TOML.parsefile(joinpath(pkgdir(@__MODULE__), "Project.toml"))["version"]

    function __init__()
        @info "LongPort Julia SDK loaded (v$VERSION)"
    end
end # module LongPort
