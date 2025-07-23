"""
Longport Julia SDK 测试脚本
"""

using Revise
using Longport

# 测试从TOML文件加载配置
cfg = Config.from_toml()

# Quote API 创建QuoteContext
ctx = QuoteContext(cfg)

# Get basic information of securities
resp = get_quote(ctx, ["700.HK"])
resp = get_quote(ctx, ["700.HK", "AAPL.US", "TSLA.US", "NFLX.US"])

# Subscribe quotes
function on_quote(symbol::String, event)
    println(symbol, event)
end

set_on_quote(ctx, on_quote)
subscribe(ctx, ["700.HK"], [SubType.QUOTE], is_first_push=true)
unsubscribe(ctx, ["700.HK"], [SubType.QUOTE, SubType.TRADE])

# Test candlesticks
candlesticks_data = candlesticks(ctx, "700.HK", CandlePeriod.DAY, 10, AdjustType.NO_ADJUST)
println("Candlesticks data: ", candlesticks_data)
