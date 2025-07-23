module TradeTypes

using Dates
using JSON3

export TopicType, Execution, OrderStatus, OrderSide, OrderType, OrderTag, TimeInForceType,
       TriggerStatus, OutsideRTH, Order, PushOrderChanged, MarginRatio, CommissionFreeStatus,
       DeductionStatus, ChargeCategoryCode, OrderHistoryDetail, OrderChargeFee, OrderChargeItem,
       OrderChargeDetail, OrderDetail, BalanceType, EstimateMaxPurchaseQuantityResponse,
       FrozenTransactionFee, CashInfo, AccountBalance, CashFlow, CashFlowDirection,
       FundPositionsResponse, FundPositionChannel, FundPosition, StockPositionsResponse,
       StockPositionChannel, StockPosition, SubmitOrderResponse

# Enums

"""
Topic type
"""
@enum TopicType begin
    Private = 0
end

"""
Order status
"""
@enum OrderStatus begin
    UnknownStatus = 0
    NotReported = 1
    ReplacedNotReported = 2
    ProtectedNotReported = 3
    VarianceNotReported = 4
    Cancelled = 5
    Replaced = 6
    PartiallyFilled = 7
    Filled = 8
    WaitToNew = 9
    New = 10
    WaitToReplace = 11
    PendingReplace = 12
    Rejected = 13
    WaitToCancel = 14
    PendingCancel = 15
    Expired = 16
    PartialWithdrawal = 17
    InitialNew = 18
    InitialReplace = 19
    InitialCancel = 20
end

"""
Order side
"""
@enum OrderSide begin
    UnknownSide = 0
    Buy = 1
    Sell = 2
end

"""
Order type
"""
@enum OrderType begin
    UnknownType = 0
    LO = 1      # Limit Order
    ELO = 2     # Enhanced Limit Order
    MO = 3      # Market Order
    AO = 4      # At-auction Order
    ALO = 5     # At-auction Limit Order
    ODD = 6     # Odd Lot Order
    LIT = 7     # Limit If Touched
    MIT = 8     # Market If Touched
    TSLPAMT = 9 # Trailing Stop Limit Amount
    TSLPPCT = 10 # Trailing Stop Limit Percent
    TSMAMT = 11 # Trailing Stop Market Amount
    TSMPCT = 12 # Trailing Stop Market Percent
    SLO = 13    # Stop Limit Order
    SLM = 14    # Stop Market Order
end

"""
Order tag
"""
@enum OrderTag begin
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
@enum TimeInForceType begin
    UnknownTIF = 0
    Day = 1
    GTC = 2     # Good Till Cancelled
    GTD = 3     # Good Till Date
end

"""
Trigger status
"""
@enum TriggerStatus begin
    UnknownTrigger = 0
    Deactive = 1
    Active = 2
    Released = 3
end

"""
Outside RTH (Regular Trading Hours)
"""
@enum OutsideRTH begin
    UnknownRTH = 0
    RTH = 1         # Regular Trading Hours
    PreRTH = 2      # Pre-market
    PostRTH = 3     # After-market
end

"""
Commission free status
"""
@enum CommissionFreeStatus begin
    UnknownCommission = 0
    NoneCommission = 1
    Calculated = 2
    PendingCommission = 3
end

"""
Deduction status
"""
@enum DeductionStatus begin
    UnknownDeduction = 0
    NoneDeduction = 1
    NoData = 2
    PendingDeduction = 3
    Done = 4
end

"""
Charge category code
"""
@enum ChargeCategoryCode begin
    UnknownCharge = 0
    Broker = 1
    ThirdParty = 2
end

"""
Balance type
"""
@enum BalanceType begin
    UnknownBalance = 0
    Cash = 1
    Stock = 2
    Fund = 3
end

"""
Cash flow direction
"""
@enum CashFlowDirection begin
    UnknownDirection = 0
    Out = 1
    In = 2
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
end

