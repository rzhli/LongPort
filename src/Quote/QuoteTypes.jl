module QuoteTypes

"""
`Quote/Types.jl` 模块是行情数据类型定义中心

它的唯一职责是定义所有与公开市场行情数据相关的数据结构 (`struct`) 和枚举 (`enum`)
包括了从服务器获取的、所有用户都能看到的、匿名的市场信息，例如：

- __实时报价__: `SecurityQuote`, `RealtimeQuote`
- __K线图数据__: `Candlestick`
- __买卖盘深度__: `SecurityDepth`, `OrderBook`
- __逐笔成交__: `QuoteTrade`
- __证券静态信息__: `SecurityStaticInfo` (如股票名称、发行量等)
- __衍生品数据__: `WarrantInfo`, `OptionQuote`

简单来说，这个模块定义了构建行情展示界面（如K线图、报价列表、买卖五档）所需要的所有数据模型

"""

using Dates
using ProtoBuf.EnumX: @enumx
using ..QuoteProtocol: CandlePeriod, TradeSession, TradeStatus

export PushCandestickMode, Candlestick, SecurityQuote, IntradayLine, QuoteTrade,
       SecurityDepth, Brokers, Depth, OrderBook,
       SubscriptionResponse, PushDepth, PushBrokers, PushTrades,
       PushCandlestick, WarrantType, SortOrderType, WarrantSortBy, WarrantInfo,
       IssuerInfo, MarketTradingSession, MarketTradingDays, TradingSessionInfo,
       RealtimeQuote, OptionQuote, OptionChainDateStrikeInfo, StrikePriceInfo,
       IssuerInfoResponse, TradingHours, WarrantQuote, ParticipantInfo

# Enums

# SubType and AdjustType are now imported from QuoteProtocol to avoid conflicts

"""
Warrant type
"""
@enumx WarrantType begin
    UnknownWarrantType = 0
    Call = 1
    Put = 2
    Bull = 3
    Bear = 4
    Inline = 5
end

"""
Sort order type
"""
@enumx SortOrderType begin
    Ascending = 0
    Descending = 1
end

"""
Warrant sort by field
"""
@enumx WarrantSortBy begin
    LastDone = 0
    ChangeRate = 1
    ChangeValue = 2
    Volume = 3
    Turnover = 4
    ExpiryDate = 5
    StrikePrice = 6
    UpperStrikePrice = 7
    LowerStrikePrice = 8
    OutstandingQuantity = 9
    OutstandingRatio = 10
    Premium = 11
    ItmOtm = 12
    ImpliedVolatility = 13
    Delta = 14
    CallPrice = 15
    ToCallPrice = 16
    EffectiveLeverage = 17
    LeverageRatio = 18
    ConversionRatio = 19
    BalancePoint = 20
    Status = 21
end

# Data Structures

"""
Candlestick
"""
struct Candlestick
    symbol::String
    close::Float64
    open::Float64
    low::Float64
    high::Float64
    volume::Int64
    turnover::Float64
    timestamp::DateTime
end

"""
Realtime quote
"""
struct RealtimeQuote
    last_done::Float64
    timestamp::DateTime
    volume::Int64
    turnover::Float64
end

"""
Security quote information
"""
struct SecurityQuote
    symbol::String
    last_done::Union{Float64, Nothing}
    prev_close::Union{Float64, Nothing}
    open::Union{Float64, Nothing}
    high::Union{Float64, Nothing}
    low::Union{Float64, Nothing}
    timestamp::Union{DateTime, Nothing}
    volume::Union{Int64, Nothing}
    turnover::Union{Float64, Nothing}
    trade_status::TradeStatus.T
    pre_market_quote::Union{RealtimeQuote, Nothing}
    post_market_quote::Union{RealtimeQuote, Nothing}
    over_night_quote::Union{RealtimeQuote, Nothing}
end

"""
Intraday line
"""
struct IntradayLine
    price::Float64
    timestamp::DateTime
    volume::Int64
    turnover::Float64
    avg_price::Float64
end

"""
Quote Trade information
"""
struct QuoteTrade
    price::Float64
    volume::Int64
    timestamp::DateTime
    trade_type::String
    direction::Int32
    trade_session::TradeSession.T
end

"""
Depth information
"""
struct Depth
    position::Int32
    price::Float64
    volume::Int64
    order_num::Int32
end

"""
Security depth
"""
struct SecurityDepth
    asks::Vector{Depth}
    bids::Vector{Depth}
end

"""
Brokers information
"""
struct Brokers
    position::Int32
    broker_ids::Vector{Int32}
end

"""
Order book
"""
struct OrderBook
    symbol::String
    sequence::Int64
    asks::Vector{Depth}
    bids::Vector{Depth}
