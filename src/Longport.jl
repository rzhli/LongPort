module Longport

    using TOML
    # Core Modules
    include("Core/Constant.jl")
    include("Core/QuoteProtocol.jl")
    include("Core/ControlProtocol.jl")
    include("Config.jl")
    include("Core/Errors.jl")
    include("Core/Utils.jl")
    include("Core/Cache.jl")
    include("Client.jl")


    include("Quote/QuoteTypes.jl")

    include("Quote/Push.jl")
    include("Quote/Quote.jl")
    include("Trade/Types.jl")
    include("Trade/Trade.jl")

    using .Constant
    using .QuoteProtocol
    using .ControlProtocol
    using .Cache
    using .Config
    using .Errors
    using .Client
    using .Trade
    using .QuoteTypes
    using .Push
    using .Quote
    
            # Config 模块
    export Config, from_toml,

            # QuoteProtocol模块
           QuoteContext, PushQuote,                                   # 结构体类型Struct
           SubType,                                                 # 枚举类型Enums
           try_new, disconnect!, realtime_quote, subscribe, unsubscribe, candlesticks,      # 函数
            
           set_on_quote, set_on_depth, set_on_brokers, set_on_trades, set_on_candlestick,
           static_info, depth, brokers, trades,
           intraday, option_quote, warrant_quote, participants, subscriptions,
           option_chain_dates, option_chain_strikes, warrant_issuers, warrant_filter,
           trading_sessions, trading_days, capital_flow_intraday, capital_flow_distribution,
           calc_indexes, member_id, quote_level

           # Trade module
           TradeContext,
           # Assuming function names from a typical trade API, might need adjustment
           submit_order, cancel_order, get_orders, get_positions, get_account_balance


    const VERSION = TOML.parsefile(joinpath(pkgdir(@__MODULE__), "Project.toml"))["version"]

    function __init__()
        @info "Longport Julia SDK loaded (v$VERSION)"
    end
end # module Longport