"""
Order information
"""
struct Order
    order_id::String
    status::OrderStatus
    stock_name::String
    quantity::Int64
    executed_quantity::Int64
    price::Union{Float64, Nothing}
    executed_price::Union{Float64, Nothing}
    submitted_at::DateTime
    side::OrderSide
    symbol::String
    order_type::OrderType
    last_done::Union{Float64, Nothing}
    trigger_price::Union{Float64, Nothing}
    msg::String
    tag::OrderTag
    time_in_force::TimeInForceType
    expire_date::Union{Date, Nothing}
    updated_at::Union{DateTime, Nothing}
    trigger_at::Union{DateTime, Nothing}
    trailing_amount::Union{Float64, Nothing}
    trailing_percent::Union{Float64, Nothing}
    limit_offset::Union{Float64, Nothing}
    trigger_status::TriggerStatus
    currency::String
    outside_rth::OutsideRTH
    remark::String
end

"""
Push order changed information
"""
struct PushOrderChanged
    side::OrderSide
    stock_name::String
    submitted_quantity::Float64
    symbol::String
    order_type::OrderType
    submitted_price::Float64
    executed_quantity::Float64
    executed_price::Union{Float64, Nothing}
    order_id::String
    currency::String
    status::OrderStatus
    submitted_at::DateTime
    updated_at::DateTime
    trigger_price::Union{Float64, Nothing}
    msg::String
    tag::OrderTag
    trigger_status::Union{TriggerStatus, Nothing}
    trigger_at::Union{DateTime, Nothing}
    trailing_amount::Union{Float64, Nothing}
    trailing_percent::Union{Float64, Nothing}
    limit_offset::Union{Float64, Nothing}
    account_no::String
    last_share::Union{Float64, Nothing}
    last_price::Union{Float64, Nothing}
    remark::String
    
    function PushOrderChanged(data::Dict)
        new(
            OrderSide(get(data, "side", 0)),
            get(data, "stock_name", ""),
            get(data, "submitted_quantity", 0.0),
            get(data, "symbol", ""),
            OrderType(get(data, "order_type", 0)),
            get(data, "submitted_price", 0.0),
            get(data, "executed_quantity", 0.0),
            get(data, "executed_price", nothing),
            get(data, "order_id", ""),
            get(data, "currency", ""),
            OrderStatus(get(data, "status", 0)),
            DateTime(get(data, "submitted_at", "1970-01-01T00:00:00Z")[1:19]),
            DateTime(get(data, "updated_at", "1970-01-01T00:00:00Z")[1:19]),
            get(data, "trigger_price", nothing),
            get(data, "msg", ""),
            OrderTag(get(data, "tag", 0)),
            get(data, "trigger_status", nothing) |> x -> isnothing(x) ? nothing : TriggerStatus(x),
            get(data, "trigger_at", nothing) |> x -> isnothing(x) ? nothing : DateTime(x[1:19]),
            get(data, "trailing_amount", nothing),
            get(data, "trailing_percent", nothing),
            get(data, "limit_offset", nothing),
            get(data, "account_no", ""),
            get(data, "last_share", nothing),
            get(data, "last_price", nothing),
            get(data, "remark", "")
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
    status::OrderStatus
    msg::String
    time::DateTime
end

"""
Order detail
"""
struct OrderDetail
    order_id::String
    status::OrderStatus
    stock_name::String
    quantity::Int64
    executed_quantity::Int64
    price::Union{Float64, Nothing}
    executed_price::Union{Float64, Nothing}
    submitted_at::DateTime
    side::OrderSide
    symbol::String
    order_type::OrderType
    last_done::Union{Float64, Nothing}
    trigger_price::Union{Float64, Nothing}
    msg::String
    tag::OrderTag
    time_in_force::TimeInForceType
    expire_date::Union{Date, Nothing}
    updated_at::Union{DateTime, Nothing}
    trigger_at::Union{DateTime, Nothing}
    trailing_amount::Union{Float64, Nothing}
    trailing_percent::Union{Float64, Nothing}
    limit_offset::Union{Float64, Nothing}
    trigger_status::TriggerStatus
    currency::String
    outside_rth::OutsideRTH
    remark::String
    free_status::CommissionFreeStatus
    free_amount::Union{Float64, Nothing}
    free_currency::Union{String, Nothing}
    deductions_status::DeductionStatus
    deductions_amount::Union{Float64, Nothing}
    deductions_currency::Union{String, Nothing}
    platform_deducted_status::DeductionStatus
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
end

"""
Frozen transaction fee
"""
struct FrozenTransactionFee
    currency::String
    frozen_transaction_fee::Float64
    
    function FrozenTransactionFee(data::Dict)
        new(
            get(data, "currency", ""),
            get(data, "frozen_transaction_fee", 0.0)
        )
    end
end

"""
Submit order response
"""
struct SubmitOrderResponse
    order_id::String
    
    function SubmitOrderResponse(data::Dict)
        new(get(data, "order_id", ""))
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
    currency::String
    
    function CashInfo(data::Dict)
        new(
            get(data, "withdraw_cash", 0.0),
            get(data, "available_cash", 0.0),
            get(data, "frozen_cash", 0.0),
            get(data, "settling_cash", 0.0),
            get(data, "currency", "")
        )
    end
end

"""
Account balance
"""
struct AccountBalance
    total_cash::Float64
    max_finance_amount::Float64
    remaining_finance_amount::Float64
    risk_level::Int32
    margin_call::Float64
    currency::String
    cash_infos::Vector{CashInfo}
    net_assets::Float64
    init_margin::Float64
    maintenance_margin::Float64
    buy_power::Float64
    frozen_transaction_fees::Vector{FrozenTransactionFee}
    
    function AccountBalance(data::Dict)
        new(
            get(data, "total_cash", 0.0),
            get(data, "max_finance_amount", 0.0),
            get(data, "remaining_finance_amount", 0.0),
            get(data, "risk_level", 0),
            get(data, "margin_call", 0.0),
            get(data, "currency", ""),
            [CashInfo(info) for info in get(data, "cash_infos", [])],
            get(data, "net_assets", 0.0),
            get(data, "init_margin", 0.0),
            get(data, "maintenance_margin", 0.0),
            get(data, "buy_power", 0.0),
            [FrozenTransactionFee(fee) for fee in get(data, "frozen_transaction_fees", [])]
        )
    end
end

"""
Cash flow
"""
struct CashFlow
    transaction_flow_name::String
    direction::CashFlowDirection
    business_type::BalanceType
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
    current_net_asset_value::Float64
    net_asset_value_day::DateTime
    symbol_name::String
    currency::String
    cost_net_asset_value::Float64
    holding_units::Float64
    
    function FundPosition(data::Dict)
        new(
            get(data, "symbol", ""),
            get(data, "current_net_asset_value", 0.0),
            DateTime(get(data, "net_asset_value_day", "1970-01-01T00:00:00Z")[1:19]),
            get(data, "symbol_name", ""),
            get(data, "currency", ""),
            get(data, "cost_net_asset_value", 0.0),
            get(data, "holding_units", 0.0)
        )
    end
end

"""
Fund position channel
"""
struct FundPositionChannel
    account_channel::String
    positions::Vector{FundPosition}
    
    function FundPositionChannel(data::Dict)
        new(
            get(data, "account_channel", ""),
            [FundPosition(pos) for pos in get(data, "positions", [])]
        )
    end
end

"""
Fund positions response
"""
struct FundPositionsResponse
    channels::Vector{FundPositionChannel}
    
    function FundPositionsResponse(data::Dict)
        new([FundPositionChannel(ch) for ch in get(data, "channels", [])])
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

end # module TradeTypes