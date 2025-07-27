# Longport Julia SDK

Longport Julia SDK 是一个用于访问 Longport 金融数据和交易服务的 Julia 客户端库，基于全新的 Actor 架构设计。

## 功能特性

### 行情服务
- 获取标的基础信息
- 获取股票实时行情
- 获取期权实时行情
- 获取轮证实时行情
- 获取标的盘口数据
- 获取经纪队列信息
- 获取券商席位信息
- K线数据获取
- 实时行情订阅与推送

### 技术特性
- **Actor-based API**: 基于现代 Actor 模型的全新架构
- **实时推送**: 支持多种类型的实时行情数据推送
- **多市场支持**: 支持美股、港股等多个市场
- **高效传输**: 使用 Protocol Buffers 进行高效的二进制数据传输

## 快速开始

### 安装

```julia
using Pkg
Pkg.add("Longport")
```

### 基本使用

```julia
using Longport

# 从 TOML 配置文件加载配置
cfg = Config.from_toml()

# 异步创建并连接 QuoteContext
ctx, channel = try_new(cfg)

# 获取标的基础信息
resp = static_info(ctx, ["700.HK", "AAPL.US", "TSLA.US"])

# 获取标的实时行情
quotes = realtime_quote(ctx, ["GOOGL.US", "AAPL.US", "TSLA.US"])

# 获取期权实时行情
resp = option_quote(ctx, ["AAPL230317P160000.US"])

# 获取轮证实时行情 
resp = warrant_quote(ctx, ["14993.HK", "66642.HK"])

# 获取标的盘口
resp = depth(ctx, "700.HK")

# 获取K线数据
candlesticks_data = candlesticks(ctx, "GOOGL.US", CandlePeriod.SIXTY_MINUTE, 365)

# 断开连接
disconnect!(ctx)
```

### 实时行情订阅

```julia
# 1. 定义回调函数
function on_quote_callback(symbol::String, event::PushQuote)
    println(symbol, event)
end

# 2. 设置回调
set_on_quote(ctx, on_quote_callback)

# 3. 订阅行情 (可选择不同类型: QUOTE, DEPTH, BROKERS, TRADE)
subscribe(ctx, ["GOOGL.US"], [SubType.DEPTH]; is_first_push=true)

# ... 等待推送 ...
sleep(10)

# 4. 取消订阅
unsubscribe(ctx, ["GOOGL.US"], [SubType.QUOTE, SubType.DEPTH])
```

### 配置文件

创建 `config.toml` 文件：

```toml
# 必填项
base_url = "https://openapi.longportapp.com"
app_key = "your_app_key"
app_secret = "your_app_secret"
access_token = "your_access_token"

# 推荐填写（辅助管理）
token_expire_time = 2025-07-22T00:00:00Z  # ISO8601格式，UTC时间

# 可选项（不填使用默认）
language = "zh_CN"
enable_overnight = true
push_candlestick_mode = "Realtime"
```

## API 概览

### 上下文管理
- `Config.from_toml()`: 从 `config.toml` 文件加载配置。
- `try_new(config)`: 创建并连接 `QuoteContext`。
- `disconnect!(ctx)`: 断开与服务器的连接。

### 行情拉取
- `static_info(ctx, symbols)`: 获取标的基础信息。
- `realtime_quote(ctx, symbols)`: 获取股票实时行情。
- `option_quote(ctx, symbols)`: 获取期权实时行情。
- `warrant_quote(ctx, symbols)`: 获取轮证实时行情。
- `depth(ctx, symbol)`: 获取标的盘口数据。
- `brokers(ctx, symbol)`: 获取标的经纪队列。
- `participants(ctx)`: 获取券商席位 ID 列表。
- `candlesticks(ctx, symbol, period, count)`: 获取 K 线数据。

### 实时行情订阅
- `set_on_quote(ctx, callback)`: 设置行情推送的回调函数。
- `subscribe(ctx, symbols, sub_types)`: 订阅行情。
- `unsubscribe(ctx, symbols, sub_types)`: 取消订阅。

## 技术特性

- **WebSocket 支持**: 实时行情和交易数据推送
- **认证安全**: 自动获取 OTP 令牌进行 WebSocket 认证
- **自动重连**: 连接断开时自动重连
- **多市场支持**: 支持美股、港股、A股等多个市场
- **Protocol Buffers**: 高效的二进制数据传输
- **配置管理**: 灵活的配置文件管理
- **区域自适应**: 根据网络位置自动选择最优服务器

## 许可证

MIT License
