# 基于官方 trade.proto 的Julia实现
# 专门用于交易WebSocket协议的Protocol Buffer消息

module TradeProtocol

    import ProtoBuf as PB
    using ProtoBuf: OneOf
    using ProtoBuf.EnumX: @enumx

    export Command, DispatchType, ContentType, Sub, SubResponse, SubResponseFail, Unsub, UnsubResponse, Notification

    # 交易网关命令定义
    @enumx Command begin
        CMD_UNKNOWN = 0
        CMD_SUB = 16
        CMD_UNSUB = 17
        CMD_NOTIFY = 18
    end

    # 分发类型
    @enumx DispatchType begin
        DISPATCH_UNDEFINED = 0
        DISPATCH_DIRECT = 1
        DISPATCH_BROADCAST = 2
    end

    # 内容类型
    @enumx ContentType begin
        CONTENT_UNDEFINED = 0
        CONTENT_JSON = 1
        CONTENT_PROTO = 2
    end

    # SubResponse 失败信息
    struct SubResponseFail
        topic::String
        reason::String
    end
    PB.default_values(::Type{SubResponseFail}) = (;topic = "", reason = "")
    PB.field_numbers(::Type{SubResponseFail}) = (;topic = 1, reason = 2)

    function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:SubResponseFail})
        topic = ""
        reason = ""
        while !PB.message_done(d)
            field_number, wire_type = PB.decode_tag(d)
            if field_number == 1
                topic = PB.decode(d, String)
            elseif field_number == 2
                reason = PB.decode(d, String)
            else
                PB.skip(d, wire_type)
            end
        end
        return SubResponseFail(topic, reason)
    end

    function PB.encode(e::PB.AbstractProtoEncoder, x::SubResponseFail)
        initpos = position(e.io)
        !isempty(x.topic) && PB.encode(e, 1, x.topic)
        !isempty(x.reason) && PB.encode(e, 2, x.reason)
        return position(e.io) - initpos
    end
    function PB._encoded_size(x::SubResponseFail)
        encoded_size = 0
        !isempty(x.topic) && (encoded_size += PB._encoded_size(x.topic, 1))
        !isempty(x.reason) && (encoded_size += PB._encoded_size(x.reason, 2))
        return encoded_size
    end

    # 订阅请求 - 命令16
    struct Sub
        topics::Vector{String}
    end
    PB.default_values(::Type{Sub}) = (;topics = String[])
    PB.field_numbers(::Type{Sub}) = (;topics = 1)

    function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:Sub})
        topics = String[]
        while !PB.message_done(d)
            field_number, wire_type = PB.decode_tag(d)
            if field_number == 1
                PB.decode!(d, topics)
            else
                PB.skip(d, wire_type)
            end
        end
        return Sub(topics)
    end

    function PB.encode(e::PB.AbstractProtoEncoder, x::Sub)
        initpos = position(e.io)
        !isempty(x.topics) && PB.encode(e, 1, x.topics)
        return position(e.io) - initpos
    end
    function PB._encoded_size(x::Sub)
        encoded_size = 0
        !isempty(x.topics) && (encoded_size += PB._encoded_size(x.topics, 1))
        return encoded_size
    end

    # 订阅响应
    struct SubResponse
        success::Vector{String}     # 订阅成功
        fail::Vector{SubResponseFail}  # 订阅失败
        current::Vector{String}     # 当前订阅
    end
    PB.default_values(::Type{SubResponse}) = (;success = String[], fail = SubResponseFail[], current = String[])
    PB.field_numbers(::Type{SubResponse}) = (;success = 1, fail = 2, current = 3)

    function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:SubResponse})
        success = String[]
        fail = SubResponseFail[]
        current = String[]
        while !PB.message_done(d)
            field_number, wire_type = PB.decode_tag(d)
            if field_number == 1
                PB.decode!(d, success)
            elseif field_number == 2
                PB.decode!(d, fail)
            elseif field_number == 3
                PB.decode!(d, current)
            else
                PB.skip(d, wire_type)
            end
        end
        return SubResponse(success, fail, current)
    end

    function PB.encode(e::PB.AbstractProtoEncoder, x::SubResponse)
        initpos = position(e.io)
        !isempty(x.success) && PB.encode(e, 1, x.success)
        !isempty(x.fail) && PB.encode(e, 2, x.fail)
        !isempty(x.current) && PB.encode(e, 3, x.current)
        return position(e.io) - initpos
    end
    function PB._encoded_size(x::SubResponse)
        encoded_size = 0
        !isempty(x.success) && (encoded_size += PB._encoded_size(x.success, 1))
        !isempty(x.fail) && (encoded_size += PB._encoded_size(x.fail, 2))
        !isempty(x.current) && (encoded_size += PB._encoded_size(x.current, 3))
        return encoded_size
    end

    # 取消订阅请求 - 命令17
    struct Unsub
        topics::Vector{String}
    end
    PB.default_values(::Type{Unsub}) = (;topics = String[])
    PB.field_numbers(::Type{Unsub}) = (;topics = 1)

    function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:Unsub})
        topics = String[]
        while !PB.message_done(d)
            field_number, wire_type = PB.decode_tag(d)
            if field_number == 1
                PB.decode!(d, topics)
            else
                PB.skip(d, wire_type)
            end
        end
        return Unsub(topics)
    end

    function PB.encode(e::PB.AbstractProtoEncoder, x::Unsub)
        initpos = position(e.io)
        !isempty(x.topics) && PB.encode(e, 1, x.topics)
        return position(e.io) - initpos
    end
    function PB._encoded_size(x::Unsub)
        encoded_size = 0
        !isempty(x.topics) && (encoded_size += PB._encoded_size(x.topics, 1))
        return encoded_size
    end

    # 取消订阅响应
    struct UnsubResponse
        current::Vector{String}     # 当前订阅
    end
    PB.default_values(::Type{UnsubResponse}) = (;current = String[])
    PB.field_numbers(::Type{UnsubResponse}) = (;current = 3)

    function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:UnsubResponse})
        current = String[]
        while !PB.message_done(d)
            field_number, wire_type = PB.decode_tag(d)
            if field_number == 3
                PB.decode!(d, current)
            else
                PB.skip(d, wire_type)
            end
        end
        return UnsubResponse(current)
    end

    function PB.encode(e::PB.AbstractProtoEncoder, x::UnsubResponse)
        initpos = position(e.io)
        !isempty(x.current) && PB.encode(e, 3, x.current)
        return position(e.io) - initpos
    end
    function PB._encoded_size(x::UnsubResponse)
        encoded_size = 0
        !isempty(x.current) && (encoded_size += PB._encoded_size(x.current, 3))
        return encoded_size
    end

    # 推送通知 - 命令18
    struct Notification
        topic::String
        content_type::ContentType.T
        dispatch_type::DispatchType.T
        data::Vector{UInt8}
    end
    PB.default_values(::Type{Notification}) = (;topic = "", content_type = ContentType.CONTENT_UNDEFINED, dispatch_type = DispatchType.DISPATCH_UNDEFINED, data = UInt8[])
    PB.field_numbers(::Type{Notification}) = (;topic = 1, content_type = 2, dispatch_type = 3, data = 4)

    function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:Notification})
        topic = ""
        content_type = ContentType.CONTENT_UNDEFINED
        dispatch_type = DispatchType.DISPATCH_UNDEFINED
        data = UInt8[]
        while !PB.message_done(d)
            field_number, wire_type = PB.decode_tag(d)
            if field_number == 1
                topic = PB.decode(d, String)
            elseif field_number == 2
                content_type = PB.decode(d, ContentType.T)
            elseif field_number == 3
                dispatch_type = PB.decode(d, DispatchType.T)
            elseif field_number == 4
                data = PB.decode(d, Vector{UInt8})
            else
                PB.skip(d, wire_type)
            end
        end
        return Notification(topic, content_type, dispatch_type, data)
    end

    function PB.encode(e::PB.AbstractProtoEncoder, x::Notification)
        initpos = position(e.io)
        !isempty(x.topic) && PB.encode(e, 1, x.topic)
        x.content_type != ContentType.CONTENT_UNDEFINED && PB.encode(e, 2, x.content_type)
        x.dispatch_type != DispatchType.DISPATCH_UNDEFINED && PB.encode(e, 3, x.dispatch_type)
        !isempty(x.data) && PB.encode(e, 4, x.data)
        return position(e.io) - initpos
    end
    function PB._encoded_size(x::Notification)
        encoded_size = 0
        !isempty(x.topic) && (encoded_size += PB._encoded_size(x.topic, 1))
        x.content_type != ContentType.CONTENT_UNDEFINED && (encoded_size += PB._encoded_size(x.content_type, 2))
        x.dispatch_type != DispatchType.DISPATCH_UNDEFINED && (encoded_size += PB._encoded_size(x.dispatch_type, 3))
        !isempty(x.data) && (encoded_size += PB._encoded_size(x.data, 4))
        return encoded_size
    end

end # module