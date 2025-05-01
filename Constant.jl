module Constant

    export DEFAULT_HTTP_URL, DEFAULT_HTTP_URL_CN, DEFAULT_QUOTE_WS, 
           DEFAULT_TRADE_WS, DEFAULT_QUOTE_WS_CN, DEFAULT_TRADE_WS_CN, 
           Language, LANGUAGES, language_str, DEFAULT_CLIENT_VERSION,
           PushCandlestickMode, PUSH_CANDLESTICK_MODES
    export PING_URL, CACHE_EXPIRE_SECONDS 
    
    # --- 默认API地址 ---
    const DEFAULT_HTTP_URL = "https://openapi.longportapp.com"
    const DEFAULT_HTTP_URL_CN = "https://openapi.longportapp.cn"
    const DEFAULT_QUOTE_WS = "wss://openapi-quote.longportapp.com/v2"
    const DEFAULT_TRADE_WS = "wss://openapi-trade.longportapp.com/v2"
    const DEFAULT_QUOTE_WS_CN = "wss://openapi-quote.longportapp.cn/v2"
    const DEFAULT_TRADE_WS_CN = "wss://openapi-trade.longportapp.cn/v2"
    
    # 地区检测地址，判断是否在中国大陆
    const PING_URL = "https://api.lbkrs.com/_ping"
    const CACHE_EXPIRE_SECONDS = 600  # seconds
    
    # --- 客户端版本 ---
    const DEFAULT_CLIENT_VERSION = "1.0.0"

    # --- 支持语言 ---
    @enum Language begin
        ZH_CN = 0  # 简体中文
        ZH_HK = 1  # 繁體中文 (香港)
        EN = 2     # English (default)
    end

    # Language code mapping
    const LANGUAGES = Dict(
        "zh-CN" => ZH_CN,
        "zh-HK" => ZH_HK,
        "en" => EN,
        "zh_CN" => ZH_CN,  # legacy support
        "en_US" => EN      # legacy support
    )

    # Get language string representation
    function language_str(lang::Language)::String
        lang == ZH_CN && return "zh-CN"
        lang == ZH_HK && return "zh-HK"
        return "en"
    end
    
    # --- Push Modes ---
    @enum PushCandlestickMode begin
        Realtime  # 实时模式
        Confirmed # 确认模式
    end
    const PUSH_CANDLESTICK_MODES = Dict(
        "Realtime" => Realtime,
        "Confirmed" => Confirmed,
        "realtime" => Realtime,  # lowercase variant
        "confirmed" => Confirmed  # lowercase variant
    )
end # module
