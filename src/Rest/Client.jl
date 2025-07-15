module Client

using HTTP: WebSockets
using ProtoBuf
using Dates
using Base.Threads

using ..Constant
using ..Protocol
using ..ControlPB

export WSClient, connect, disconnect!, send_packet, is_connected, 
       start_message_loop, stop_message_loop

"""
WSClient
    
WebSocket 客户端，用于与长桥服务器建立长连接。

# Fields
- `ws::Union{Nothing, WebSockets.WebSocket}`: WebSocket 连接
- `url::String`: 连接 URL
- `connected::Bool`: 连接状态
- `authenticated::Bool`: 认证状态
- `seq_id::UInt32`: 序列号
- `session_id::String`: 会话 ID
- `callbacks::Dict{String, Function}`: 回调函数
- `message_task::Union{Nothing, Task}`: 消息处理任务
- `heartbeat_task::Union{Nothing, Task}`: 心跳任务
- `reconnect_enabled::Bool`: 是否启用自动重连
- `max_reconnect_attempts::Int`: 最大重连次数
- `reconnect_delay::Float64`: 重连延迟（秒）
"""
mutable struct WSClient
    ws::Union{Nothing, WebSockets.WebSocket}
    url::String
    connected::Bool
    authenticated::Bool
    seq_id::UInt32
    session_id::String
    callbacks::Dict{String, Function}
    message_task::Union{Nothing, Task}
    heartbeat_task::Union{Nothing, Task}
    reconnect_enabled::Bool
    max_reconnect_attempts::Int
    reconnect_delay::Float64
    
    function WSClient(url::String)
        new(
            nothing,                # ws
            url,                    # url
            false,                  # connected
            false,                  # authenticated
            UInt32(1),              # seq_id
            "",                     # session_id
            Dict{String, Function}(), # callbacks
            nothing,                # message_task
            nothing,                # heartbeat_task
            true,                   # reconnect_enabled
            5,                      # max_reconnect_attempts
            5.0                     # reconnect_delay
        )
    end
end

"""
connect(url::String) -> WSClient
    
创建并连接到 WebSocket 服务器。
"""
function connect(url::String, auth_data::Union{Nothing, Vector{UInt8}} = nothing)::WSClient
    client = WSClient(url)
    connect!(client, auth_data)
    return client
end

"""
connect!(client::WSClient, auth_data::Union{Nothing, Vector{UInt8}} = nothing)
    
连接到 WebSocket 服务器。
"""
function connect!(client::WSClient, auth_data::Union{Nothing, Vector{UInt8}} = nothing)
    if client.connected
        @warn "客户端已连接"
        return
    end
    
    try
        @info "正在连接到 WebSocket 服务器: $(client.url)"
        
        # 解析 URL 构建完整的连接字符串
        base_url = client.url
        if !startswith(base_url, "wss://") && !startswith(base_url, "ws://")
            base_url = "wss://" * base_url
        end
        
        # 添加协议参数
        query_params = [
            "version=2",
            "codec=1", 
            "platform=9"
        ]
        
        full_url = base_url * "?" * join(query_params, "&")
        
        @info "连接 URL: $full_url"
        
        # 建立 WebSocket 连接
        WebSockets.open(full_url) do ws
            client.ws = ws
            client.connected = true
            client.seq_id = UInt32(1)
            
            @info "WebSocket 连接成功"
            
            # 如果提供了认证数据，立即发送
            if !isnothing(auth_data)
                @info "发送认证数据..."
                send_packet(client, UInt8(2), auth_data)  # CMD_AUTH = 2
            end
            
            # 启动消息处理循环
            start_message_loop(client)
            
            # 启动心跳任务
            start_heartbeat_task(client)
            
            # 保持连接
            while client.connected && isopen(ws.io)
                sleep(0.1)
            end
        end
        
    catch e
        @error "WebSocket 连接失败" exception=(e, catch_backtrace())
        client.connected = false
        rethrow(e)
    end
end

