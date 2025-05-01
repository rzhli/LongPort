include("Constant.jl")  # 先加载 Constant 模块
include("proto/control_pb.jl")
include("Region.jl")
include("Client.jl")
include("Config.jl")
include("Auth.jl")

using .Client, .Auth, .Config


config = Config.from_toml()
config = Config.load_config()
client = Client.connect(config.quote_ws)

# 构造鉴权请求
auth_req = ControlPB.AuthRequest(
    token = config.access_token,
    metadata = Dict("client_version" => Constant.DEFAULT_CLIENT_VERSION)
)

# 发送 CMD_AUTH 协议包
Client.send_packet(client, ControlPB.Command.CMD_AUTH, auth_req)

# 接收服务器响应
while true
    cmd, seq_id, body = Client.receive_packet(client)
    if cmd == ControlPB.Command.CMD_AUTH
        resp = ControlPB.decode(ControlPB.ProtoDecoder(IOBuffer(body)), ControlPB.AuthResponse)
        @info "Authentication successful!" session_id=resp.session_id expires=resp.expires
        break
    else
        @warn "Unexpected message received: $cmd"
    end
end

function main()
    config = Config.load_config()
    client = Client.connect(config.http_url)

    Auth.authenticate_ws(client, config)

    flags, cmd, body = WebSocketClient.receive_packet(client)
    if cmd == Constant.CMD_AUTH
        resp = Auth.handle_auth_response(body)
        println("认证成功，SessionID: ", resp.session_id)
    else
        error("认证失败")
    end
end

main()

# Load configuration from Config

config = Config.load_config()

ctx = Quotes.QuoteContext(config)

resp = quotes(["700.HK", "AAPL.US", "TSLA.US", "NFLX.US"])

function longport_get(codes::Vector{String})

    path::String = "/v1/asset/stock"  # 股票持仓接口请求路径
    timestamp = string(time())
    headers = Dict(
        "X-Api-Key" => app_key,
        "Authorization" => access_token,
        "X-Timestamp" => timestamp,
        "Content-Type" => "application/json; charset=utf-8"
    )
    body = ""  # GET 请求无 body
    query_parameters = join(["symbol=$(code)" for code in codes], "&")
    headers["X-Api-Signature"] = sign("GET", path, headers, query_parameters, body, app_secret)
   
    # 构造完整 URL
    full_url = "$base_url$path?$query_parameters"

    try
        res = HTTP.get(full_url, headers)
        return JSON3.read(res.body)
    catch e
        @warn "请求失败: $e"
        return nothing
    end
end

function process_response(body_json::JSON3.Object{Vector{UInt8}, Vector{UInt64}})
    code = body_json[:code] # 业务码 0:表示请求成功  
    message = body_json[:message]
    data = body_json[:data]
    list = data[:list]
    stock_info = list[1]["stock_info"]
    return stock_info
end

holdings = ["601390.SS", "002424.SZ",
"002145.SZ", "601816.SS", "002936.SZ", "000100.SZ", "002367.SZ", 
"000850.SZ", "600219.SS", "002266.SZ"]
h = longport_get(["601390.SS"])


d = process_response(h)



function longbridge_post(
    url::String, body::Dict, app_key::String, 
    access_token::String, secret::String
    )
    path::String = "v1/trade/order"       # 委托下单接口
    ts = string(time())
    headers = Dict(
        "X-Api-Key" => app_key,
        "Authorization" => access_token,
        "X-Timestamp" => ts,
        "Content-Type" => "application/json; charset=utf-8"
    )

    body_json = JSON3.write(body)
    params = ""
    signature = sign("POST", path, headers, params, body_json, secret)
    headers["X-Api-Signature"] = signature

    response = HTTP.post(url * path, headers, body_json)
    return response
end
