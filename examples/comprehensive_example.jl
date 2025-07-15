using Longport

"""
长桥 Julia SDK 完整使用示例

演示了如何使用扩展后的 SDK 功能，包括：
1. 基础连接和认证
2. 获取各种市场数据
3. 订阅实时行情
4. 历史数据分析
"""

function main()
    println("=== 长桥 Julia SDK 使用示例 ===\n")
    
    # 1. 创建客户端并连接
    println("1. 初始化客户端...")
    client = LongportClient("config.toml")
    
    try
        # 连接到服务器
        connect!(client, Quote=true, trade=false)
        println("✓ 已连接到长桥服务器\n")
        
        # 2. 获取股票静态信息
        println("2. 获取股票静态信息...")
        symbols = ["AAPL.US", "00700.HK", "600519.SH"]
        static_info = get_static_info(client, symbols)
        println("✓ 获取到 $(length(symbols)) 只股票的静态信息")
        
        for symbol in symbols
            if haskey(static_info, "data") && !isempty(static_info["data"])
                println("  - $symbol: 已获取")
            end
        end
        println()
        
        # 3. 获取 K 线数据
        println("3. 获取 K 线数据...")
        symbol = "AAPL.US"
        
        # 获取日线数据
        daily_data = get_candlestick(client, symbol, "1d", count=30)
        println("✓ 获取 $symbol 最近30天日线数据")
        
        # 获取历史数据（按日期范围）
        history_data = get_history_candlestick_by_date(
            client, symbol, "1d", 
            "2024-01-01", "2024-01-31"
        )
        println("✓ 获取 $symbol 2024年1月历史数据")
        
        # 获取分时数据
        intraday_data = get_intraday(client, symbol)
        println("✓ 获取 $symbol 当日分时数据")
        println()
        
        # 4. 获取期权数据（如果支持）
        println("4. 获取期权链信息...")
        try
            option_dates = get_option_chain_dates(client, symbol)
            println("✓ 获取 $symbol 期权到期日列表")
        catch e
            println("! 期权数据获取失败（可能该股票不支持期权）: $(e)")
        end
        println()
        
        # 5. 获取资金流向
        println("5. 获取资金流向...")
        capital_flow = get_capital_flow(client, "00700.HK")
        println("✓ 获取腾讯(00700.HK)资金流向数据")
        println()
        
        # 6. 获取交易时段信息
        println("6. 获取交易时段...")
        trading_session = get_trading_session(client, "US", "2024-07-15")
        println("✓ 获取美股交易时段信息")
        
        trading_days = get_trading_days(client, "HK", "2024-07-01", "2024-07-31")
        println("✓ 获取港股7月交易日历")
        println()
        
        # 7. 订阅实时行情
        println("7. 订阅实时行情...")
        
        # 设置行情回调
        quote_count = 0
        set_callback!(client, "quote") do data
            global quote_count
            quote_count += 1
            println("  收到行情更新 #$quote_count: $(get(data, "symbol", "Unknown"))")
        end
        
        # 订阅股票
        subscribe_symbols = ["AAPL.US", "TSLA.US"]
        subscribe_quotes(client, subscribe_symbols)
        println("✓ 已订阅 $(join(subscribe_symbols, ", ")) 实时行情")
        
        # 等待一些行情数据
        println("  等待行情数据（10秒）...")
        sleep(10)
        
        # 取消订阅
        unsubscribe_quotes(client, subscribe_symbols)
        println("✓ 已取消订阅")
        println()
        
        # 8. 获取窝轮信息（港股）
        println("8. 获取窝轮信息...")
        try
            warrant_issuers = MarketData.get_quote_warrant_issuers(client.config)
            println("✓ 获取窝轮发行商列表")
            
            warrant_list = get_warrant_list(client, "00700.HK", page=1, size=10)
            println("✓ 获取腾讯相关窝轮列表")
        catch e
            println("! 窝轮数据获取失败: $(e)")
        end
        println()
        
        # 9. 数据分析示例
        println("9. 数据分析示例...")
        analyze_stock_data(client, "AAPL.US")
        println()
        
        println("=== 示例运行完成 ===")
        
    catch e
        println("❌ 运行过程中发生错误: $e")
        println("错误详情: $(sprint(showerror, e, catch_backtrace()))")
        
    finally
        # 断开连接
        println("\n清理资源...")
        disconnect!(client)
        println("✓ 已断开连接")
    end
end

"""
analyze_stock_data(client::LongportClient, symbol::String)

简单的股票数据分析示例。
"""
function analyze_stock_data(client::LongportClient, symbol::String)
    try
        println("  分析股票: $symbol")
        
        # 获取30天历史数据
        data = get_candlestick(client, symbol, "1d", count=30)
        
        if haskey(data, "data") && !isempty(data["data"])
            candles = data["data"]
            
            # 计算简单统计
            closes = [Float64(candle["close"]) for candle in candles if haskey(candle, "close")]
            
            if !isempty(closes)
                current_price = closes[end]
                high_price = maximum(closes)
                low_price = minimum(closes)
                avg_price = sum(closes) / length(closes)
                
                println("    当前价格: \$$(round(current_price, digits=2))")
                println("    30天最高: \$$(round(high_price, digits=2))")
                println("    30天最低: \$$(round(low_price, digits=2))")
                println("    30天均价: \$$(round(avg_price, digits=2))")
                
                # 计算涨跌幅
                if length(closes) >= 2
                    change = closes[end] - closes[end-1]
                    change_pct = (change / closes[end-1]) * 100
                    println("    日变化: \$$(round(change, digits=2)) ($(round(change_pct, digits=2))%)")
                end
            else
                println("    无有效价格数据")
            end
        else
            println("    无法获取历史数据")
        end
        
    catch e
        println("    数据分析失败: $e")
    end
end

# 运行示例
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end