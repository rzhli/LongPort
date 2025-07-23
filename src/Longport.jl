module Longport

using HTTP, JSON3, Dates, URIs, SHA, TOML

# Include modules following Python SDK structure
include("Core/Constant.jl")
include("Core/ControlProtocol.jl")
include("Core/QuoteProtocol.jl")
include("Core/TradeProtocol.jl")
include("Core/Utils.jl")
include("Core/Cache.jl")
include("Config.jl")
include("Quote/QuoteTypes.jl")
include("Quote/Push.jl")
include("Trade/Types.jl")
include("Client.jl")
include("Quote/Quote.jl")
include("Trade/Trade.jl")

# Use modules
using .Constant
using .ControlProtocol
using .QuoteProtocol
using .TradeProtocol
using .Utils
using .Cache
using .Config
using .QuoteTypes
using .Push
using .TradeTypes
using .Client
using .Quote
using .Trade 

# Core exception type - following Python SDK OpenApiException
struct LongportException <: Exception
    code::Union{Int, Nothing}
    trace_id::Union{String, Nothing}
    message::String
    
    function LongportException(code::Union{Int, Nothing}, trace_id::Union{String, Nothing}, message::String)
        new(code, trace_id, message)
    end
    
    function LongportException(message::String)
        new(nothing, nothing, message)
    end
end
function Base.show(io::IO, e::LongportException)
    if !isnothing(e.code)
        print(io, "LongportException: (code=$(e.code), trace_id=$(e.trace_id)) $(e.message)")
    else
        print(io, "LongportException: $(e.message)")
    end
end

# Main exports - following Python SDK structure
export 

    # 各模块
    Config, 
    # QuoteProtocol, Client, Quote, TradeTypes, QuoteTypes,
    
    # Exception
    LongportException,

    # Quote模块结构体类型、枚举类型及函数
    QuoteContext,                           # 结构体类型Struct及函数
    
    get_quote, connect!, disconnect!, subscribe, unsubscribe, static_info,          
    candlesticks, option_quote, warrant_quote, depth, brokers, participants,         # 函数
    set_on_brokers, set_on_trades, set_on_candlestick, set_on_quote, set_on_depth, 
    
    # QuoteProtocol模块结构体类型、枚举类型及函数
    CandlePeriod, TradeSession,                                    # 枚举类型
    
    TradeContext,

    # Utils模块
    to_namedtuple,

    # Core Enums and Types
    Language, Market, PushCandlestickMode,
    
    # Quote Enums and Types
    TradeStatus, TradeSessions, SecurityBoard,
    WarrantType, WarrantSortBy, SortOrderType,
    SubType, AdjustType,
    
    # Quote Data structures (QuoteProtocol模块)
    PushQuote, SecurityQuote, SecurityStaticInfo, SecurityDepth, Depth, Brokers,
    Candlestick, QuoteTrade, IntradayLine, OrderBook, RealtimeQuote,
    PushDepth, PushBrokers, PushTransaction, PushCandlestick,
    WarrantInfo, IssuerInfo, MarketTradingSession, TradingSessionInfo,
    OptionQuote, OptionChainDateStrikeInfo, StrikePriceInfo,
    
    # Trade Enums and Types
    TopicType, OrderStatus, OrderSide, OrderType, OrderTag, TimeInForceType,
    TriggerStatus, OutsideRTH, CommissionFreeStatus, DeductionStatus,
    ChargeCategoryCode, BalanceType,
    
    # Trade Enum Values
    Private,

    # OrderStatus values
    NotReported, ReplacedNotReported, ProtectedNotReported, VarianceNotReported,
    Cancelled, Replaced, PartiallyFilled, Filled, WaitToNew, New, WaitToReplace,
    PendingReplace, Rejected, WaitToCancel, PendingCancel, Expired, PartialWithdrawal,
    InitialNew, InitialReplace, InitialCancel,

    # OrderSide values
    Buy, Sell,

    # OrderType values
    LO, ELO, MO, AO, ALO, ODD, LIT, MIT, TSLPAMT, TSLPPCT, TSMAMT, TSMPCT, SLO, SLM,

    # OrderTag values
    Normal, LongTerm, Grey, MarginCall, Offline, Creditor, Debtor, NonExercise, AllocatedSub,

    # TimeInForceType values
    Day, GTC, GTD,

    # TriggerStatus values
    Deactive, Active, Released,
    
    # OutsideRTH values
    RTH, PreRTH, PostRTH,
    
    # Trade Data structures
    Execution, Order, PushOrderChanged, MarginRatio, OrderChargeItem,
    OrderChargeFee, OrderChargeDetail, OrderHistoryDetail, OrderDetail,
    EstimateMaxPurchaseQuantityResponse, FrozenTransactionFee,
    
    # Trade Context methods
    set_on_order_changed, set_on_order_status

# Version info
const VERSION = TOML.parsefile(joinpath(pkgdir(@__MODULE__), "Project.toml"))["version"]

function __init__()
    @info "Longport Julia SDK loaded (v$VERSION)"
end

end # module Longport
