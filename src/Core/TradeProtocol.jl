# 基于官方 trade.proto 的Julia实现
# 专门用于交易WebSocket协议的Protocol Buffer消息

module TradeProtocol

    import ProtoBuf as PB
    using ProtoBuf: OneOf
    using EnumX
    using Dates
    using JSON3
    using ..QuoteProtocol: SecurityBoard
    using ..Constant

    export Command, DispatchType, ContentType, Sub, SubResponse, SubResponseFail, Unsub, UnsubResponse, Notification, OrderType,
           OrderStatus, TopicType, Execution, OrderSide, OrderTag, TimeInForceType, TriggerStatus, OutsideRTH, Order, PushOrderChanged,
           MarginRatio, CommissionFreeStatus, DeductionStatus, ChargeCategoryCode, OrderHistoryDetail, OrderChargeFee, OrderChargeItem,
           OrderChargeDetail, OrderDetail, BalanceType, EstimateMaxPurchaseQuantityResponse, FrozenTransactionFee, CashInfo,
           AccountBalance, CashFlow, CashFlowDirection, FundPositionsResponse, FundPositionChannel, FundPosition, StockPositionsResponse,
           StockPositionChannel, StockPosition, SubmitOrderResponse, ExecutionResponse, TodayExecutionResponse, RiskLevel,
           SubmitOrderOptions, ReplaceOrderOptions, GetHistoryExecutionsOptions, GetTodayExecutionsOptions, GetHistoryOrdersOptions,
           GetTodayOrdersOptions, GetCashFlowOptions, GetFundPositionsOptions, GetStockPositionsOptions, EstimateMaxPurchaseQuantityOptions,
           PushEvent

    # --- Order Type Enum ---
    @enumx OrderType begin
        UNKNOWN = 0
        LO          # 限价单 (HK, US)
        ELO         # 增强限价单 (HK)
        MO          # 市价单 (HK, US)
        AO          # 竞价市价单 (HK)
        ALO         # 竞价限价单 (HK)
        ODD         # 碎股单挂单 (HK)
        LIT         # 触价限价单 (HK, US)
        MIT         # 触价市价单 (HK, US)
        TSLPAMT     # 跟踪止损限价单 (跟踪金额) (HK, US)
        TSLPPCT     # 跟踪止损限价单 (跟踪涨跌幅) (HK, US)
        SLO         # 特殊限价单 (HK)
    end

    # --- Order Status Enum ---
    @enumx OrderStatus begin
        NotReported             # 待提交
        ReplacedNotReported     # 待提交 (改单成功)
        ProtectedNotReported    # 待提交 (保价订单)
        VarietiesNotReported    # 待提交 (条件单)
        Filled                  # 已成交
        WaitToNew               # 已提待报
        New                     # 已委托
        WaitToReplace           # 修改待报
        PendingReplace          # 待修改
        Replaced                # 已修改
        PartialFilled           # 部分成交
        WaitToCancel            # 撤销待报
        PendingCancel           # 待撤回
        Rejected                # 已拒绝
        Canceled                # 已撤单
        Expired                 # 已过期
        PartialWithdrawal       # 部分撤单
    end

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
                PB.decode!(d, PB.BufferedVector(topics))
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
                PB.decode!(d, PB.BufferedVector(success))
            elseif field_number == 2
                PB.decode!(d, PB.BufferedVector(fail))
            elseif field_number == 3
                PB.decode!(d, PB.BufferedVector(current))
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
                PB.decode!(d, PB.BufferedVector(topics))
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
                PB.decode!(d, PB.BufferedVector(current))
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

    """
    Topic type
    """
    @enumx TopicType begin
        Private = 0
    end

    """
    Order side
    """
    @enumx OrderSide begin
        UnknownSide = 0
        Buy = 1
        Sell = 2
    end

    """
    Order tag
    """
    @enumx OrderTag begin
        UnknownTag = 0
        Normal = 1
        LongTerm = 2
        Grey = 3
        MarginCall = 4
        Offline = 5
        Creditor = 6
        Debtor = 7
        NonExercise = 8
        AllocatedSub = 9
    end

    """
    Time in force type
    """
    @enumx TimeInForceType begin
        UnknownTIF = 0
        Day = 1
        GTC = 2     # Good Till Cancelled
        GTD = 7     # Good Till Date
    end

    """
    Trigger price type
    """
    @enumx TriggerPriceType begin
        Unknown = 0
        LIT = 1
        MIT = 2
    end

    """
    Trigger status
    """
    @enumx TriggerStatus begin
        UnknownTrigger = 0
        Deactive = 1
        Active = 2
        Released = 3
    end

    """
    Enable or disable outside regular trading hours
    """
    @enumx OutsideRTH begin
        RTH_ONLY
        ANY_TIME
        OVERNIGHT
    end

    """
    Commission free status
    """
    @enumx CommissionFreeStatus begin
        UnknownCommission = 0
        NoneCommission = 1
        Calculated = 2
        PendingCommission = 3
    end

    """
    Deduction status
    """
    @enumx DeductionStatus begin
        UnknownDeduction = 0
        NoneDeduction = 1
        NoData = 2
        PendingDeduction = 3
        Done = 4
    end

    """
    Charge category code
    """
    @enumx ChargeCategoryCode begin
        UnknownCharge = 0
        Broker = 1
        ThirdParty = 2
    end

    """
    Balance type
    """
    @enumx BalanceType begin
        UnknownBalance = 0
        Cash = 1
        Stock = 2
        Fund = 3
    end

    """
    Cash flow direction
    """
    @enumx CashFlowDirection begin
        UnknownDirection = 0
        Out = 1
        In = 2
    end

    """
    Risk level
    """
    @enumx RiskLevel begin
        Safe = 0
        Moderate = 1
        Warning = 2
        Danger = 3
    end

    # Data Structures

    """
    Execution information
    """
    struct Execution
        order_id::String
        trade_id::String
        symbol::String
        trade_done_at::DateTime
        quantity::Int64
        price::Float64

        function Execution(data::Dict)
            new(
                get(data, "order_id", ""),
                get(data, "trade_id", ""),
                get(data, "symbol", ""),
                DateTime(get(data, "trade_done_at", "1970-01-01T00:00:00Z")[1:19]),
                get(data, "quantity", 0),
                get(data, "price", 0.0)
            )
        end
    end

    """
    Order information
    """
    struct Order
        order_id::String
        status::OrderStatus.T
        stock_name::String
        quantity::Int64
        executed_quantity::Int64
        price::Union{Float64, Nothing}
        executed_price::Union{Float64, Nothing}
        submitted_at::DateTime
        side::OrderSide.T
        symbol::String
        order_type::OrderType.T
        last_done::Union{Float64, Nothing}
        trigger_price::Union{Float64, Nothing}
        msg::String
        tag::OrderTag.T
        time_in_force::TimeInForceType.T
        expire_date::Union{Date, Nothing}
        updated_at::Union{DateTime, Nothing}
        trigger_at::Union{DateTime, Nothing}
        trailing_amount::Union{Float64, Nothing}
        trailing_percent::Union{Float64, Nothing}
        limit_offset::Union{Float64, Nothing}
        trigger_status::TriggerStatus.T
        currency::String
        outside_rth::OutsideRTH.T
        remark::String

        function Order(data::Dict)
            new(
                get(data, "order_id", ""),
                OrderStatus.T(get(data, "status", 0)),
                get(data, "stock_name", ""),
                get(data, "quantity", 0),
                get(data, "executed_quantity", 0),
                get(data, "price", nothing),
                get(data, "executed_price", nothing),
                unix2datetime(get(data, "submitted_at", 0)),
                OrderSide.T(get(data, "side", 0)),
                get(data, "symbol", ""),
                OrderType.T(get(data, "order_type", 0)),
                get(data, "last_done", nothing),
                get(data, "trigger_price", nothing),
                get(data, "msg", ""),
                OrderTag.T(get(data, "tag", 0)),
                TimeInForceType.T(get(data, "time_in_force", 0)),
                get(data, "expire_date", nothing) |> d -> isnothing(d) ? nothing : Date(d),
                get(data, "updated_at", nothing) |> t -> isnothing(t) ? nothing : unix2datetime(t),
                get(data, "trigger_at", nothing) |> t -> isnothing(t) ? nothing : unix2datetime(t),
                get(data, "trailing_amount", nothing),
                get(data, "trailing_percent", nothing),
                get(data, "limit_offset", nothing),
                TriggerStatus.T(get(data, "trigger_status", 0)),
                get(data, "currency", ""),
                OutsideRTH.T(get(data, "outside_rth", 0)),
                get(data, "remark", "")
            )
        end
    end

    """
    Push order changed information
    """
    struct PushOrderChanged
        side::OrderSide.T
        stock_name::String
        submitted_quantity::Union{Int64, Nothing}
        symbol::String
        order_type::OrderType.T
        submitted_price::Union{Float64, Nothing}
        executed_quantity::Union{Int64, Nothing}
        executed_price::Union{Float64, Nothing}
        order_id::String
        currency::String
        status::OrderStatus.T
        submitted_at::Union{DateTime, Nothing}
        updated_at::Union{DateTime, Nothing}
        trigger_price::Union{Float64, Nothing}
        msg::String
        tag::OrderTag.T
        trigger_status::Union{TriggerStatus.T, Nothing}
        trigger_at::Union{DateTime, Nothing}
        trailing_amount::Union{Float64, Nothing}
        trailing_percent::Union{Float64, Nothing}
        limit_offset::Union{Float64, Nothing}
        account_no::String
        last_share::Union{Int64, Nothing}
        last_price::Union{Float64, Nothing}
        remark::String

        function PushOrderChanged(data::Dict)
            side_str = get(data, "side", "Buy")
            side = side_str == "Buy" ? Buy : Sell

            stock_name = get(data, "stock_name", "")
            submitted_quantity = haskey(data, "submitted_quantity") ? parse(Int64, data["submitted_quantity"]) : nothing
            symbol = get(data, "symbol", "")

            order_type_str = get(data, "order_type", "LO")
            order_type = getfield(OrderType, Symbol(order_type_str))

            submitted_price = haskey(data, "submitted_price") ? parse(Float64, data["submitted_price"]) : nothing
            executed_quantity = haskey(data, "executed_quantity") ? parse(Int64, data["executed_quantity"]) : nothing
            executed_price = haskey(data, "executed_price") ? parse(Float64, data["executed_price"]) : nothing
            order_id = get(data, "order_id", "")
            currency = get(data, "currency", "")

            status_str = get(data, "status", "NewStatus")
            status = getfield(OrderStatus, Symbol(status_str))

            submitted_at = haskey(data, "submitted_at") ? unix2datetime(parse(Int64, data["submitted_at"])) : nothing
            updated_at = haskey(data, "updated_at") ? unix2datetime(parse(Int64, data["updated_at"])) : nothing
            trigger_price = haskey(data, "trigger_price") ? parse(Float64, data["trigger_price"]) : nothing
            msg = get(data, "msg", "")

            tag_str = get(data, "tag", "Normal")
            tag_map = Dict("Normal" => Normal, "GTC" => LongTerm, "Grey" => Grey)
            tag = get(tag_map, tag_str, Normal)

            trigger_status_str = get(data, "trigger_status", "DEACTIVE")
            trigger_status_map = Dict("NOT_USED" => Deactive, "DEACTIVE" => Deactive, "ACTIVE" => Active, "RELEASED" => Released)
            trigger_status = get(trigger_status_map, trigger_status_str, Deactive)

            trigger_at = haskey(data, "trigger_at") ? unix2datetime(parse(Int64, data["trigger_at"])) : nothing
            trailing_amount = haskey(data, "trailing_amount") ? parse(Float64, data["trailing_amount"]) : nothing
            trailing_percent = haskey(data, "trailing_percent") ? parse(Float64, data["trailing_percent"]) : nothing
            limit_offset = haskey(data, "limit_offset") ? parse(Float64, data["limit_offset"]) : nothing
            account_no = get(data, "account_no", "")
            last_share = haskey(data, "last_share") ? parse(Int64, data["last_share"]) : nothing
            last_price = haskey(data, "last_price") ? parse(Float64, data["last_price"]) : nothing
            remark = get(data, "remark", "")

            new(
                side,
                stock_name,
                submitted_quantity,
                symbol,
                order_type,
                submitted_price,
                executed_quantity,
                executed_price,
                order_id,
                currency,
                status,
                submitted_at,
                updated_at,
                trigger_price,
                msg,
                tag,
                trigger_status,
                trigger_at,
                trailing_amount,
                trailing_percent,
                limit_offset,
                account_no,
                last_share,
                last_price,
                remark
            )
        end
    end

    """
    Margin ratio information
    """
    struct MarginRatio
        im_factor::Float64
        mm_factor::Float64
        fm_factor::Float64

        function MarginRatio(data::Dict)
            new(
                parse(Float64, get(data, "im_factor", "0.0")),
                parse(Float64, get(data, "mm_factor", "0.0")),
                parse(Float64, get(data, "fm_factor", "0.0"))
            )
        end
    end

    function Base.show(io::IO, r::MarginRatio)
        print(io, "MarginRatio(im_factor: $(r.im_factor), mm_factor: $(r.mm_factor), fm_factor: $(r.fm_factor))")
    end

    """
    Order charge fee
    """
    struct OrderChargeFee
        code::String
        name::String
        fee::Float64
        currency::String
    end

    """
    Order charge item
    """
    struct OrderChargeItem
        code::String
        name::String
        fees::Vector{OrderChargeFee}
    end


    """
    Order charge detail
    """
    struct OrderChargeDetail
        total_charges::Float64
        currency::String
        items::Vector{OrderChargeItem}
    end

    """
    Order history detail
    """
    struct OrderHistoryDetail
        price::Float64
        quantity::Int64
        status::OrderStatus.T
        msg::String
        time::DateTime
    end

    """
    Order detail
    """
    struct OrderDetail
        order_id::String
        status::OrderStatus.T
        stock_name::String
        quantity::Int64
        executed_quantity::Int64
        price::Union{Float64, Nothing}
        executed_price::Union{Float64, Nothing}
        submitted_at::DateTime
        side::OrderSide.T
        symbol::String
        order_type::OrderType.T
        last_done::Union{Float64, Nothing}
        trigger_price::Union{Float64, Nothing}
        msg::String
        tag::OrderTag.T
        time_in_force::TimeInForceType.T
        expire_date::Union{Date, Nothing}
        updated_at::Union{DateTime, Nothing}
        trigger_at::Union{DateTime, Nothing}
        trailing_amount::Union{Float64, Nothing}
        trailing_percent::Union{Float64, Nothing}
        limit_offset::Union{Float64, Nothing}
        trigger_status::TriggerStatus.T
        currency::String
        outside_rth::OutsideRTH.T
        remark::String
        free_status::CommissionFreeStatus.T
        free_amount::Union{Float64, Nothing}
        free_currency::Union{String, Nothing}
        deductions_status::DeductionStatus.T
        deductions_amount::Union{Float64, Nothing}
        deductions_currency::Union{String, Nothing}
        platform_deducted_status::DeductionStatus.T
        platform_deducted_amount::Union{Float64, Nothing}
        platform_deducted_currency::Union{String, Nothing}
        history::Vector{OrderHistoryDetail}
        charge_detail::OrderChargeDetail
    end

    """
    Estimate max purchase quantity response
    """
    struct EstimateMaxPurchaseQuantityResponse
        cash_max_qty::Int64
        margin_max_qty::Int64

        function EstimateMaxPurchaseQuantityResponse(data::Dict)
            new(
                get(data, "cash_max_qty", 0),
                get(data, "margin_max_qty", 0)
            )
        end
    end

    """
    Frozen transaction fee
    """
    struct FrozenTransactionFee
        currency::Currency.T
        frozen_transaction_fee::Float64
        
        function FrozenTransactionFee(data::Dict)
            new(
                getfield(Currency, Symbol(get(data, "currency", "HKD"))),
                get(data, "frozen_transaction_fee", 0.0)
            )
        end
    end

    function Base.show(io::IO, fee::FrozenTransactionFee)
        print(io, "    - Currency: ", fee.currency, ", Fee: ", fee.frozen_transaction_fee)
    end

    """
    Submit order response
    """
    struct SubmitOrderResponse
        order_id::String
        
        function SubmitOrderResponse(data::Dict)
            new(get(data, :order_id, ""))
        end
    end

    """
    Cash info
    """
    struct CashInfo
        withdraw_cash::Float64
        available_cash::Float64
        frozen_cash::Float64
        settling_cash::Float64
        currency::Currency.T
        
        function CashInfo(data::Dict)
            new(
                get(data, "withdraw_cash", 0.0),
                get(data, "available_cash", 0.0),
                get(data, "frozen_cash", 0.0),
                get(data, "settling_cash", 0.0),
                getfield(Currency, Symbol(get(data, "currency", "HKD")))
            )
        end
    end

    function Base.show(io::IO, info::CashInfo)
        println(io, "    - Currency: ", info.currency)
        println(io, "      Available: ", info.available_cash)
        println(io, "      Withdrawable: ", info.withdraw_cash)
        println(io, "      Frozen: ", info.frozen_cash)
        print(io,   "      Settling: ", info.settling_cash)
    end

    """
    Account balance
    """
    struct AccountBalance
        total_cash::Float64
        max_finance_amount::Float64
        remaining_finance_amount::Float64
        risk_level::RiskLevel.T
        margin_call::Float64
        currency::Currency.T
        cash_infos::Vector{CashInfo}
        net_assets::Float64
        init_margin::Float64
        maintenance_margin::Float64
        buy_power::Float64
        frozen_transaction_fees::Vector{FrozenTransactionFee}
        market::Union{Market.T,Nothing}

        function AccountBalance(data::Dict)
            new(
                get(data, "total_cash", 0.0),
                get(data, "max_finance_amount", 0.0),
                get(data, "remaining_finance_amount", 0.0),
                RiskLevel.T(get(data, "risk_level", 0)),
                get(data, "margin_call", 0.0),
                getfield(Currency, Symbol(get(data, "currency", "HKD"))),
                [CashInfo(info) for info in get(data, "cash_infos", [])],
                get(data, "net_assets", 0.0),
                get(data, "init_margin", 0.0),
                get(data, "maintenance_margin", 0.0),
                get(data, "buy_power", 0.0),
                [FrozenTransactionFee(fee) for fee in get(data, "frozen_transaction_fees", [])],
                haskey(data, "market") ? getfield(Market, Symbol(uppercase(data["market"]))) : nothing
            )
        end
    end

    function Base.show(io::IO, balance::AccountBalance)
        print(io, "Account Balance (", balance.currency)
        if !isnothing(balance.market)
            print(io, ", Market: ", balance.market)
        end
        println(io, "):")
        println(io, "  Net Assets: ", balance.net_assets)
        println(io, "  Total Cash: ", balance.total_cash)
        println(io, "  Buy Power: ", balance.buy_power)
        println(io, "  Risk Level: ", balance.risk_level)
        println(io, "  Margin Call: ", balance.margin_call)
        println(io, "  Initial Margin: ", balance.init_margin)
        println(io, "  Maintenance Margin: ", balance.maintenance_margin)
        println(io, "  Max Finance Amount: ", balance.max_finance_amount)
        println(io, "  Remaining Finance Amount: ", balance.remaining_finance_amount)
        
        println(io, "\n  Cash Details:")
        for info in balance.cash_infos
            println(io, info)
        end

        if !isempty(balance.frozen_transaction_fees)
            println(io, "\n  Frozen Transaction Fees:")
            for fee in balance.frozen_transaction_fees
                println(io, fee)
            end
        end
    end

    """
    Cash flow
    """
    struct CashFlow
        transaction_flow_name::String
        direction::CashFlowDirection.T
        business_type::BalanceType.T
        balance::Float64
        currency::String
        business_time::DateTime
        symbol::Union{String, Nothing}
        description::String
        
        function CashFlow(data::Dict)
            new(
                get(data, "transaction_flow_name", ""),
                CashFlowDirection(get(data, "direction", 0)),
                BalanceType(get(data, "business_type", 0)),
                get(data, "balance", 0.0),
                get(data, "currency", ""),
                DateTime(get(data, "business_time", "1970-01-01T00:00:00Z")[1:19]),
                get(data, "symbol", nothing),
                get(data, "description", "")
            )
        end
    end

    """
    Fund position
    """
    struct FundPosition
        symbol::String
        symbol_name::String
        currency::String
        holding_units::String
        current_net_asset_value::String
        cost_net_asset_value::String
        net_asset_value_day::String

        function FundPosition(data::Dict)
            new(
                get(data, "symbol", ""),
                get(data, "symbol_name", ""),
                get(data, "currency", ""),
                get(data, "holding_units", "0"),
                get(data, "current_net_asset_value", "0"),
                get(data, "cost_net_asset_value", "0"),
                get(data, "net_asset_value_day", "")
            )
        end
    end

    """
    Fund position channel
    """
    struct FundPositionChannel
        account_channel::String
        fund_info::Vector{FundPosition}
        
        function FundPositionChannel(data::Dict)
            new(
                get(data, "account_channel", ""),
                [FundPosition(pos) for pos in get(data, "fund_info", [])]
            )
        end
    end

    """
    Fund positions response
    """
    struct FundPositionsResponse
        list::Vector{FundPositionChannel}
        
        function FundPositionsResponse(data::Dict)
            new([FundPositionChannel(ch) for ch in get(data, "list", [])])
        end
    end

    """
    Stock position
    """
    struct StockPosition
        symbol::String
        symbol_name::String
        quantity::Float64
        available_quantity::Float64
        currency::String
        cost_price::Float64
        market::String  # 对应Python版本的Market类型
        init_quantity::Union{Float64, Nothing}
        
        function StockPosition(data::Dict)
            new(
                get(data, "symbol", ""),
                get(data, "symbol_name", ""),
                get(data, "quantity", 0.0),
                get(data, "available_quantity", 0.0),
                get(data, "currency", ""),
                get(data, "cost_price", 0.0),
                get(data, "market", ""),
                get(data, "init_quantity", nothing)
            )
        end
    end

    """
    Stock position channel
    """
    struct StockPositionChannel
        account_channel::String
        positions::Vector{StockPosition}
        
        function StockPositionChannel(data::Dict)
            new(
                get(data, "account_channel", ""),
                [StockPosition(pos) for pos in get(data, "positions", [])]
            )
        end
    end

    """
    Stock positions response
    """
    struct StockPositionsResponse
        channels::Vector{StockPositionChannel}
        
        function StockPositionsResponse(data::Dict)
            new([StockPositionChannel(ch) for ch in get(data, "channels", [])])
        end
    end

    """
    Today execution response
    """
    struct TodayExecutionResponse
        trades::Vector{Execution}
        
        function TodayExecutionResponse(data::Dict)
            executions = []
            if haskey(data, "trades")
                for trade_data in data["trades"]
                    execution = Execution(
                        get(trade_data, "order_id", ""),
                        get(trade_data, "trade_id", ""),
                        get(trade_data, "symbol", ""),
                        DateTime(get(trade_data, "trade_done_at", "1970-01-01T00:00:00Z")[1:19]),
                        get(trade_data, "quantity", 0),
                        get(trade_data, "price", 0.0)
                    )
                    push!(executions, execution)
                end
            end
            new(executions)
        end
    end

    """
    History execution response
    """
    struct ExecutionResponse
        trades::Vector{Execution}
        has_more::Bool
        
        function ExecutionResponse(data::Dict)
            executions = []
            if haskey(data, "trades")
                for trade_data in data["trades"]
                    execution = Execution(
                        get(trade_data, "order_id", ""),
                        get(trade_data, "trade_id", ""),
                        get(trade_data, "symbol", ""),
                        DateTime(get(trade_data, "trade_done_at", "1970-01-01T00:00:00Z")[1:19]),
                        get(trade_data, "quantity", 0),
                        get(trade_data, "price", 0.0)
                    )
                    push!(executions, execution)
                end
            end
            new(executions, get(data, "has_more", false))
        end
    end

    # --- Request Option Structs ---

    Base.@kwdef struct SubmitOrderOptions
        symbol::String
        order_type::OrderType.T
        side::OrderSide.T
        submitted_quantity::Int64
        time_in_force::TimeInForceType.T        # 订单有效期类型, Day - 当日有效, GTC - 撤单前有效, GTD - 到期前有效
        expire_date::Union{String,Nothing} = nothing  # 到期日, GTD 订单必填, format: YYYY-MM-DD
        submitted_price::Union{Float64,Nothing} = nothing
        remark::Union{String,Nothing} = nothing     # 备注 (最大 64 字符)
        trigger_price::Union{Float64,Nothing} = nothing     # 触发价格，例如：388.5, LIT / MIT 订单必填
        trigger_price_type::Union{TriggerPriceType.T,Nothing} = nothing
        limit_offset::Union{Float64,Nothing} = nothing      # 指定价差，例如 "1.2" 表示价差1.2USD(如果是美股), TSLPAMT/TSLPPCT 订单必填
        trailing_amount::Union{Float64,Nothing} = nothing   # 跟踪金额, TSLPAMT订单必填
        trailing_percent::Union{Float64,Nothing} = nothing  # 跟踪涨跌幅，单位为百分比，例如 "2.5" 表示 "2.5%", TSLPPCT 订单必填
        outside_rth::Union{String,Nothing} = nothing  # 是否允许盘前盘后，美股必填, RTH_ONLY - 不允许盘前盘后, ANY_TIME - 允许盘前盘后, OVERNIGHT - 夜盘
    end

    Base.@kwdef struct ReplaceOrderOptions
        order_id::String
        submitted_quantity::Int
        submitted_price::Union{Float64,Nothing} = nothing
    end

    Base.@kwdef struct GetHistoryExecutionsOptions
        symbol::Union{String,Nothing} = nothing
        start_at::Union{Date,Nothing} = nothing
        end_at::Union{Date,Nothing} = nothing
    end

    Base.@kwdef struct GetTodayExecutionsOptions
        symbol::Union{String,Nothing} = nothing
    end

    Base.@kwdef struct GetHistoryOrdersOptions
        symbol::Union{String,Nothing} = nothing
        status::Union{Vector{OrderStatus.T},Nothing} = nothing
        side::Union{OrderSide.T,Nothing} = nothing
        start_at::Union{Date,Nothing} = nothing
        end_at::Union{Date,Nothing} = nothing
    end

    Base.@kwdef struct GetTodayOrdersOptions
        symbol::Union{String,Nothing} = nothing
        status::Union{Vector{OrderStatus.T},Nothing} = nothing
        side::Union{OrderSide.T,Nothing} = nothing
    end

    Base.@kwdef struct GetCashFlowOptions
        start_time::Int64
        end_time::Int64
        business_type::Union{Vector{BalanceType.T},Nothing} = nothing
        symbol::Union{String,Nothing} = nothing
        page::Union{Int,Nothing} = nothing
        size::Union{Int,Nothing} = nothing
    end

    Base.@kwdef struct GetFundPositionsOptions
        symbol::Union{Vector{String},Nothing} = nothing
    end

    Base.@kwdef struct GetStockPositionsOptions
        symbol::Union{String,Nothing} = nothing
    end

    Base.@kwdef struct EstimateMaxPurchaseQuantityOptions
        symbol::String
        order_type::OrderType.T
        side::OrderSide.T
        price::Union{Float64,Nothing} = nothing
    end

    # --- Push Event Types ---
    struct PushEvent
        topic::TopicType.T
        data::Any
    end

end # module
