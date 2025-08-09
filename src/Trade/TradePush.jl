"""
Trade Push Event Handler Module

参照Python SDK的trade push事件处理机制，提供完整的交易推送事件处理。
对应Python版本的python/src/trade/push.rs
"""
module TradePush

    using ProtoBuf
    using ..TradeProtocol
    using ..Client
    using ..Config
    using ..Constant

    export Callbacks, PushEvent, handle_push_event!, subscribe, unsubscribe, PushOrderChanged

    # 推送事件基类
    abstract type PushEvent end

    """
    订单回报推送
    """
    struct PushOrderChanged <: PushEvent
        order_id::AbstractString
        status::Int32
        sub_status::Int32
        submitted_price::AbstractString
        submitted_quantity::Int64
        executed_quantity::Int64
        executed_price::AbstractString
        trigger_price::AbstractString
        msg::AbstractString
        tag::Int32
        triggered_at::Int64
        updated_at::Int64
        last_share::AbstractString
        last_price::AbstractString

        function PushOrderChanged(data::PushOrderChanged)
            new(
                data.order_id,
                data.status,
                data.sub_status,
                data.submitted_price,
                data.submitted_quantity,
                data.executed_quantity,
                data.executed_price,
                data.trigger_price,
                data.msg,
                data.tag,
                data.triggered_at,
                data.updated_at,
                data.last_share,
                data.last_price,
            )
        end
    end

    """
    回调函数存储结构
    参照Python版本的Callbacks结构
    """
    mutable struct Callbacks
        on_order_changed::Union{Function,Nothing}

        function Callbacks()
            new(nothing)
        end
    end

    """
    设置订单变更回调函数
    """
    function set_on_order_changed!(callbacks::Callbacks, callback::Function)
        callbacks.on_order_changed = callback
    end

    """
    处理推送事件
    参照Python版本的handle_push_event函数
    """
    function handle_push_event!(cb::Callbacks, n::Notification)
        if n.topic == "private" && n.content_type == CONTENT_PROTO
            if !isnothing(cb.on_order_changed)
                try
                    order_changed = PB.decode(PushOrderChanged(), n.data)
                    cb.on_order_changed(PushOrderChanged(order_changed))
                catch e
                    @error "订单变更回调函数执行失败" exception = e
                end
            end
        else
            @warn "未知的推送事件类型" n
        end
    end

end # module TradePush
