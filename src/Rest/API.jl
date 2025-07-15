module API

using HTTP
using JSON3
using URIs
using SHA
using Dates
using ..Auth
using ..Config

export get, post, request

"""
    get(path::String; params::Dict=Dict(), headers::Dict=Dict(), config::APIConfig)
    
发送 GET 请求到长桥 API。

# Arguments
- `path::String`: API 路径
- `params::Dict`: 查询参数
- `headers::Dict`: 请求头
- `config::APIConfig`: API 配置

# Returns
- API 响应的 JSON 数据
"""

function get(path::String; params::Dict = Dict(), headers::Dict = Dict(), config::APIConfig)
    return request("GET", path; params = params, body = "", headers = headers, config = config)
end

"""
post(path::String; body::String="", headers::Dict=Dict(), config::APIConfig)
    
发送 POST 请求到长桥 API。

# Arguments
- `path::String`: API 路径
- `body::String`: 请求体
- `headers::Dict`: 请求头
- `config::APIConfig`: API 配置

# Returns
- API 响应的 JSON 数据
"""
function post(path::String; body::String = "", headers::Dict = Dict(), config::APIConfig)
    return request("POST", path; params = Dict(), body = body, headers = headers, config = config)
end

"""
request(method::String, path::String; params::Dict, body::String, headers::Dict, config::APIConfig)
    
核心请求函数，处理签名和发送 HTTP 请求。
"""
function request(method::String, path::String; params::Dict, body::String, headers::Dict, config::APIConfig)
    try
        # 准备请求
        mtd = uppercase(method)
        base_url = config.http_url
        
        # 生成时间戳
        timestamp = string(floor(Int, time() * 1000))
        
        # 构建基础头部
        request_headers = Dict{String, String}(
            "X-Api-Key" => config.app_key,
            "Authorization" => "Bearer $(config.access_token)",
            "X-Timestamp" => timestamp,
            "Content-Type" => "application/json; charset=utf-8"
        )
        
        # 合并用户提供的头部
        merge!(request_headers, headers)
        
        # 构建 URL
        uri = if isempty(params)
            URIs.URI(base_url * path)
        else
            URIs.URI(base_url * path; query = params)
        end
        
        # 生成签名
        params_str = isempty(params) ? "" : URIs.escapeuri(params)
        signature = Auth.sign(mtd, path, request_headers, params_str, body, config)
        request_headers["X-Api-Signature"] = signature
        
        @debug "发送 API 请求" method=mtd url=string(uri) headers=request_headers
        
        # 发送请求
        response = if mtd == "GET"
            HTTP.get(uri, headers = request_headers)
        else
            HTTP.post(uri, headers = request_headers, body = body)
        end
        
        # 检查响应状态
        if response.status >= 400
            @error "API 请求失败" status=response.status body=String(response.body)
            error("API request failed with status $(response.status): $(String(response.body))")
        end
        
        # 解析 JSON 响应
        result = JSON3.read(response.body)
        
        @debug "API 请求成功" status=response.status
        
        return result
        
    catch e
        @error "API 请求异常" method=method path=path exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
make_authenticated_request(
    config::APIConfig, method::String, path::String; 
    params::Dict=Dict(), body::String="", headers::Dict=Dict()
)
    
创建经过认证的 HTTP 请求的辅助函数。
"""
function make_authenticated_request(
    config::APIConfig, method::String, path::String; 
    params::Dict = Dict(), body::String = "", headers::Dict = Dict()
    )
    
    # 检查 token 是否过期
    if Config.is_token_expired(config)
        @info "Access token 已过期，正在刷新..."
        Config.refresh_access_token!(config)
    end
    
    return request(method, path; params=params, body=body, headers=headers, config=config)
end

"""
get_quote_static(config::APIConfig, symbols::Vector{String})
    
获取股票静态信息。
"""
function get_quote_static(config::APIConfig, symbols::Vector{String})
    params = Dict("symbols" => join(symbols, ","))
    return get("/v1/quote/static"; params = params, config = config)
end

"""
get_quote_depth(config::APIConfig, symbol::String)
    
获取股票深度行情。
"""
function get_quote_depth(config::APIConfig, symbol::String)
    params = Dict("symbol" => symbol)
    return get("/v1/quote/depth"; params = params, config = config)
end

"""
get_quote_brokers(config::APIConfig, symbol::String)
    
获取股票经纪商队列。
"""
function get_quote_brokers(config::APIConfig, symbol::String)
    params = Dict("symbol" => symbol)
    return get("/v1/quote/brokers"; params = params, config = config)
end

"""
get_quote_trades(config::APIConfig, symbol::String; count::Int=500)
    
获取股票最近成交。
"""
function get_quote_trades(config::APIConfig, symbol::String; count::Int = 500)
    params = Dict(
        "symbol" => symbol,
        "count" => string(count)
    )
    return get("/v1/quote/trades"; params = params, config = config)
end





end # end of module