module Config
    # --- Dependencies ---
    using TOML, Dates, HTTP, JSON3
    using ..Constant, ..Region
    
    export APIConfig, from_toml, refresh_access_token!, load_config
             
    const CONFIG_PATH = joinpath(@__DIR__, "..", "config.toml")
    
    mutable struct APIConfig
        app_key::String
        app_secret::String
        access_token::String
        http_url::String
        quote_ws::String
        trade_ws::String
        language::Union{Nothing, Language}
        enable_overnight::Bool
        push_candlestick_mode::PushCandlestickMode
        token_expire_time::Union{Nothing, DateTime}
        
        function APIConfig(; 
            app_key::String, 
            app_secret::String, 
            access_token::String, 
            language::Union{Nothing, Language} = nothing,
            enable_overnight::Bool = false,
            push_candlestick_mode::PushCandlestickMode = PushCandlestickMode.Realtime,
            token_expire_time::Union{Nothing, DateTime} = nothing)
            # Default URLs based on region
            http_url = is_cn() ? DEFAULT_HTTP_URL_CN : DEFAULT_HTTP_URL
            quote_ws = is_cn() ? DEFAULT_QUOTE_WS_CN : DEFAULT_QUOTE_WS
            trade_ws = is_cn() ? DEFAULT_TRADE_WS_CN : DEFAULT_TRADE_WS
            
            new(app_key, app_secret, access_token, http_url, quote_ws, trade_ws,
                language, enable_overnight, push_candlestick_mode, token_expire_time)
        end
    end

    # 从TOML配置文件创建配置
    function from_toml(; path::String = CONFIG_PATH)::APIConfig
        if !isfile(path)
            error("Config file not found: $path")
        end
        
        config_dict = TOML.parsefile(path)
        
        # 必填字段检查
        required_keys = ["app_key", "app_secret", "access_token"]
        for key in required_keys
            if !haskey(config_dict, key)
                error("Missing required config key: $key")
            end
        end
        
        # 获取配置值
        app_key = config_dict["app_key"]
        app_secret = config_dict["app_secret"]
        access_token = config_dict["access_token"]
        token_expire_time = get(config_dict, "token_expire_time", nothing)
       
        # 选填字段
        enable_overnight = get(config_dict, "enable_overnight", false)
        
        # 语言
        language_str = get(config_dict, "language", nothing)
        language = isnothing(language_str) ? nothing : get(LANGUAGES, language_str, nothing)
        
        # Push模式 
        push_mode_str = get(config_dict, "push_candlestick_mode", "Realtime")
        push_candlestick_mode = get(PUSH_CANDLESTICK_MODES, push_mode_str, "Realtime")
        
        # 这里不再处理 http_url/quote_ws/trade_ws，因为构造函数内部自动设置
        return APIConfig(
            app_key = app_key,
            app_secret = app_secret,
            access_token = access_token,
            language = language,
            enable_overnight = enable_overnight,
            push_candlestick_mode = push_candlestick_mode,
            token_expire_time = token_expire_time
        )
    end


    # 刷新Access Token
    function refresh_access_token!(config::APIConfig; expired_at::Union{Nothing, DateTime} = nothing)
        expired_at = isnothing(expired_at) ? now(Dates.UTC) + Dates.Day(90) : expired_at
        
        # 构建请求
        url = config.http_url * "v1/token/refresh"
        headers = [
            "Content-Type" => "application/json",
            "X-API-KEY" => config.app_key
        ]
        
        body = Dict(
            "app_secret" => config.app_secret,
            "expired_at" => Dates.format(expired_at, Dates.RFC1123Format)
        )
        
        try
            response = HTTP.post(url, headers, JSON3.write(body))
            data = JSON3.read(response.body)
            
            if response.status != 200
                error("Failed to refresh token: $(data["message"])")
            end
            
            config.access_token = data["access_token"]
            config.token_expire_time = expired_at
            
            return config.access_token, config.token_expire_time 
        catch e
            error("Error refreshing access token: $e")
        end
    end

    # 检查Token是否过期
    function is_token_expired(config::APIConfig)::Bool
        if isnothing(config.token_expire_time)
            @warn "配置文件缺少token过期时间"
        end
        now(Dates.UTC) >= config.token_expire_time
    end
   
    # 更新配置文件（主要更新token和过期时间）有默认值的参数必须放在最后
    function update_config_toml!(new_token::String, new_expired_at::String, path::String = CONFIG_PATH)
        if !isfile(path)
            error("配置文件不存在: $path")
        end
        config = TOML.parsefile(path)
     
        config["access_token"] = new_token
        config["expired_at"] = new_expired_at
        open(path, "w") do io
            TOML.print(io, config)
        end
    end

    # 验证Token是否过期并加载config
    function load_config(path::String = CONFIG_PATH)
        config = from_toml(path = path)
        if is_token_expired(config)
            new_token, new_expired_at = refresh_access_token!(config; config.token_expire_time)
            update_config_toml!(path, new_token, new_expired_at)
            config = from_toml(path = path)
            return config
        else
            return config
        end
    end
end # end of Config module

