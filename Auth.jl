module Auth
    using ..Config, ..ControlPB, ..Constant, ..Client 
    using HTTP, JSON3, SHA, Base64, Logging, TOML, URIs

    export 
    handle_auth_response, sign, hmac_sha256_hex, authenticate_ws

    # ========================= Signature =================================
    # 使用 HMAC-SHA256 计算消息摘要并返回十六进制字符串
    function hmac_sha256_hex(key::String, message::String)::String
        return bytes2hex(hmac_sha256(collect(codeunits(key)), codeunits(message)))
    end

    function sign(
        method::String, uri::String, headers::Dict{String, String},
        params::String, body::String, app_secret::String
        )::String
        mtd = uppercase(method)
        ts = headers["X-Timestamp"]
        access_token = headers["Authorization"]
        app_key = headers["X-Api-Key"]

        canonical_request = """
                        $mtd|$uri|$params|authorization:$access_token
                        x-api-key:$app_key
                        x-timestamp:$ts
                        |authorization;x-api-key;x-timestamp|
                        """
        if !isempty(body)
            canonical_request *= bytes2hex(sha1(body))
        end
        sign_str = "HMAC-SHA256|" * bytes2hex(sha1(canonical_request))
        signature = hmac_sha256_hex(app_secret, sign_str)
        return "HMAC-SHA256 SignedHeaders=authorization;x-api-key;x-timestamp, Signature=$signature"
    end

    # ========================= WebSocket Authentication ==================
    # 发送鉴权请求 CMD_AUTH 到服务器，并等待响应。
    function authenticate_ws(client::Client.WSClient, config::Config.APIConfig)
        auth_req = ControlPB.AuthRequest(
            token = config.access_token,
            metadata = Dict("client_version" =>  Constant.DEFAULT_CLIENT_VERSION) 
        )
        io_buf = IOBuffer()
        ProtoBuf.encode(io_buf, auth_req)
        body = take!(io_buf)
        @info "Sending CMD_AUTH to WebSocket server..."
        Client.send_packet(client, ControlPB.Command.CMD_AUTH, auth_req)
    end
    """
    handle_auth_response(body::Vector{UInt8}) -> AuthResponse
    解析服务器返回的鉴权响应包。
    """
    function handle_auth_response(body::Vector{UInt8})
        io = IOBuffer(body)
        resp = ProtoBuf.decode(ControlPB.ProtoDecoder(io), ControlPB.AuthResponse)
        @info "WebSocket auth successful:" session_id = resp.session_id expires = resp.expires
        return resp
    end
end # end of Auth module