end

"""
Subscription response
"""
struct SubscriptionResponse
    sub_types::Vector{Int32}
    success::Vector{String}
    fail::Vector{String}
    current::Vector{String}
end


"""
Push depth
"""
struct PushDepth
    symbol::String
    sequence::Int64
    asks::Vector{Depth}
    bids::Vector{Depth}
end

"""
Push brokers
"""
struct PushBrokers
    symbol::String
    sequence::Int64
    ask_brokers::Vector{Brokers}
    bid_brokers::Vector{Brokers}
end

"""
Push trades
"""
struct PushTrades
    symbol::String
    sequence::Int64
    trades::Vector{QuoteTrade}
end

"""
Push candlestick
"""
struct PushCandlestick
    symbol::String
    period::CandlePeriod.T
    candlestick::Candlestick
end

"""
Warrant information
"""
struct WarrantInfo
    symbol::String
    name::String
    last_done::Float64
    change_rate::Float64
    change_value::Float64
    volume::Int64
    turnover::Float64
    expiry_date::Date
    strike_price::Union{Float64, Nothing}
    upper_strike_price::Union{Float64, Nothing}
    lower_strike_price::Union{Float64, Nothing}
    outstanding_quantity::Int64
    outstanding_ratio::Float64
    premium::Float64
    itm_otm::Float64
    implied_volatility::Union{Float64, Nothing}
    delta::Union{Float64, Nothing}
    call_price::Union{Float64, Nothing}
    to_call_price::Union{Float64, Nothing}
    effective_leverage::Union{Float64, Nothing}
    leverage_ratio::Float64
    conversion_ratio::Union{Float64, Nothing}
    balance_point::Union{Float64, Nothing}
    status::TradeStatus.T
end

"""
Issuer information
"""
struct IssuerInfo
    issuer_id::Int32
    name_cn::String
    name_en::String
    name_hk::String
end

"""
Trading session information
"""
struct TradingSessionInfo
    begin_time::Time
    end_time::Time
    trade_session::TradeSession.T
end

"""
Market trading session
"""
struct MarketTradingSession
    market::String
    trade_sessions::Vector{TradingSessionInfo}
end

"""
Market trading days
"""
struct MarketTradingDays
    trading_days::Vector{Date}
    half_trading_days::Vector{Date}
end

"""
Option quote
"""
struct OptionQuote
    symbol::String
    last_done::Union{Float64, Nothing}
    prev_close::Union{Float64, Nothing}
    open::Union{Float64, Nothing}
    high::Union{Float64, Nothing}
    low::Union{Float64, Nothing}
    timestamp::Union{DateTime, Nothing}
    volume::Union{Int64, Nothing}
    turnover::Union{Float64, Nothing}
    trade_status::TradeStatus.T
    implied_volatility::Union{Float64, Nothing}
    open_interest::Union{Int64, Nothing}
    expiry_date::Date
    strike_price::Float64
    contract_multiplier::Float64
    contract_type::String
    contract_size::Float64
    direction::String
    historical_volatility::Union{Float64, Nothing}
    underlying_symbol::String
end

"""
Strike price information
"""
struct StrikePriceInfo
    price::Float64
    call_symbol::String
    put_symbol::String
end

"""
Option chain date strike information
"""
struct OptionChainDateStrikeInfo
    expiry_date::Date
    strike_price_info::Vector{StrikePriceInfo}
end

"""
Issuer information response
"""
struct IssuerInfoResponse
    issuer_info::Vector{IssuerInfo}
end

"""
Trading hours
"""
struct TradingHours
    timezone::String
    trading_sessions::Vector{TradingSessionInfo}
end

"""
Warrant quote
"""
struct WarrantQuote
    symbol::String
    last_done::Union{Float64, Nothing}
    prev_close::Union{Float64, Nothing}
    open::Union{Float64, Nothing}
    high::Union{Float64, Nothing}
    low::Union{Float64, Nothing}
    timestamp::Union{DateTime, Nothing}
    volume::Union{Int64, Nothing}
    turnover::Union{Float64, Nothing}
    trade_status::TradeStatus.T
    implied_volatility::Union{Float64, Nothing}
    expiry_date::Date
    last_trade_date::Date
    outstanding_ratio::Float64
    outstanding_qty::Int64
    conversion_ratio::Float64
    category::String
    strike_price::Float64
    upper_strike_price::Float64
    lower_strike_price::Float64
    call_price::Float64
    underlying_symbol::String
end

"""
Participant information
"""
struct ParticipantInfo
    broker_ids::Vector{Int64}
    participant_name_cn::String
    participant_name_en::String
    participant_name_hk::String
end

end # module QuoteTypes
