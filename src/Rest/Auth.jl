module Auth
    using HTTP, JSON3, SHA, Base64, TOML, URIs
    using ..Config, ..ControlPB, ..Constant, ProtoBuf

    export sign, get_OTP, create_auth_request

    # ========================= Signature =================================
    # 使用 HMAC-SHA256 计算消息摘要并返回十六进制字符串
    function hmac_sha256_hex(key::String, message::String)::String
        return bytes2hex(hmac_sha256(collect(codeunits(key)), codeunits(message)))
    end

    function sign(
        method::String, uri::String, headers::Dict{String, String},
        params::String, body::String, config::APIConfig
        )::String
        mtd = uppercase(method)
        ts = headers["X-Timestamp"]
        access_token = headers["Authorization"]
        app_key = headers["X-Api-Key"]

        canonical_request = join([
            "$mtd|$uri|$params|authorization:$access_token",
            "x-api-key:$app_key",
            "x-timestamp:$ts",
            "|authorization;x-api-key;x-timestamp|"], "\n"
        )

        if !isempty(body)
            canonical_request *= bytes2hex(sha1(body))
        end
        sign_str = "HMAC-SHA256|" * bytes2hex(sha1(canonical_request))
        signature = hmac_sha256_hex(config.app_secret, sign_str)
        return "HMAC-SHA256 SignedHeaders=authorization;x-api-key;x-timestamp, Signature=$signature"
    end

    # ==================== get OTP(One Time Password) ==================
    """
    获取长连接使用的 Token(One time password)，长连接的 Token 可以用来连接行情和交易的长连接网关，
    是一次性的，使用过后就会作废。
    请求
    基本信息	
    HTTP URL	    /v1/socket/token
    HTTP Method	    GET
    请求头
    名称	            类型	    必须	    描述
    Authorization	  string	    是	
    Content-Type	  string	    是	固定值："application/json; charset=utf-8"
    """

    function get_OTP(config::APIConfig)
        timestamp = string(floor(Int, time() * 1000))
        headers = Dict(
            "X-Api-Key" => config.app_key,
            "Authorization" => "Bearer $(config.access_token)",
            "X-Timestamp" => timestamp,
            "Content-Type" => "application/json; charset=utf-8",
        )

        # 生成签名 
        signature = sign("GET", "/v1/socket/token", headers, "", "", config)

        headers["X-Api-Signature"] = signature
        
        url = config.http_url
        res = HTTP.get("$url/v1/socket/token", headers = headers)
        OTP = JSON3.read(res.body)[:data][:otp]
        return OTP
    end

    # ========================= WebSocket Authentication ==================
    """
        create_auth_request(config::Config.APIConfig) -> Vector{UInt8}

    Creates the serialized body for a WebSocket authentication request.
    Automatically gets OTP token for WebSocket authentication.
    """
    function create_auth_request(config::Config.APIConfig)::Vector{UInt8}
        # 获取OTP令牌用于WebSocket认证
        otp_token = get_OTP(config)
        
        auth_req = ControlPB.AuthRequest(
            otp_token,
            Dict("client_version" => Constant.DEFAULT_CLIENT_VERSION) 
        )
        io_buf = IOBuffer()
        encoder = ProtoBuf.ProtoEncoder(io_buf)
        ProtoBuf.encode(encoder, auth_req)
        return take!(io_buf)
    end
end # end of Auth module
