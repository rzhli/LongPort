module Longport
    include("Config.jl")    # 用于读取和保存 API 密钥、令牌等配置
    include("Auth.jl")      # 处理鉴权逻辑，如 token 刷新、签名计算。
    include("API.jl")       # 封装所有 HTTP 请求的接口逻辑。
    include("Quotes.jl")    # 提供行情接口（拉取与订阅）。
    include("WebSocket.jl") # 处理 WebSocket 或 TCP 长连接通信。
    #include("Proto.jl")     # 包含所有由 quote.proto 等定义生成的 Protobuf 类型与解析逻辑。
    
    using .Config, .Quotes
    using .Auth
    using .API
    export Config, API, Auth, Quotes, WebSocket
    export QuoteContext, quotes, SecurityQuote  
end




