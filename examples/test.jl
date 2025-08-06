"""
LongPort Julia SDK - Test Script
(Tests functions individually using the new Actor-based API)
"""

using LongPort, Dates
# Load config from TOML file
cfg = from_toml()
# Asynchronously create and connect the QuoteContext
ctx, channel = try_new(cfg)

# 行情
## 拉取  每次请求支持传入的标的数量上限是 500 个
### 获取标的基础信息 （DataFrame） 后面三个的 board = ""
resp = static_info(ctx, ["700.HK", "AAPL.US", "TSLA.US", "NFLX.US"])

### 获取股票实时行情 （DataFrame） （over_night_quote需开通美股LV1实时行情）
quotes = realtime_quote(ctx, ["GOOGL.US", "AAPL.US", "TSLA.US", "NFLX.US"])

### 获取期权实时行情 （需开通OPRA美股期权行情）
resp = option_quote(ctx, ["AAPL230317P160000.US"])

### 获取轮证实时行情 （DataFrame）
resp = warrant_quote(ctx, ["14993.HK", "66642.HK"])

### 获取标的盘口    （DataFrame）
depth_df = depth(ctx, "700.HK")

### 获取标的经纪队列 （返回空值, 盘中再测试）
resp = brokers(ctx, "700.HK")

### 获取券商席位 ID   （DataFrame）
resp = participants(ctx)

### 获取标的成交明细    (DataFrame)
resp = trades(ctx, "700.HK", 500)

### 获取标的当日分时（DataFrame格式）
resp = intraday(ctx, "700.HK")

# 获取标的历史K线（DataFrame格式）
using Dates
# after 2023-01-01
history_offset_data = history_candlesticks_by_offset(
    ctx, "700.HK", CandlePeriod.DAY, AdjustType.NO_ADJUST, Direction.FORWARD, 10; date=DateTime(2023, 1, 1)
)
# before 2023-01-01
history_offset_data = history_candlesticks_by_offset(
    ctx, "700.HK", CandlePeriod.FOUR_HOUR, AdjustType.NO_ADJUST, Direction.BACKWARD, 10; date = DateTime(2024, 1, 1)
)
# 2023-01-01 to 2023-02-01
history_date_data = history_candlesticks_by_date(
    ctx, "700.HK", CandlePeriod.TWENTY_MINUTE, AdjustType.NO_ADJUST; start_date=Date(2023, 5, 1), end_date=Date(2023, 12, 1)
)

### 获取标的的期权链到期日列表
expiry_date = option_chain_expiry_date_list(ctx, "AAPL.US")

### 获取标的的期权链到期日期权标的列表 (返回空值，需开通OPRA美股期权行情权限？)
info = option_chain_info_by_date(ctx, "AAPL.US", Date(2025-08-22))

### 获取轮证发行商ID （DataFrame）
resp = warrant_issuers(ctx)

### 获取轮证筛选列表  (DataFrame)
data, count = warrant_list(ctx, "700.HK", WarrantSortBy.LastDone, SortOrderType.Descending)

### 获取各市场当日交易时段  （DataFrame）
resp = trading_session(ctx)

### 获取市场交易日  （DataFrame）
resp = trading_days(ctx, Market.CN, Date(2025, 8, 1), Date(2025, 8, 30))

### 获取标的当日资金流向  (DataFrame)
resp = capital_flow(ctx, "700.HK")

### 获取标的当日资金分布  (DataFrame)
resp = capital_distribution(ctx, "700.HK")

### 获取标的计算指标    (DataFrame)
resp = calc_indexes(ctx, ["700.HK", "AAPL.US"])

#=
@enumx CandlePeriod begin
    UNKNOWN_PERIOD = 0
    ONE_MINUTE = 1
    TWO_MINUTE = 2
    THREE_MINUTE = 3
    FIVE_MINUTE = 5
    TEN_MINUTE = 10
    FIFTEEN_MINUTE = 15
    TWENTY_MINUTE = 20
    THIRTY_MINUTE = 30
    FORTY_FIVE_MINUTE = 45
    SIXTY_MINUTE = 60
    TWO_HOUR = 120
    THREE_HOUR = 180
    FOUR_HOUR = 240
    DAY = 1000
    WEEK = 2000
    MONTH = 3000
    QUARTER = 3500
    YEAR = 4000
end
=#

