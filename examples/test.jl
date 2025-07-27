"""
Longport Julia SDK - Test Script
(Tests functions individually using the new Actor-based API)
"""

using Longport
# Load config from TOML file
cfg = Config.from_toml()
# Asynchronously create and connect the QuoteContext
ctx, channel = try_new(cfg)


# 行情
## 拉取  每次请求支持传入的标的数量上限是 500 个
### 获取标的基础信息   后面三个的 board = ""
resp = static_info(ctx, ["700.HK", "AAPL.US", "TSLA.US", "NFLX.US"])

### 获取股票实时行情 （over_night_quote需开通美股LV1实时行情）
quotes = realtime_quote(ctx, ["GOOGL.US", "AAPL.US", "TSLA.US", "NFLX.US"])

### 获取期权实时行情 （需开通OPRA美股期权行情）
resp = option_quote(ctx, ["AAPL230317P160000.US"])

### 获取轮证实时行情 
resp = warrant_quote(ctx, ["14993.HK", "66642.HK"])

### 获取标的盘口
resp = depth(ctx, "700.HK")

### 获取标的经纪队列   开盘时再测试
resp = brokers(ctx, "66642.HK")

### 获取券商席位 ID
resp = participants(ctx)






# Subscribe quotes
# 1. Define your callback function
function on_quote_callback(symbol::String, event::PushQuote)
    println(symbol, event)
end
# 2. Set the callback
set_on_quote(ctx, on_quote_callback)

#= 3. Subscribe 行情订阅类型
@enumx SubType begin
    UNKNOWN_TYPE = 0
    QUOTE = 1
    DEPTH = 2
    BROKERS = 3
    TRADE = 4
end
=#
subscribe(ctx, ["GOOGL.US"], [SubType.DEPTH]; is_first_push=true)
sleep(10)
# 5. Unsubscribe
unsubscribe(ctx, ["GOOGL.US"], [SubType.QUOTE, SubType.DEPTH])

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
candlesticks_data = candlesticks(ctx, "GOOGL.US", CandlePeriod.SIXTY_MINUTE, 365)
println(candlesticks_data)













disconnect!(ctx)
