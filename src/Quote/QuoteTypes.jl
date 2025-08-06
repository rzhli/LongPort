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

export PushCandestickMode, Candlestick, SecurityQuote, Line, QuoteTrade,
       SubscriptionResponse, PushTrades,
       PushCandlestick, WarrantType, SortOrderType, WarrantSortBy, WarrantInfo,
       SecurityIntradayResponse,
       MarketTradingSession, MarketTradingDays, TradingSessionInfo,
       RealtimeQuote, OptionQuote,
       TradingHours, WarrantQuote, ParticipantInfo,
       OptionChainDateListResponse, Security

# Enums


struct Security
    symbol::String
    name_cn::String
    name_hk::String
    name_en::String
end

end # module QuoteTypes