"""
disconnect!(client::WSClient)
    
断开 WebSocket 连接。
"""
function disconnect!(client::WSClient)
    if !client.connected
        return
    end
    
    @info "正在断开 WebSocket 连接..."
    
    # 停止心跳任务
    if !isnothing(client.heartbeat_task)
        try
            Base.schedule(client.heartbeat_task, InterruptException(), error=true)
        catch
        end
        client.heartbeat_task = nothing
    end
    
    # 停止消息处理任务
    if !isnothing(client.message_task)
        try
            Base.schedule(client.message_task, InterruptException(), error=true)
        catch
        end
        client.message_task = nothing
    end
    
    # 关闭 WebSocket 连接
    if !isnothing(client.ws) && isopen(client.ws.io)
        try
            WebSockets.close(client.ws)
        catch e
            @warn "关闭 WebSocket 连接时发生错误" exception=e
        end
    end
    
    client.connected = false
    client.authenticated = false
    client.ws = nothing
    
    @info "WebSocket 连接已断开"
end

"""
is_connected(client::WSClient) -> Bool
    
检查客户端是否已连接。
"""
function is_connected(client::WSClient)::Bool
    return client.connected && !isnothing(client.ws) && isopen(client.ws.io)
end

"""
send_packet(client::WSClient, cmd::UInt8, body::Vector{UInt8})
    
发送数据包到服务器。
"""
function send_packet(client::WSClient, cmd::UInt8, body::Vector{UInt8})
    if !is_connected(client)
        throw(ArgumentError("客户端未连接"))
    end
    
    try
        # 构建数据包
        seq_id = client.seq_id
        client.seq_id += 1
        
        # 构建数据包头部
        # 根据长桥协议：[cmd(1)] + [seq_id(4)] + [body_len(4)] + [body]
        header = IOBuffer()
        write(header, cmd)                    # 命令 (1 byte)
        write(header, hton(seq_id))          # 序列号 (4 bytes, big-endian)
        write(header, hton(UInt32(length(body))))  # 包体长度 (4 bytes, big-endian)
        
        header_data = take!(header)
        packet_data = vcat(header_data, body)
        
        # 发送数据包
        WebSockets.send(client.ws, packet_data)
        
        @debug "已发送数据包" cmd=cmd seq_id=seq_id body_len=length(body)
        
        return seq_id
        
    catch e
        @error "发送数据包失败" exception=(e, catch_backtrace())
        rethrow(e)
    end
end

"""
start_message_loop(client::WSClient)
    
启动消息处理循环。
"""
function start_message_loop(client::WSClient)
    if !isnothing(client.message_task)
        return
    end
    
    client.message_task = @async begin
        try
            @info "启动消息处理循环"
            
            while is_connected(client)
                try
                    # 接收消息
                    data = WebSockets.receive(client.ws)
                    
                    if length(data) < 9  # 最小包头长度
                        @warn "接收到无效数据包，长度过短" length=length(data)
                        continue
                    end
                    
                    # 解析包头
                    io = IOBuffer(data)
                    cmd = read(io, UInt8)
                    seq_id = ntoh(read(io, UInt32))
                    body_len = ntoh(read(io, UInt32))
                    
                    # 读取包体
                    body = read(io, body_len)
                    
                    @debug "接收到数据包" cmd=cmd seq_id=seq_id body_len=body_len
                    
                    # 处理消息
                    handle_message(client, cmd, seq_id, body)
                    
                catch e
                    if e isa InterruptException
                        @info "消息处理循环被中断"
                        break
                    elseif e isa WebSockets.WebSocketError
                        @warn "WebSocket 错误，尝试重连" exception=e
                        if client.reconnect_enabled
                            reconnect(client)
                        end
                        break
                    else
                        @error "消息处理循环发生错误" exception=(e, catch_backtrace())
                    end
                end
            end
            
        catch e
            @error "消息处理循环异常退出" exception=(e, catch_backtrace())
        finally
            @info "消息处理循环已停止"
        end
    end
end

