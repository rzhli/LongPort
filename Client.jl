module Client
    using ..Constant, ..ControlPB # 引入编译后的 control.proto 类型

    using Sockets, ProtoBuf, HTTP, Base.Threads
    using HTTP: WebSockets, WebSockets.WebSocket
    export WSClient, connect, send_packet, receive_packet

    # WebSocket客户端
    mutable struct WSClient
        ws::WebSocket
        next_seq_id::UInt32
        recv_chan::Channel{Vector{UInt8}}
        inflight::Dict{UInt32, Channel{Any}}  # 存储每个 seq_id 对应的 response channel
        rate_limiter::Dict{Int, Any}  # 用于限流
    end

    """
    connect(url::String) -> WSClient
    """
    function connect(ws_url::String)::WSClient
        
        recv_chan = Channel{Vector{UInt8}}(64)
        inflight = Dict{UInt32, Channel{Any}}()
        rate_limiter = Dict{Int, Any}()
    
        ws_ref = Ref{WebSocket}()
        client_ref = Ref{WSClient}()

        # 连接 WebSocket 并初始化结构体
        WebSockets.open(ws_url) do ws
            ws_ref[] = ws
            client = WSClient(ws, UInt32(1), recv_chan, inflight, rate_limiter)
            client_ref[] = client

            @info "WebSocket connected to $ws_url"

            # 启动接收消息协程
            @async listen_forever(client)
            
            # 主线程阻塞交还控制权
            wait(Condition())  # 可替换为更合理的调度模型
        end

        return client_ref[]
    end


    """
    send_packet(client::WSClient, cmd::Command, msg)
    打包包头 + Protobuf body，并发送到 WebSocket。
    示例：send_packet(client, Command.CMD_AUTH, auth_request)
    """
    function send_packet(client::WSClient, cmd::ControlPB.Command.T, msg)
        
        # 可选：运行时验证是否为合法消息类型
        if !(msg isa Union{ControlPB.AuthRequest, ControlPB.AuthResponse,
                            ControlPB.Heartbeat, ControlPB.ReconnectRequest,
                            ControlPB.ReconnectResponse, ControlPB.Close}
            )

            error("Invalid Protobuf message type: $(typeof(msg))")
        end
        ws = client.ws
       
        # 序列号自增
        seq_id = client.next_seq_id
        client.next_seq_id += 1

        # 编码 Protobuf 消息为字节数组
        io = IOBuffer()
        ProtoBuf.encode(io, msg)
        body = take!(io)

        # 包格式:
        # [PacketLength(4)][HeaderLength(2)][Version(2)][Flags(1)][Cmd(2)][SeqId(4)][Body(N)]
        header_length = UInt16(17)  # 固定长度头总长: 4+2+2+1+2+4=15 bytes
        version = UInt16(1)
        flags = UInt8(0)

        packet_length = hton(UInt32(header_length + length(body)))
       
        # 构建头部
        header = IOBuffer()
        write(header, packet_length)           # PacketLength (UInt32)
        write(header, hton(header_length))     # HeaderLength (UInt16)
        write(header, hton(version))           # Version (UInt16)
        write(header, flags)                   # Flags (UInt8)
        write(header, hton(UInt16(cmd)))       # Cmd (UInt16)
        write(header, hton(seq_id))            # SeqId (UInt32)
        
        header_data = take!(header)
        data = vcat(header_data, body)

        try
            WebSockets.writeguarded(ws, data)  # 避免并发写冲突
            @debug "Sent packet: cmd=$(cmd), seq_id=$seq_id, size=$(length(data))"
        catch e
            @error "WebSocket write error" exception=(e, catch_backtrace())
        end
    end

    """
    receive_packet(client::WSClient) -> (cmd::Command, seq_id::UInt32, body::Vector{UInt8})
    从 WebSocket 接收数据包，解码头部与 body。
    """
    function receive_packet(client::WSClient)
        try
            data = take!(client.recv_chan)
            length(data) < 15 && error("Received packet too short for header")
            io = IOBuffer(data)

            packet_length = ntoh(read(io, UInt32))
            header_length = ntoh(read(io, UInt16))
            version = ntoh(read(io, UInt16))
            flags = read(io, UInt8)
            raw_cmd = ntoh(read(io, UInt16))
            seq_id = ntoh(read(io, UInt32))
            
            # 解析命令
            cmd = ControlPB.Command(raw_cmd)
            # 读取 body
            body = read(io)
            @debug "Received packet: cmd=$cmd, seq_id=$seq_id, size=$(length(data))"
            return (cmd, seq_id, body)
        catch e
            @error "Error receiving packet" exception=(e, catch_backtrace())
            rethrow()
        end
    end
end # end of Client module