### 获取标的K线     （DataFrame）
# 获取 700.HK 的盘中 K 线
candlesticks_data = candlesticks(ctx, "700.HK", CandlePeriod.SIXTY_MINUTE, 365; adjust_type = AdjustType.NO_ADJUST)
# 获取 700.HK 的所有 K 线  （TradeSession.All数字代码未知）
candlesticks_data = candlesticks(ctx, "700.HK", CandlePeriod.DAY, 100; trade_sessions = TradeSession.All)
candlesticks_data = candlesticks(ctx, "700.HK", CandlePeriod.DAY, 100; trade_sessions = TradeSession.Intraday)

### 当前市场温度
resp = market_temperature(ctx, Market.CN)

### 获取历史市场温度（只有日数据，没有周，月数据）
type, list = history_market_temperature(ctx, Market.US, Date(2024, 1, 1), Date(2025, 2, 1))




# 订阅

# 1. Define your callback functions
function on_quote_callback(symbol::String, event::PushQuote)
    china_time = unix2datetime(event.timestamp) + Hour(8)  # Convert UTC to China time (UTC+8)
    println("Quote: $symbol \n Last: $(event.last_done) Volume: $(event.volume) Turnover: $(event.turnover) Timestamp: $(china_time)")
end

function on_depth_callback(symbol::String, event::PushDepth)
    println("Depth: $symbol")
    for ask in event.ask
        println("  Ask: Position = $(ask.position), Price = $(ask.price), Volume = $(ask.volume), Orders = $(ask.order_num)")
    end
    for bid in event.bid
        println("  Bid: Position = $(bid.position), Price = $(bid.price), Volume = $(bid.volume), Orders = $(bid.order_num)")
    end
end

# 2. Set the callbacks
set_on_quote(ctx, on_quote_callback)
set_on_depth(ctx, on_depth_callback)

#= 3. Subscribe 行情订阅类型
@enumx SubType begin
    UNKNOWN_TYPE = 0
    QUOTE = 1
    DEPTH = 2
    BROKERS = 3
    TRADE = 4
end
=#

### 订阅行情数据  实时价格推送，实时盘口推送
subscribe(ctx, ["700.HK"], [SubType.QUOTE, SubType.DEPTH]; is_first_push=true)
### 取消订阅
unsubscribe(ctx, ["700.HK"], [SubType.QUOTE, SubType.DEPTH])

subscribe(ctx, ["601816.SH"], [SubType.QUOTE, SubType.DEPTH]; is_first_push=true)
unsubscribe(ctx, ["601816.SH"], [SubType.QUOTE, SubType.DEPTH])

### 获取当前订阅及订阅类型
subs = subscriptions(ctx)

ctx, channel = try_new(cfg)
### 实时经纪队列推送
function on_brokers_callback(symbol::String, event::PushBrokers)
    println("Brokers: $symbol")
    for ask in event.ask_brokers
        println("  Ask: Position = $(ask.position), BrokerIDs = $(ask.broker_ids)")
    end
    for bid in event.bid_brokers
        println("  Bid: Position = $(bid.position), BrokerIDs = $(bid.broker_ids)")
    end
end
set_on_brokers(ctx, on_brokers_callback)

subscribe(ctx, ["700.HK"], [SubType.BROKERS]; is_first_push=true)
unsubscribe(ctx, ["700.HK"], [SubType.BROKERS])

### 实时成交明细推送
function on_trades_callback(symbol::String, event::PushTrade)
    println("Trades: $symbol")
    for t in event.trade
        println("  Price: $(t.price), Volume: $(t.volume), Tradetype: $(t.trade_type), Direction: $(t.direction), Tradesession: $(t.trade_session)")
    end
end
set_on_trades(ctx, on_trades_callback)
subscribe(ctx, ["700.HK"], [SubType.TRADE]; is_first_push = true)
unsubscribe(ctx, ["700.HK"], [SubType.TRADE])

### 创建自选股分组
group_id = create_watchlist_group(ctx, "Watchlist1", securities = ["700.HK", "AAPL.US"])

### 查看自选股分组
resp = watchlist(ctx)

### 删除自选股
message = delete_watchlist_group(ctx, 3542782, true)

### 更新自选股
update_watchlist_group(ctx, 10086, name = "WatchList2", securities = ["700.HK", "AAPL.US"], mode = SecuritiesUpdateMode.Add)

### 获取标的列表（只有中文名称name_cn）
resp = security_list(ctx, Market.US, SecurityListCategory.Overnight)

disconnect!(ctx)