"""
handle_message(client::WSClient, cmd::UInt8, seq_id::UInt32, body::Vector{UInt8})
    
处理接收到的消息。
"""
function handle_message(client::WSClient, cmd::UInt8, seq_id::UInt32, body::Vector{UInt8})
    try
        # 根据命令类型处理消息
        if cmd == 0x01  # 认证响应
            handle_auth_response(client, body)
        elseif cmd == 0x02  # 心跳响应
            handle_heartbeat_response(client, body)
        elseif cmd == 0x10  # 行情推送
            handle_quote_push(client, body)
        elseif cmd == 0x11  # 订单推送
            handle_order_push(client, body)
        else
            @debug "未处理的消息类型" cmd=cmd seq_id=seq_id
        end
        
        # 调用用户定义的回调
        callback_key = "cmd_$(cmd)"
        if haskey(client.callbacks, callback_key)
            client.callbacks[callback_key](cmd, seq_id, body)
        end
        
    catch e
        @error "处理消息时发生错误" cmd=cmd seq_id=seq_id exception=(e, catch_backtrace())
    end
end

"""
handle_auth_response(client::WSClient, body::Vector{UInt8})
    
处理认证响应。
"""
function handle_auth_response(client::WSClient, body::Vector{UInt8})
    try
        # 解析认证响应
        io = IOBuffer(body)
        resp = ProtoBuf.decode(ControlPB.ProtoDecoder(io), ControlPB.AuthResponse)
        
        client.session_id = resp.session_id
        client.authenticated = true
        
        @info "认证成功" session_id=client.session_id
        
        # 调用认证成功回调
        if haskey(client.callbacks, "auth_success")
            client.callbacks["auth_success"](resp)
        end
        
    catch e
        @error "处理认证响应失败" exception=(e, catch_backtrace())
        client.authenticated = false
    end
end

"""
handle_heartbeat_response(client::WSClient, body::Vector{UInt8})
    
处理心跳响应。
"""
function handle_heartbeat_response(client::WSClient, body::Vector{UInt8})
    @debug "收到心跳响应"
    
    if haskey(client.callbacks, "heartbeat")
        client.callbacks["heartbeat"](body)
    end
end

"""
handle_quote_push(client::WSClient, body::Vector{UInt8})
    
处理行情推送。
"""
function handle_quote_push(client::WSClient, body::Vector{UInt8})
    @debug "收到行情推送" body_len=length(body)
    
    if haskey(client.callbacks, "quote")
        client.callbacks["quote"](body)
    end
end

"""
handle_order_push(client::WSClient, body::Vector{UInt8})
    
处理订单推送。
"""
function handle_order_push(client::WSClient, body::Vector{UInt8})
    @debug "收到订单推送" body_len=length(body)
    
    if haskey(client.callbacks, "order")
        client.callbacks["order"](body)
    end
end

"""
start_heartbeat_task(client::WSClient; interval::Int=30)
    
启动心跳任务。
"""
function start_heartbeat_task(client::WSClient; interval::Int=30)
    if !isnothing(client.heartbeat_task)
        return
    end
    
    client.heartbeat_task = @async begin
        try
            @info "启动心跳任务" interval=interval
            
            while is_connected(client) && client.authenticated
                try
                    # 发送心跳包
                    heartbeat_body = Vector{UInt8}()  # 心跳包体为空
                    send_packet(client, 0x02, heartbeat_body)
                    
                    sleep(interval)
                    
                catch e
                    if e isa InterruptException
                        @info "心跳任务被中断"
                        break
                    else
                        @error "心跳任务发生错误" exception=(e, catch_backtrace())
                        sleep(1)  # 等待后重试
                    end
                end
            end
            
        catch e
            @error "心跳任务异常退出" exception=(e, catch_backtrace())
        finally
            @info "心跳任务已停止"
        end
    end
end

"""
set_callback!(client::WSClient, event::String, callback::Function)
    
设置事件回调函数。
"""
function set_callback!(client::WSClient, event::String, callback::Function)
    client.callbacks[event] = callback
end

"""
reconnect(client::WSClient)
    
重新连接到服务器。
"""
function reconnect(client::WSClient)
    if !client.reconnect_enabled
        return
    end
    
    @info "开始重连..."
    
    # 断开当前连接
    disconnect!(client)
    
    # 等待一段时间后重连
    sleep(client.reconnect_delay)
    
    # 重新连接
    try
        connect!(client)
        @info "重连成功"
    catch e
        @error "重连失败" exception=(e, catch_backtrace())
    end
end

end # module Client
