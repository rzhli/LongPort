using Longport

# ===================================================================
# Python SDK 风格的 Julia Longport 测试示例
# ===================================================================

println("1. Quote API (Get basic information of securities)")
println("从config.toml加载配置...")
config = Config.from_toml(path="src/config.toml")

# 创建QuoteContext - 类似Python: ctx = QuoteContext(config)
ctx = QuoteContext.QuoteCtx(config)

# 获取基础信息 - 类似Python: resp = ctx.quote(["700.HK", "AAPL.US", "TSLA.US", "NFLX.US"])
println("获取证券基础信息...")
try
    resp = ctx.quote(["700.HK", "AAPL.US", "TSLA.US", "NFLX.US"])
    println("✓ 行情数据获取成功")
    println(resp)
catch e
    println("❌ 获取行情失败: ", e)
end

println()

# Quote API (Subscribe quotes) - 类似Python示例
println("2. Quote API (Subscribe quotes)")

# 回调函数 - 类似Python: def on_quote(symbol: str, event: PushQuote):
function on_quote(symbol::String, event)
    println("📈 收到行情推送: $symbol -> $event")
end

# 设置回调 - 类似Python: ctx.set_on_quote(on_quote)
ctx.set_on_quote(on_quote)

# 订阅 - 类似Python: resp = ctx.subscribe(["700.HK"], [SubType.Quote], is_first_push=True)
println("订阅行情推送...")
try
    resp = ctx.subscribe(["700.HK"], is_first_push=true)
    println("✓ 订阅成功: ", resp)
    
    # 等待推送 - 类似Python: sleep(30)
    println("等待推送数据 (5秒)...")
    sleep(5)
catch e
    println("❌ 订阅失败: ", e)
end

println()

# Trade API (Submit order) - 类似Python示例
println("3. Trade API (Submit order)")

# 创建TradeContext - 类似Python: ctx = TradeContext(config)
trade_ctx = TradeContext.TradeContext(config)

# 提交订单 - 类似Python SDK
println("提交测试订单...")
try
    # 类似Python:
    # resp = ctx.submit_order("700.HK", OrderType.LO, OrderSide.Buy, Decimal("500"), 
    #                        TimeInForceType.Day, submitted_price=Decimal("50"), 
    #                        remark="Hello from Python SDK")
    resp = trade_ctx.submit_order(
        "700.HK",                                    # symbol
        TradeContext.TradeOrderType.LO,              # order_type (限价单)
        TradeContext.TradeOrderSide.Buy,             # side (买入)
        500,                                         # submitted_quantity
        TradeContext.TradeTimeInForceType.Day,       # time_in_force (当日有效)
        submitted_price=50.0,                        # submitted_price
        remark="Hello from Julia SDK"                # remark
    )
    println("✓ 订单提交成功")
    println(resp)
catch e
    println("❌ 订单提交失败（正常，需要真实交易权限）: ", e)
end

println()

# 获取订单列表
println("4. 获取订单列表")
try
    orders = trade_ctx.get_orders()
    println("✓ 订单列表获取成功")
    println(orders)
catch e
    println("❌ 获取订单列表失败: ", e)
end

println()

println("=== 测试完成 ===")
println("✨ Julia SDK 提供了与 Python SDK 完全一致的 API 风格")
println("📝 配置从 config.toml 文件加载")
println("🔗 支持 QuoteContext 和 TradeContext 两种上下文")
println("🚀 完全兼容现有的 LongportClient 使用方式")
