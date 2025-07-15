# Longport Julia SDK

长桥 Julia SDK，提供统一的接口访问长桥 HTTP API 和 WebSocket 服务。

## 项目结构

```
Longport.jl/
├── Project.toml               # Julia 项目配置
├── Manifest.toml             # 依赖锁定文件
├── LICENSE                   # MIT 许可证
├── README.md                 # 项目文档
├── src/                      # 源代码目录
│   ├── Longport.jl           # 主模块文件
│   ├── config.toml           # API 配置文件
│   ├── Core/                 # 核心模块
│   │   ├── ControlPB.jl      # Protocol Buffer 控制协议
│   │   ├── Constant.jl       # 常量定义
│   │   ├── Config.jl         # 配置管理
│   │   ├── Region.jl         # 区域设置
│   │   ├── Quotes.jl         # 行情业务逻辑
│   │   ├── MarketData.jl     # 市场数据
│   │   └── Trading.jl        # 交易业务逻辑
│   └── Rest/                 # REST API
│       ├── Auth.jl           # 认证模块
│       ├── Client.jl         # WebSocket 客户端
│       └── API.jl            # HTTP API 接口
└── examples/                 # 示例代码
    ├── authentication.jl     # 认证示例
    ├── comprehensive_example.jl # 综合示例
    ├── get_quotes.jl         # 获取行情示例
    └── place_order.jl        # 下单示例
```

## 模块架构

### Core 模块
- **ControlPB.jl**: Protocol Buffer 控制协议定义（WebSocket 认证、心跳等）
- **Constant.jl**: API 端点、命令码、默认设置等常量定义
- **Config.jl**: 配置结构体和加载逻辑（API 密钥、URL 等）
- **Region.jl**: 区域和语言设置，根据位置判断API端点
- **Quotes.jl**: 行情业务逻辑封装，如拉取快照报价、订阅实时推送
- **MarketData.jl**: 市场数据相关接口
- **Trading.jl**: 交易相关业务逻辑

### Rest 模块
- **Auth.jl**: 处理认证端点逻辑（获取 OTP token）
- **Client.jl**: WebSocket 客户端设置，连接管理
- **API.jl**: 统一封装 HTTP 接口的主入口

## 快速开始

### 安装

```julia
using Pkg
Pkg.add(url="https://github.com/your-repo/Longport.jl")
```

### 基本使用

```julia
using Longport

# 从配置文件创建客户端
client = LongportClient(joinpath(@__DIR__, "config.toml"))

# 连接并认证
connect!(client)

# 订阅行情
subscribe_quotes(client, ["AAPL.US", "00700.HK"])

# 获取股票静态信息
info = get_static_info(client, ["AAPL.US"])

# 获取 K 线数据
candlestick = get_candlestick(client, "AAPL.US", "Day", count=30)

# 断开连接
disconnect!(client)
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

## API 接口

### 配置管理
- `APIConfig` - 配置结构体
- `load_config()` - 加载配置文件
- `refresh_access_token!()` - 刷新访问令牌

### 客户端管理
- `LongportClient()` - 创建客户端
- `connect!()` - 连接到服务器
- `disconnect!()` - 断开连接
- `is_connected()` - 检查连接状态

### 认证相关
- `get_OTP()` - 获取一次性密码
- `create_auth_request()` - 创建认证请求

### 行情相关
- `get_static_info()` - 获取股票静态信息
- `get_candlestick()` - 获取 K 线数据
- `get_history_candlestick_by_date()` - 获取历史 K 线
- `get_intraday()` - 获取分时数据
- `get_option_chain_dates()` - 获取期权链到期日
- `get_warrant_list()` - 获取窝轮列表
- `get_capital_flow()` - 获取资金流向
- `get_trading_session()` - 获取交易时段
- `get_trading_days()` - 获取交易日历

### 实时推送
- `subscribe_quotes()` - 订阅行情推送
- `unsubscribe_quotes()` - 取消订阅

### HTTP 请求
- `get_request()` - 发送 GET 请求
- `post_request()` - 发送 POST 请求

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