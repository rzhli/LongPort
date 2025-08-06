module Constant

    using EnumX
    
    export DEFAULT_HTTP_URL, DEFAULT_HTTP_URL_CN, DEFAULT_QUOTE_WS, 
           DEFAULT_TRADE_WS, DEFAULT_QUOTE_WS_CN, DEFAULT_TRADE_WS_CN, 
           DEFAULT_CLIENT_VERSION, PROTOCOL_VERSION, PushCandlestickMode,
           CODEC_TYPE, PLATFORM_TYPE, Language, Market, Granularity, SecuritiesUpdateMode,
           SecurityListCategory
    
    # --- 默认API地址 ---
    const DEFAULT_HTTP_URL = "https://openapi.longportapp.com"
    const DEFAULT_HTTP_URL_CN = "https://openapi.longportapp.cn"
    const DEFAULT_QUOTE_WS = "wss://openapi-quote.longportapp.com/v2"
    const DEFAULT_TRADE_WS = "wss://openapi-trade.longportapp.com/v2"
    const DEFAULT_QUOTE_WS_CN = "wss://openapi-quote.longportapp.cn/v2"
    const DEFAULT_TRADE_WS_CN = "wss://openapi-trade.longportapp.cn/v2"
    
    # --- 协议常量 ---
    const PROTOCOL_VERSION = 1  # 协议版本号， 目前仅支持一个版本
    const CODEC_TYPE = 1  # 数据包序列化方式：Protobuf
    const PLATFORM_TYPE = 9  # 客户端平台 OpenAPI 版本
    
    # --- 客户端版本 ---
    const DEFAULT_CLIENT_VERSION = "1.0.0"

    # --- 支持语言 ---
    @enumx Language begin
        ZH_CN = 0  # 简体中文 (default)
        ZH_HK = 1  # 繁體中文 (香港)
        EN = 2     # English
    end

    # --- Push Modes ---
    @enumx PushCandlestickMode begin
        Realtime  # 实时模式
        Confirmed # 确认模式
    end
    
    # --- Market Enum ---
    @enumx Market begin
        Unknown = 0
        US = 1      # US market
        HK = 2      # HK market 
        CN = 3      # CN market
        SG = 4      # SG market
    end

    @enumx Granularity begin
        Day = 0
        Week = 1
        Month = 2
    end

    @enumx SecuritiesUpdateMode begin
        Add = 0
        Remove = 1
        Replace = 2
    end
    
    function Base.string(s::SecuritiesUpdateMode.T)
        s == SecuritiesUpdateMode.Add && return "add"
        s == SecuritiesUpdateMode.Remove && return "remove"
        s == SecuritiesUpdateMode.Replace && return "replace"
        throw(ArgumentError("Invalid SecuritiesUpdateMode value"))
    end
    
    function Base.string(g::Granularity.T)
        g == Granularity.Day && return "day"
        g == Granularity.Week && return "week"
        g == Granularity.Month && return "month"
        throw(ArgumentError("Invalid Granularity value"))
    end

    @enumx SecurityListCategory begin
        Overnight = 0
    end

    function Base.string(c::SecurityListCategory.T)
        c == SecurityListCategory.Overnight && return "Overnight"
        throw(ArgumentError("Invalid SecurityListCategory value"))
    end
    
end # module
