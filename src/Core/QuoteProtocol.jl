# 基于官方 api.proto 的Julia实现  https://github.com/longportapp/openapi-protobufs/blob/main/quote/api.proto
# 专门用于行情 WebSocket 协议的 Protocol Buffer 消息

module QuoteProtocol

    using ProtoBuf
    using ProtoBuf.EnumX: @enumx
    using ProtoBuf.Codecs: BufferedVector
    using Dates
    import ProtoBuf: ProtoDecoder, decode, encode, _encoded_size, skip, message_done, decode_tag, default_values, field_numbers
    import Base: show

    export QuoteCommand, SubType, TradeStatus, TradeSession, AdjustType, CandlePeriod,      # 枚举类型Enums
           SecurityBoard, PushQuoteTag, CalcIndex,
           
           SecurityRequest, MultiSecurityRequest, PrePostQuote, SecurityQuote, SecurityQuoteResponse,         # 结构体类型Struct
           SecurityStaticInfo, SecurityStaticInfoResponse,
           
           HistoryCandlestickQueryType, Direction,                                                            # 枚举类型Enums

           Candlestick, SecurityCandlestickRequest, SecurityCandlestickResponse,                              # 结构体类型Struct
           QuoteSubscribeRequest, QuoteSubscribeResponse, QuoteUnsubscribeRequest,                            # 结构体类型Struct
           QuoteUnsubscribeResponse,

           Depth, Brokers, Transaction, PushQuote, PushDepth, PushBrokers, PushTransaction,                   # 结构体类型Struct
           OptionExtend, WarrantExtend, StrikePriceInfo,  SecurityDepthResponse, SecurityBrokersResponse,
           OptionQuote, OptionQuoteResponse, WarrantQuote, WarrantQuoteResponse, 
           ParticipantInfo, ParticipantBrokerIdsResponse
           
    # 行情协议指令定义 - 基于api.proto
    @enumx QuoteCommand begin
        UNKNOWN_COMMAND = 0
        HEART_BEAT = 1                  # 心跳
        AUTH = 2                        # 鉴权
        RECONNECT = 3                   # 重新连接

        QueryUserQuoteProfile = 4       # 查询用户行情信息
        Subscription = 5                # 查询连接的已订阅数据
        Subscribe = 6                   # 订阅行情数据
        Unsubscribe = 7                 # 取消订阅行情数据
        QueryMarketTradePeriod = 8      # 查询各市场的当日交易时段
        QueryMarketTradeDay = 9         # 查询交易日
        QuerySecurityStaticInfo = 10    # 查询标的基础信息
        QuerySecurityQuote = 11         # 查询标的行情(所有标的通用行情)
        QueryOptionQuote = 12           # 查询期权行情(仅支持期权)
        QueryWarrantQuote = 13          # 查询轮证行情(仅支持轮证)
        QueryDepth = 14                 # 查询盘口
        QueryBrokers = 15               # 查询经纪队列
        QueryParticipantBrokerIds = 16  # 查询券商经纪席位
        QueryTrade = 17                 # 查询成交明细
        QueryIntraday = 18              # 查询当日分时
        QueryCandlestick = 19           # 查询k线
        QueryOptionChainDate = 20       # 查询标的期权链日期列表
        QueryOptionChainDateStrikeInfo = 21 # 查询标的期权链某日的行权价信息
        QueryWarrantIssuerInfo = 22     # 查询轮证发行商对应Id
        QueryWarrantFilterList = 23     # 查询轮证筛选列表
        QueryCapitalFlowIntraday = 24   # 查询标的的资金流分时
        QueryCapitalFlowDistribution = 25 # 查询标的资金流大小单
        QuerySecurityCalcIndex = 26     # 查询标的指标数据
        QueryHistoryCandlestick = 27    # 查询标的历史 k 线

        PushQuoteData = 101             # 推送行情
        PushDepthData = 102             # 推送盘口
        PushBrokersData = 103           # 推送经纪队列
        PushTradeData = 104             # 推送成交明细
    end
    show(io::IO, x::QuoteCommand.T) = print(io, Symbol(x))

    # 行情订阅类型
    @enumx SubType begin
        UNKNOWN_TYPE = 0
        QUOTE = 1
        DEPTH = 2
        BROKERS = 3
        TRADE = 4
    end
    show(io::IO, x::SubType.T) = print(io, Symbol(x))

    # 交易状态
    @enumx TradeStatus begin
        Normal = 0
        Halted = 1          # 停牌
        Delisted = 2
        Fuse = 3
        PrepareList = 4
        CodeMoved = 5
        ToBeOpened = 6
        SplitStockHalts = 7
        Expired = 8
        WarrantPrepareList = 9
        SuspendTrade = 10
    end
    show(io::IO, x::TradeStatus.T) = print(io, Symbol(x))

    # 交易时段
    @enumx TradeSession begin
        Intraday = 0               # 盘中、日内
        PreTrade = 1               # 盘前
        PostTrade = 2              # 盘后
        OvernightTrade = 3         # 夜盘
    end
    show(io::IO, x::TradeSession.T) = print(io, Symbol(x))

    # 复权类型
    @enumx AdjustType begin
        NO_ADJUST = 0
        FORWARD_ADJUST = 1
    end
    show(io::IO, x::AdjustType.T) = print(io, Symbol(x))

    # K线周期
    @enumx CandlePeriod begin
        UNKNOWN_PERIOD = 0
        ONE_MINUTE = 1
        TWO_MINUTE = 2
        THREE_MINUTE = 3
        FIVE_MINUTE = 5
        TEN_MINUTE = 10
        FIFTEEN_MINUTE = 15
        TWENTY_MINUTE = 20
        THIRTY_MINUTE = 30
        FORTY_FIVE_MINUTE = 45
        SIXTY_MINUTE = 60
        TWO_HOUR = 120
        THREE_HOUR = 180
        FOUR_HOUR = 240
        DAY = 1000
        WEEK = 2000
        MONTH = 3000
        QUARTER = 3500
        YEAR = 4000
    end
    show(io::IO, x::CandlePeriod.T) = print(io, Symbol(x))

    # 推送行情标签
    @enumx PushQuoteTag begin
        Normal = 0              # 实时行情
        Eod = 1                 # 日终数据
    end
    show(io::IO, x::PushQuoteTag.T) = print(io, Symbol(x))

    # 计算指标
    @enumx CalcIndex begin
        CALCINDEX_UNKNOWN = 0
        CALCINDEX_LAST_DONE = 1
        CALCINDEX_CHANGE_VAL = 2
        CALCINDEX_CHANGE_RATE = 3
        CALCINDEX_VOLUME = 4
        CALCINDEX_TURNOVER = 5
        CALCINDEX_YTD_CHANGE_RATE = 6
        CALCINDEX_TURNOVER_RATE = 7
        CALCINDEX_TOTAL_MARKET_VALUE = 8
        CALCINDEX_CAPITAL_FLOW = 9
        CALCINDEX_AMPLITUDE = 10
        CALCINDEX_VOLUME_RATIO = 11
        CALCINDEX_PE_TTM_RATIO = 12
        CALCINDEX_PB_RATIO = 13
        CALCINDEX_DIVIDEND_RATIO_TTM = 14
        CALCINDEX_FIVE_DAY_CHANGE_RATE = 15
        CALCINDEX_TEN_DAY_CHANGE_RATE = 16
        CALCINDEX_HALF_YEAR_CHANGE_RATE = 17
        CALCINDEX_FIVE_MINUTES_CHANGE_RATE = 18
        CALCINDEX_EXPIRY_DATE = 19
        CALCINDEX_STRIKE_PRICE = 20
        CALCINDEX_UPPER_STRIKE_PRICE = 21
        CALCINDEX_LOWER_STRIKE_PRICE = 22
        CALCINDEX_OUTSTANDING_QTY = 23
        CALCINDEX_OUTSTANDING_RATIO = 24
        CALCINDEX_PREMIUM = 25
        CALCINDEX_ITM_OTM = 26
        CALCINDEX_IMPLIED_VOLATILITY = 27
        CALCINDEX_WARRANT_DELTA = 28
        CALCINDEX_CALL_PRICE = 29
        CALCINDEX_TO_CALL_PRICE = 30
        CALCINDEX_EFFECTIVE_LEVERAGE = 31
        CALCINDEX_LEVERAGE_RATIO = 32
        CALCINDEX_CONVERSION_RATIO = 33
        CALCINDEX_BALANCE_POINT = 34
        CALCINDEX_OPEN_INTEREST = 35
        CALCINDEX_DELTA = 36
        CALCINDEX_GAMMA = 37
        CALCINDEX_THETA = 38
        CALCINDEX_VEGA = 39
        CALCINDEX_RHO = 40
    end
    show(io::IO, x::CalcIndex.T) = print(io, Symbol(x))

    # 证券板块
    @enumx SecurityBoard begin
        UnknownBoard     = 0
        USMain           = 1  # 美股主板
        USPink           = 2  # 粉单市场
        USDJI            = 3  # 道琼斯指数
        USNSDQ           = 4  # 纳斯达克指数
        USSector         = 5  # 美股行业概念
        USOption         = 6  # 美股期权
        USOptionS        = 7  # 美股特殊期权（收盘时间为 16:15）
        HKEquity         = 8  # 港股股本证券
        HKPreIPO         = 9  # 港股暗盘
        HKWarrant        = 10 # 港股轮证
        HKCBBC           = 11 # 港股牛熊证
        HKSector         = 12 # 港股行业概念
        SHMainConnect    = 13 # 上证主板 - 互联互通
        SHMainNonConnect = 14 # 上证主板 - 非互联互通
        SHSTAR           = 15 # 科创板
        CNIX             = 16 # 沪深指数
        CNSector         = 17 # 沪深行业概念
        SZMainConnect    = 18 # 深证主板 - 互联互通
        SZMainNonConnect = 19 # 深证主板 - 非互联互通
        SZGEMConnect     = 20 # 创业板 - 互联互通
        SZGEMNonConnect  = 21 # 创业板 - 非互联互通
        SGMain           = 22 # 新加坡主板
        STI              = 23 # 新加坡海峡指数
        SGSector         = 24 # 新加坡行业概念
    end
    show(io::IO, x::SecurityBoard.T) = print(io, Symbol(x))
    # 暂时没用到
    function parse_board_enum(s::AbstractString)::SecurityBoard.T
        if isempty(s)
            return SecurityBoard.UnknownBoard
        end

        for (val, name) in zip(instances(SecurityBoard.T), string.(instances(SecurityBoard.T)))
            if s == name
                return val
            end
        end

        @warn "Unknown SecurityBoard value: '$s'"
        return SecurityBoard.UnknownBoard
    end

    # 基础请求结构
    struct SecurityRequest
        symbol::String
    end
    default_values(::Type{SecurityRequest}) = (;symbol = "")
    field_numbers(::Type{SecurityRequest}) = (;symbol = 1)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityRequest})
        symbol = ""
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            else
                skip(d, wire_type)
            end
        end
        return SecurityRequest(symbol)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::SecurityRequest)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        return position(e.io) - initpos
    end
    function _encoded_size(x::SecurityRequest)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        return encoded_size
    end

    # 多标的请求结构
    struct MultiSecurityRequest
        symbol::Vector{String}
    end
    default_values(::Type{MultiSecurityRequest}) = (;symbol = String[])
    field_numbers(::Type{MultiSecurityRequest}) = (;symbol = 1)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:MultiSecurityRequest})
        symbol = String[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                decode!(d, wire_type, symbol)
            else
                skip(d, wire_type)
            end
        end
        return MultiSecurityRequest(symbol)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::MultiSecurityRequest)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        return position(e.io) - initpos
    end
    function _encoded_size(x::MultiSecurityRequest)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        return encoded_size
    end

    struct SecurityStaticInfo
        symbol::String
        name_cn::String
        name_en::String
        name_hk::String
        listing_date::String
        exchange::String
        currency::String
        lot_size::Int64
        total_shares::Int64
        circulating_shares::Int64
        hk_shares::Int64
        eps::Float64
        eps_ttm::Float64
        bps::Float64
        dividend_yield::Float64
        stock_derivatives::Vector{Int64}
        board::String
    end
    default_values(::Type{SecurityStaticInfo}) = (;symbol = "", name_cn = "", name_en = "", name_hk = "", listing_date = "", exchange = "", currency = "", lot_size = zero(Int64), total_shares = zero(Int64), circulating_shares = zero(Int64), hk_shares = zero(Int64), eps = 0.0, eps_ttm = 0.0, bps = 0.0, dividend_yield = 0.0, stock_derivatives = Int64[], board = "")
    field_numbers(::Type{SecurityStaticInfo}) = (;symbol = 1, name_cn = 2, name_en = 3, name_hk = 4, listing_date = 5, exchange = 6, currency = 7, lot_size = 8, total_shares = 9, circulating_shares = 10, hk_shares = 11, eps = 12, eps_ttm = 13, bps = 14, dividend_yield = 15, stock_derivatives = 16, board = 17)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityStaticInfo})
        symbol = ""
        name_cn = ""
        name_en = ""
        name_hk = ""
        listing_date = ""
        exchange = ""
        currency = ""
        lot_size = zero(Int64)
        total_shares = zero(Int64)
        circulating_shares = zero(Int64)
        hk_shares = zero(Int64)
        eps = 0.0
        eps_ttm = 0.0
        bps = 0.0
        dividend_yield = 0.0
        stock_derivatives = BufferedVector{Int64}()
        board = ""
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                name_cn = decode(d, String)
            elseif field_number == 3
                name_en = decode(d, String)
            elseif field_number == 4
                name_hk = decode(d, String)
            elseif field_number == 5
                listing_date = decode(d, String)
            elseif field_number == 6
                exchange = decode(d, String)
            elseif field_number == 7
                currency = decode(d, String)
            elseif field_number == 8
                lot_size = decode(d, Int64)
            elseif field_number == 9
                total_shares = decode(d, Int64)
            elseif field_number == 10
                circulating_shares = decode(d, Int64)
            elseif field_number == 11
                hk_shares = decode(d, Int64)
            elseif field_number == 12
                eps = parse(Float64, decode(d, String))
            elseif field_number == 13
                eps_ttm = parse(Float64, decode(d, String))
            elseif field_number == 14
                bps = parse(Float64, decode(d, String))
            elseif field_number == 15
                dividend_yield = parse(Float64, decode(d, String))
            elseif field_number == 16
                decode!(d, wire_type, stock_derivatives)
            elseif field_number == 17
                board = decode(d, String)
            else
                skip(d, wire_type)
            end
        end
        return SecurityStaticInfo(
            symbol, name_cn, name_en, name_hk, listing_date, exchange, currency, lot_size, 
            total_shares, circulating_shares, hk_shares, eps, eps_ttm, bps, dividend_yield, 
            getindex(stock_derivatives), board
        )
    end

    # 证券静态信息响应
    struct SecurityStaticInfoResponse
        secu_static_info::Vector{SecurityStaticInfo}
    end
    SecurityStaticInfoResponse() = SecurityStaticInfoResponse(SecurityStaticInfo[])
    default_values(::Type{SecurityStaticInfoResponse}) = (;secu_static_info = SecurityStaticInfo[])
    field_numbers(::Type{SecurityStaticInfoResponse}) = (;secu_static_info = 1)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityStaticInfoResponse})
        secu_static_info = SecurityStaticInfo[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(secu_static_info, decode(sub_d, SecurityStaticInfo))
            else
                skip(d, wire_type)
            end
        end
        return SecurityStaticInfoResponse(secu_static_info)
    end
  
    struct PrePostQuote
        last_done::Float64       # 最新成交价
        timestamp::Int64
        volume::Int64
        turnover::Float64        # 成交额，当前报价时累计的成交金额
        high::Float64
        low::Float64
        prev_close::Float64
    end
    function show(io::IO, q::PrePostQuote)
        print(io, "{ last: $(q.last_done), high: $(q.high), low: $(q.low), volume: $(q.volume), turnover: $(q.turnover) }")
    end
    default_values(::Type{PrePostQuote}) = (
        last_done = 0.0,
        timestamp = zero(Int64),
        volume = zero(Int64),
        turnover = 0.0,
        high = 0.0,
        low = 0.0,
        prev_close = 0.0
    )
    field_numbers(::Type{PrePostQuote}) = (
        last_done = 1,
        timestamp = 2,
        volume = 3,
        turnover = 4,
        high = 5,
        low = 6,
        prev_close = 7
    )

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:PrePostQuote})
        last_done = 0.0
        timestamp = zero(Int64)
        volume = zero(Int64)
        turnover = 0.0
        high = 0.0
        low = 0.0
        prev_close = 0.0

        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                last_done = parse(Float64, decode(d, String))
            elseif field_number == 2
                timestamp = decode(d, Int64)
            elseif field_number == 3
                volume = decode(d, Int64)
            elseif field_number == 4
                turnover = parse(Float64, decode(d, String))
            elseif field_number == 5
                high = parse(Float64, decode(d, String))
            elseif field_number == 6
                low = parse(Float64, decode(d, String))
            elseif field_number == 7
                prev_close = parse(Float64, decode(d, String))
            else
                skip(d, wire_type)
            end
        end

        return PrePostQuote(last_done, timestamp, volume, turnover, high, low, prev_close)
    end
  
    # 证券行情数据
    struct SecurityQuote
        symbol::String
        last_done::Float64
        prev_close::Float64
        open::Float64
        high::Float64
        low::Float64
        timestamp::Int64
        volume::Int64
        turnover::Float64
        trade_status::TradeStatus.T
        pre_market_quote::Union{PrePostQuote, Nothing}
        post_market_quote::Union{PrePostQuote, Nothing}
        over_night_quote::Union{PrePostQuote, Nothing}
    end
    default_values(::Type{SecurityQuote}) = (
        symbol = "",
        last_done = 0.0,
        prev_close = 0.0,
        open = 0.0,
        high = 0.0,
        low = 0.0,
        timestamp = zero(Int64),
        volume = 0,
        turnover = 0.0,
        trade_status = TradeStatus.Normal,
        pre_market_quote = nothing,
        post_market_quote = nothing,
        over_night_quote = nothing
    )
    field_numbers(::Type{SecurityQuote}) = (
        symbol = 1,
        last_done = 2,
        prev_close = 3,
        open = 4,
        high = 5,
        low = 6,
        timestamp = 7,
        volume = 8,
        turnover = 9,
        trade_status = 10,
        pre_market_quote = 11,
        post_market_quote = 12,
        over_night_quote = 13
    )

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityQuote})
        symbol = ""
        last_done = 0.0
        prev_close = 0.0
        open = 0.0
        high = 0.0
        low = 0.0
        timestamp = zero(Int64)
        volume = 0
        turnover = 0.0
        trade_status = TradeStatus.Normal
        pre_market_quote = nothing
        post_market_quote = nothing
        over_night_quote = nothing

        try
            while !message_done(d)
                field_number, wire_type = decode_tag(d)
                if field_number == 1
                    symbol = decode(d, String)
                elseif field_number == 2
                    last_done = parse(Float64, decode(d, String))
                elseif field_number == 3
                    prev_close = parse(Float64, decode(d, String))
                elseif field_number == 4
                    open = parse(Float64, decode(d, String))
                elseif field_number == 5
                    high = parse(Float64, decode(d, String))
                elseif field_number == 6
                    low = parse(Float64, decode(d, String))
                elseif field_number == 7
                    timestamp = decode(d, Int64)
                elseif field_number == 8
                    volume = decode(d, Int64)
                elseif field_number == 9
                    turnover = parse(Float64, decode(d, String))
                elseif field_number == 10
                    trade_status = decode(d, TradeStatus.T)
                elseif field_number == 11
                    len = decode(d, UInt64)
                    sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                    pre_market_quote = decode(sub_d, PrePostQuote)
                elseif field_number == 12
                    len = decode(d, UInt64)
                    sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                    post_market_quote = decode(sub_d, PrePostQuote)
                elseif field_number == 13
                    len = decode(d, UInt64)
                    sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                    over_night_quote = decode(sub_d, PrePostQuote)
                else
                    skip(d, wire_type)
                end
            end
        catch e
            @error "SecurityQuote decode error" exception=e position=position(d.io)
            rethrow(e)
        end

        return SecurityQuote(
            symbol, last_done, prev_close, open, high, low,
            timestamp, volume, turnover, trade_status,
            pre_market_quote, post_market_quote, over_night_quote
        )
    end

    # 证券行情响应
    struct SecurityQuoteResponse
        secu_quote::Vector{SecurityQuote}
    end
    SecurityQuoteResponse() = SecurityQuoteResponse(SecurityQuote[])
    default_values(::Type{SecurityQuoteResponse}) = (;secu_quote = SecurityQuote[])
    field_numbers(::Type{SecurityQuoteResponse}) = (;secu_quote = 1)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityQuoteResponse})
        secu_quote = SecurityQuote[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(secu_quote, decode(sub_d, SecurityQuote))
            else
                skip(d, wire_type)
            end
        end
        return SecurityQuoteResponse(secu_quote)
    end

    # 历史K线查询类型
    @enumx HistoryCandlestickQueryType begin
        UNKNOWN_QUERY_TYPE = 0
        QUERY_BY_OFFSET = 1
        QUERY_BY_DATE = 2
    end
    show(io::IO, x::HistoryCandlestickQueryType.T) = print(io, Symbol(x))

    # 查询方向
    @enumx Direction begin
        BACKWARD = 0  # 老数据，从最新的数据往历史数据翻页
        FORWARD = 1   # 新数据，从当前数据往最新数据翻页
    end
    show(io::IO, x::Direction.T) = print(io, Symbol(x))

    # K线数据
    struct Candlestick
        close::Float64
        open::Float64
        low::Float64
        high::Float64
        volume::Int64
        turnover::Float64
        timestamp::Int64
        trade_session::TradeSession.T
    end
    default_values(::Type{Candlestick}) = (;close = 0.0, open = 0.0, low = 0.0, high = 0.0, volume = zero(Int64), turnover = 0.0, timestamp = zero(Int64), trade_session = TradeSession.Intraday)
    field_numbers(::Type{Candlestick}) = (;close = 1, open = 2, low = 3, high = 4, volume = 5, turnover = 6, timestamp = 7, trade_session = 8)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:Candlestick})
        close = 0.0
        open = 0.0
        low = 0.0
        high = 0.0
        volume = zero(Int64)
        turnover = 0.0
        timestamp = zero(Int64)
        trade_session = TradeSession.Intraday
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                close = parse(Float64, decode(d, String))
            elseif field_number == 2
                open = parse(Float64, decode(d, String))
            elseif field_number == 3
                low = parse(Float64, decode(d, String))
            elseif field_number == 4
                high = parse(Float64, decode(d, String))
            elseif field_number == 5
                volume = decode(d, Int64)
            elseif field_number == 6
                turnover = parse(Float64, decode(d, String))
            elseif field_number == 7
                timestamp = decode(d, Int64)
            elseif field_number == 8
                trade_session = decode(d, TradeSession.T)
            else
                skip(d, wire_type)
            end
        end
        return Candlestick(close, open, low, high, volume, turnover, timestamp, trade_session)
    end

    # K线请求
    struct SecurityCandlestickRequest
        symbol::String
        period::CandlePeriod.T
        count::Int64
        adjust_type::AdjustType.T
        trade_session::TradeSession.T
    end
    default_values(::Type{SecurityCandlestickRequest}) = (
        ;symbol = "", period = CandlePeriod.UNKNOWN_PERIOD, count = 0, 
        adjust_type = AdjustType.NO_ADJUST, trade_session = TradeSession.Intraday
    )
    field_numbers(::Type{SecurityCandlestickRequest}) = (;symbol = 1, period = 2, count = 3, adjust_type = 4, trade_session = 5)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityCandlestickRequest})
        symbol = ""
        period = CandlePeriod.UNKNOWN_PERIOD
        count = zero(Int64)
        adjust_type = AdjustType.NO_ADJUST
        trade_session = TradeSession.Intraday
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                period = decode(d, CandlePeriod.T)
            elseif field_number == 3
                count = decode(d, Int64)
            elseif field_number == 4
                adjust_type = decode(d, AdjustType.T)
            elseif field_number == 5
                trade_session = decode(d, TradeSession.T)
            else
                skip(d, wire_type)
            end
        end
        return SecurityCandlestickRequest(symbol, period, count, adjust_type, trade_session)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::SecurityCandlestickRequest)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        x.period != CandlePeriod.UNKNOWN_PERIOD && encode(e, 2, x.period)
        x.count != 0 && encode(e, 3, x.count)
        x.adjust_type != AdjustType.NO_ADJUST && encode(e, 4, x.adjust_type)
        x.trade_session != TradeSession.Intraday && encode(e, 5, x.trade_session)
        return position(e.io) - initpos
    end
    function _encoded_size(x::SecurityCandlestickRequest)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        x.period != CandlePeriod.UNKNOWN_PERIOD && (encoded_size += _encoded_size(x.period, 2))
        x.count != 0 && (encoded_size += _encoded_size(x.count, 3))
        x.adjust_type != AdjustType.NO_ADJUST && (encoded_size += _encoded_size(x.adjust_type, 4))
        x.trade_session != TradeSession.Intraday && (encoded_size += _encoded_size(x.trade_session, 5))
        return encoded_size
    end

    # K线响应
    struct SecurityCandlestickResponse
        symbol::String
        candlesticks::Vector{Candlestick}
    end
    SecurityCandlestickResponse() = SecurityCandlestickResponse("", Candlestick[])
    default_values(::Type{SecurityCandlestickResponse}) = (;symbol = "", candlesticks = Candlestick[])
    field_numbers(::Type{SecurityCandlestickResponse}) = (;symbol = 1, candlesticks = 2)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityCandlestickResponse})
        symbol = ""
        candlesticks = Candlestick[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(candlesticks, decode(sub_d, Candlestick))
            else
                skip(d, wire_type)
            end
        end
        return SecurityCandlestickResponse(symbol, candlesticks)
    end

    # 行情订阅请求
    struct QuoteSubscribeRequest
        symbol::Vector{String}
        sub_type::Vector{SubType.T}
        is_first_push::Bool
    end
    default_values(::Type{QuoteSubscribeRequest}) = (;symbol = String[], sub_type = SubType.T[], is_first_push = false)
    field_numbers(::Type{QuoteSubscribeRequest}) = (;symbol = 1, sub_type = 2, is_first_push = 3)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:QuoteSubscribeRequest})
        symbol = String[]
        sub_type = SubType.T[]
        is_first_push = false
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                decode!(d, wire_type, symbol)
            elseif field_number == 2
                decode!(d, wire_type, sub_type)
            elseif field_number == 3
                is_first_push = decode(d, Bool)
            else
                skip(d, wire_type)
            end
        end
        return QuoteSubscribeRequest(symbol, sub_type, is_first_push)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::QuoteSubscribeRequest)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        !isempty(x.sub_type) && encode(e, 2, x.sub_type)
        x.is_first_push != false && encode(e, 3, x.is_first_push)
        return position(e.io) - initpos
    end
    function _encoded_size(x::QuoteSubscribeRequest)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        !isempty(x.sub_type) && (encoded_size += _encoded_size(x.sub_type, 2))
        x.is_first_push != false && (encoded_size += _encoded_size(x.is_first_push, 3))
        return encoded_size
    end

    # 行情订阅响应（空消息）
    struct QuoteSubscribeResponse
    end
    default_values(::Type{QuoteSubscribeResponse}) = NamedTuple()
    field_numbers(::Type{QuoteSubscribeResponse}) = NamedTuple()

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:QuoteSubscribeResponse})
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            skip(d, wire_type)
        end
        return QuoteSubscribeResponse()
    end
    function _encoded_size(x::QuoteSubscribeResponse)
        return 0
    end

    # 行情取消订阅请求
    struct QuoteUnsubscribeRequest
        symbol::Vector{String}
        sub_type::Vector{SubType.T}
        unsub_all::Bool
    end
    default_values(::Type{QuoteUnsubscribeRequest}) = (;symbol = String[], sub_type = SubType.T[], unsub_all = false)
    field_numbers(::Type{QuoteUnsubscribeRequest}) = (;symbol = 1, sub_type = 2, unsub_all = 3)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:QuoteUnsubscribeRequest})
        symbol = String[]
        sub_type = SubType.T[]
        unsub_all = false
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                decode!(d, wire_type, symbol)
            elseif field_number == 2
                decode!(d, wire_type, sub_type)
            elseif field_number == 3
                unsub_all = decode(d, Bool)
            else
                skip(d, wire_type)
            end
        end
        return QuoteUnsubscribeRequest(symbol, sub_type, unsub_all)
    end
    function encode(e::ProtoBuf.ProtoBuf.AbstractProtoEncoder, x::QuoteUnsubscribeRequest)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        !isempty(x.sub_type) && encode(e, 2, x.sub_type)
        x.unsub_all != false && encode(e, 3, x.unsub_all)
        return position(e.io) - initpos
    end
    function _encoded_size(x::QuoteUnsubscribeRequest)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        !isempty(x.sub_type) && (encoded_size += _encoded_size(x.sub_type, 2))
        x.unsub_all != false && (encoded_size += _encoded_size(x.unsub_all, 3))
        return encoded_size
    end

    # 行情取消订阅响应（空消息）
    struct QuoteUnsubscribeResponse
    end
    default_values(::Type{QuoteUnsubscribeResponse}) = NamedTuple()
    field_numbers(::Type{QuoteUnsubscribeResponse}) = NamedTuple()

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:QuoteUnsubscribeResponse})
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            skip(d, wire_type)
        end
        return QuoteUnsubscribeResponse()
    end
    function _encoded_size(x::QuoteUnsubscribeResponse)
        return 0
    end

    # 盘口数据
    struct Depth
        position::Int64
        price::Float64
        volume::Int64
        order_num::Int64
    end
    default_values(::Type{Depth}) = (;position = zero(Int64), price = 0.0, volume = zero(Int64), order_num = zero(Int64))
    field_numbers(::Type{Depth}) = (;position = 1, price = 2, volume = 3, order_num = 4)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:Depth})
        position = zero(Int64)
        price = 0.0
        volume = zero(Int64)
        order_num = zero(Int64)
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                position = decode(d, Int64)
            elseif field_number == 2
                price = parse(Float64, decode(d, String))
            elseif field_number == 3
                volume = decode(d, Int64)
                elseif field_number == 4
                order_num = decode(d, Int64)
            else
                skip(d, wire_type)
            end
        end
        return Depth(position, price, volume, order_num)
    end

    # 经纪队列
    struct Brokers
        position::Int64
        broker_ids::Vector{Int64}
    end
    default_values(::Type{Brokers}) = (;position = zero(Int64), broker_ids = Int64[])
    field_numbers(::Type{Brokers}) = (;position = 1, broker_ids = 2)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:Brokers})
        position = zero(Int64)
        broker_ids = BufferedVector{Int64}()
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                position = decode(d, Int64)
            elseif field_number == 2
                decode!(d, wire_type, broker_ids)
            else
                skip(d, wire_type)
            end
        end
        return Brokers(position, getindex(broker_ids))
    end

    # 成交明细
    struct Transaction
        price::String
        volume::Int64
        timestamp::Int64
        trade_type::String
        direction::Int64
        trade_session::TradeSession.T
    end
    default_values(::Type{Transaction}) = (;price = "", volume = zero(Int64), timestamp = zero(Int64), trade_type = "", direction = zero(Int64), trade_session = TradeSession.Intraday)
    field_numbers(::Type{Transaction}) = (;price = 1, volume = 2, timestamp = 3, trade_type = 4, direction = 5, trade_session = 6)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:Transaction})
        price = ""
        volume = zero(Int64)
        timestamp = zero(Int64)
        trade_type = ""
        direction = zero(Int64)
        trade_session = TradeSession.Intraday
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                price = decode(d, String)
            elseif field_number == 2
                volume = decode(d, Int64)
            elseif field_number == 3
                timestamp = decode(d, Int64)
            elseif field_number == 4
                trade_type = decode(d, String)
            elseif field_number == 5
                direction = decode(d, Int64)
            elseif field_number == 6
                trade_session = decode(d, TradeSession.T)
            else
                skip(d, wire_type)
            end
        end
        return Transaction(price, volume, timestamp, trade_type, direction, trade_session)
    end

    # 推送行情数据
    struct PushQuote
        symbol::String
        sequence::Int64                 # 推送序列号，用于标识消息的顺序
        last_done::Float64
        open::Float64
        high::Float64
        low::Float64
        timestamp::Int64
        volume::Int64                   # 成交量，到当前时间为止的总成交股数
        turnover::Float64               # 成交额，到当前时间为止的总成交金额
        trade_status::TradeStatus.T
        trade_session::TradeSession.T
        current_volume::Int64           # 当前单笔成交量（可能指最近一笔或一个极短时间窗口内的成交，区别于`volume`的日内累计值）
        current_turnover::Float64       # 当前单笔成交额
        tag::PushQuoteTag.T
    end
    default_values(::Type{PushQuote}) = (
        ; symbol = "", sequence = zero(Int64), last_done = 0.0, open = 0.0, high = 0.0, low = 0.0, timestamp = zero(Int64), volume = zero(Int64), turnover = 0.0, 
        trade_status = TradeStatus.Normal, trade_session = TradeSession.Intraday, current_volume = zero(Int64), current_turnover = 0.0, tag = PushQuoteTag.Normal
    )
    field_numbers(::Type{PushQuote}) = (
        ; symbol = 1, sequence = 2, last_done = 3, open = 4, high = 5, low = 6, timestamp = 7, volume = 8, turnover = 9, 
        trade_status = 10, trade_session = 11, current_volume = 12, current_turnover = 13, tag = 14
    )

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:PushQuote})
        symbol = ""
        sequence = zero(Int64)
        last_done = 0.0
        open = 0.0
        high = 0.0
        low = 0.0
        timestamp = zero(Int64)
        volume = zero(Int64)
        turnover = 0.0
        trade_status = TradeStatus.Normal
        trade_session = TradeSession.Intraday
        current_volume = zero(Int64)
        current_turnover = 0.0
        tag = PushQuoteTag.Normal
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                sequence = decode(d, Int64)
            elseif field_number == 3
                last_done = parse(Float64, decode(d, String))
            elseif field_number == 4
                open = parse(Float64, decode(d, String))
            elseif field_number == 5
                high = parse(Float64, decode(d, String))
            elseif field_number == 6
                low = parse(Float64, decode(d, String))
            elseif field_number == 7
                timestamp = decode(d, Int64)
            elseif field_number == 8
                volume = decode(d, Int64)
            elseif field_number == 9
                turnover = parse(Float64, decode(d, String))
            elseif field_number == 10
                trade_status = decode(d, TradeStatus.T)
            elseif field_number == 11
                trade_session = decode(d, TradeSession.T)
            elseif field_number == 12
                current_volume = decode(d, Int64)
            elseif field_number == 13
                current_turnover = parse(Float64, decode(d, String))
            elseif field_number == 14
                tag = decode(d, PushQuoteTag.T)
            else
                skip(d, wire_type)
            end
        end
        return PushQuote(symbol, sequence, last_done, open, high, low, timestamp, volume, turnover, trade_status, trade_session, current_volume, current_turnover, tag)
    end

    # 推送盘口数据
    struct PushDepth
        symbol::String
        sequence::Int64
        ask::Vector{Depth}
        bid::Vector{Depth}
    end
    default_values(::Type{PushDepth}) = (;symbol = "", sequence = zero(Int64), ask = Depth[], bid = Depth[])
    field_numbers(::Type{PushDepth}) = (;symbol = 1, sequence = 2, ask = 3, bid = 4)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:PushDepth})
        symbol = ""
        sequence = zero(Int64)
        ask = Depth[]
        bid = Depth[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                sequence = decode(d, Int64)
            elseif field_number == 3
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(ask, decode(sub_d, Depth))
            elseif field_number == 4
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(bid, decode(sub_d, Depth))
            else
                skip(d, wire_type)
            end
        end
        return PushDepth(symbol, sequence, ask, bid)
    end

    # 推送经纪队列数据
    struct PushBrokers
        symbol::String
        sequence::Int64
        ask_brokers::Vector{Brokers}
        bid_brokers::Vector{Brokers}
    end
    default_values(::Type{PushBrokers}) = (;symbol = "", sequence = zero(Int64), ask_brokers = Brokers[], bid_brokers = Brokers[])
    field_numbers(::Type{PushBrokers}) = (;symbol = 1, sequence = 2, ask_brokers = 3, bid_brokers = 4)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:PushBrokers})
        symbol = ""
        sequence = zero(Int64)
        ask_brokers = Brokers[]
        bid_brokers = Brokers[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                sequence = decode(d, Int64)
            elseif field_number == 3
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(ask_brokers, decode(sub_d, Brokers))
            elseif field_number == 4
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(bid_brokers, decode(sub_d, Brokers))
            else
                skip(d, wire_type)
            end
        end
        return PushBrokers(symbol, sequence, ask_brokers, bid_brokers)
    end

    # 推送成交明细数据
    struct PushTransaction
        symbol::String
        sequence::Int64
        transaction::Vector{Transaction}
    end
    default_values(::Type{PushTransaction}) = (;symbol = "", sequence = zero(Int64), transaction = Transaction[])
    field_numbers(::Type{PushTransaction}) = (;symbol = 1, sequence = 2, transaction = 3)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:PushTransaction})
        symbol = ""
        sequence = zero(Int64)
        transaction = Transaction[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                sequence = decode(d, Int64)
            elseif field_number == 3
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(transaction, decode(sub_d, Transaction))
            else
                skip(d, wire_type)
            end
        end
        return PushTransaction(symbol, sequence, transaction)
    end

    # 期权扩展信息
    struct OptionExtend
        implied_volatility::String
        open_interest::Int64
        expiry_date::String
        strike_price::String
        contract_multiplier::String
        contract_type::String
        contract_size::String
        direction::String
        historical_volatility::String
        underlying_symbol::String
    end
    default_values(::Type{OptionExtend}) = (;implied_volatility = "", open_interest = zero(Int64), expiry_date = "", strike_price = "", contract_multiplier = "", contract_type = "", contract_size = "", direction = "", historical_volatility = "", underlying_symbol = "")
    field_numbers(::Type{OptionExtend}) = (;implied_volatility = 1, open_interest = 2, expiry_date = 3, strike_price = 4, contract_multiplier = 5, contract_type = 6, contract_size = 7, direction = 8, historical_volatility = 9, underlying_symbol = 10)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:OptionExtend})
        implied_volatility = ""
        open_interest = zero(Int64)
        expiry_date = ""
        strike_price = ""
        contract_multiplier = ""
        contract_type = ""
        contract_size = ""
        direction = ""
        historical_volatility = ""
        underlying_symbol = ""
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                implied_volatility = decode(d, String)
            elseif field_number == 2
                open_interest = decode(d, Int64)
            elseif field_number == 3
                expiry_date = decode(d, String)
            elseif field_number == 4
                strike_price = decode(d, String)
            elseif field_number == 5
                contract_multiplier = decode(d, String)
            elseif field_number == 6
                contract_type = decode(d, String)
            elseif field_number == 7
                contract_size = decode(d, String)
            elseif field_number == 8
                direction = decode(d, String)
            elseif field_number == 9
                historical_volatility = decode(d, String)
            elseif field_number == 10
                underlying_symbol = decode(d, String)
            else
                skip(d, wire_type)
            end
        end
        return OptionExtend(implied_volatility, open_interest, expiry_date, strike_price, contract_multiplier, contract_type, contract_size, direction, historical_volatility, underlying_symbol)
    end

    # 权证扩展信息
    struct WarrantExtend
        implied_volatility::Float64
        expiry_date::String
        last_trade_date::String
        outstanding_ratio::Float64
        outstanding_qty::Int64
        conversion_ratio::Float64
        category::String
        strike_price::Float64
        upper_strike_price::Float64
        lower_strike_price::Float64
        call_price::Float64
        underlying_symbol::String
    end
    default_values(::Type{WarrantExtend}) = (;implied_volatility = 0.0, expiry_date = "", last_trade_date = "", outstanding_ratio = 0.0, outstanding_qty = zero(Int64), conversion_ratio = 0.0, category = "", strike_price = 0.0, upper_strike_price = 0.0, lower_strike_price = 0.0, call_price = 0.0, underlying_symbol = "")
    field_numbers(::Type{WarrantExtend}) = (;implied_volatility = 1, expiry_date = 2, last_trade_date = 3, outstanding_ratio = 4, outstanding_qty = 5, conversion_ratio = 6, category = 7, strike_price = 8, upper_strike_price = 9, lower_strike_price = 10, call_price = 11, underlying_symbol = 12)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:WarrantExtend})
        implied_volatility = 0.0
        expiry_date = ""
        last_trade_date = ""
        outstanding_ratio = 0.0
        outstanding_qty = zero(Int64)
        conversion_ratio = 0.0
        category = ""
        strike_price = 0.0
        upper_strike_price = 0.0
        lower_strike_price = 0.0
        call_price = 0.0
        underlying_symbol = ""
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                implied_volatility = parse(Float64, decode(d, String))
            elseif field_number == 2
                expiry_date = decode(d, String)
            elseif field_number == 3
                last_trade_date = decode(d, String)
            elseif field_number == 4
                outstanding_ratio = parse(Float64, decode(d, String))
            elseif field_number == 5
                outstanding_qty = decode(d, Int64)
            elseif field_number == 6
                conversion_ratio = parse(Float64, decode(d, String))
            elseif field_number == 7
                category = decode(d, String)
            elseif field_number == 8
                strike_price = parse(Float64, decode(d, String))
            elseif field_number == 9
                upper_strike_price = parse(Float64, decode(d, String))
            elseif field_number == 10
                lower_strike_price = parse(Float64, decode(d, String))
            elseif field_number == 11
                call_price = parse(Float64, decode(d, String))
            elseif field_number == 12
                underlying_symbol = decode(d, String)
            else
                skip(d, wire_type)
            end
        end
        return WarrantExtend(implied_volatility, expiry_date, last_trade_date, outstanding_ratio, outstanding_qty, conversion_ratio, category, strike_price, upper_strike_price, lower_strike_price, call_price, underlying_symbol)
    end

    # 期权行情数据
    struct OptionQuote
        symbol::String
        last_done::String
        prev_close::String
        open::String
        high::String
        low::String
        timestamp::Int64
        volume::Int64
        turnover::String
        trade_status::TradeStatus.T
        option_extend::OptionExtend
    end
    default_values(::Type{OptionQuote}) = (;symbol = "", last_done = "", prev_close = "", open = "", high = "", low = "", timestamp = zero(Int64), volume = zero(Int64), turnover = "", trade_status = TradeStatus.Normal, option_extend = OptionExtend("", 0, "", "", "", "", "", "", "", ""))
    field_numbers(::Type{OptionQuote}) = (;symbol = 1, last_done = 2, prev_close = 3, open = 4, high = 5, low = 6, timestamp = 7, volume = 8, turnover = 9, trade_status = 10, option_extend = 11)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:OptionQuote})
        symbol = ""
        last_done = ""
        prev_close = ""
        open = ""
        high = ""
        low = ""
        timestamp = zero(Int64)
        volume = zero(Int64)
        turnover = ""
        trade_status = TradeStatus.Normal
        option_extend = nothing
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                last_done = decode(d, String)
            elseif field_number == 3
                prev_close = decode(d, String)
            elseif field_number == 4
                open = decode(d, String)
            elseif field_number == 5
                high = decode(d, String)
            elseif field_number == 6
                low = decode(d, String)
            elseif field_number == 7
                timestamp = decode(d, Int64)
            elseif field_number == 8
                volume = decode(d, Int64)
            elseif field_number == 9
                turnover = decode(d, String)
            elseif field_number == 10
                trade_status = decode(d, TradeStatus.T)
            elseif field_number == 11
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                option_extend = decode(sub_d, OptionExtend)
            else
                skip(d, wire_type)
            end
        end
        return OptionQuote(symbol, last_done, prev_close, open, high, low, timestamp, volume, turnover, trade_status, option_extend)
    end


    # 期权行情响应
    struct OptionQuoteResponse
        secu_quote::Vector{OptionQuote}
    end
    OptionQuoteResponse() = OptionQuoteResponse(OptionQuote[])
    default_values(::Type{OptionQuoteResponse}) = (;secu_quote = OptionQuote[])
    field_numbers(::Type{OptionQuoteResponse}) = (;secu_quote = 1)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:OptionQuoteResponse})
        secu_quote = OptionQuote[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(secu_quote, decode(sub_d, OptionQuote))
            else
                skip(d, wire_type)
            end
        end
        return OptionQuoteResponse(secu_quote)
    end


    # 轮证行情数据
    struct WarrantQuote
        symbol::String
        last_done::Float64
        prev_close::Float64
        open::Float64
        high::Float64
        low::Float64
        timestamp::Int64
        volume::Int64
        turnover::Float64
        trade_status::TradeStatus.T
        warrant_extend::WarrantExtend
    end
    default_values(::Type{WarrantQuote}) = (;symbol = "", last_done = 0.0, prev_close = 0.0, open = 0.0, high = 0.0, low = 0.0, timestamp = zero(Int64), volume = zero(Int64), turnover = 0.0, trade_status = TradeStatus.Normal, warrant_extend = WarrantExtend(0.0, "", "", 0.0, 0, 0.0, "", 0.0, 0.0, 0.0, 0.0, ""))
    field_numbers(::Type{WarrantQuote}) = (;symbol = 1, last_done = 2, prev_close = 3, open = 4, high = 5, low = 6, timestamp = 7, volume = 8, turnover = 9, trade_status = 10, warrant_extend = 11)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:WarrantQuote})
        symbol = ""
        last_done = 0.0
        prev_close = 0.0
        open = 0.0
        high = 0.0
        low = 0.0
        timestamp = zero(Int64)
        volume = zero(Int64)
        turnover = 0.0
        trade_status = TradeStatus.Normal
        warrant_extend = WarrantExtend(0.0, "", "", 0.0, 0, 0.0, "", 0.0, 0.0, 0.0, 0.0, "")
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                last_done = parse(Float64, decode(d, String))
            elseif field_number == 3
                prev_close = parse(Float64, decode(d, String))
            elseif field_number == 4
                open = parse(Float64, decode(d, String))
            elseif field_number == 5
                high = parse(Float64, decode(d, String))
            elseif field_number == 6
                low = parse(Float64, decode(d, String))
            elseif field_number == 7
                timestamp = decode(d, Int64)
            elseif field_number == 8
                volume = decode(d, Int64)
            elseif field_number == 9
                turnover = parse(Float64, decode(d, String))
            elseif field_number == 10
                trade_status = decode(d, TradeStatus.T)
            elseif field_number == 11
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                warrant_extend = decode(sub_d, WarrantExtend)
            else
                skip(d, wire_type)
            end
        end
        return WarrantQuote(symbol, last_done, prev_close, open, high, low, timestamp, volume, turnover, trade_status, warrant_extend)
    end


    # 轮证行情响应
    struct WarrantQuoteResponse
        secu_quote::Vector{WarrantQuote}
    end
    WarrantQuoteResponse() = WarrantQuoteResponse(WarrantQuote[])
    default_values(::Type{WarrantQuoteResponse}) = (;secu_quote = WarrantQuote[])
    field_numbers(::Type{WarrantQuoteResponse}) = (;secu_quote = 2)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:WarrantQuoteResponse})
        secu_quote = WarrantQuote[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 2
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(secu_quote, decode(sub_d, WarrantQuote))
            else
                skip(d, wire_type)
            end
        end
        return WarrantQuoteResponse(secu_quote)
    end


    # 行权价信息
    struct StrikePriceInfo
        price::String
        call_symbol::String
        put_symbol::String
        standard::ProtoBuf.Bool
    end
    default_values(::Type{StrikePriceInfo}) = (;price = "", call_symbol = "", put_symbol = "", standard = false)
    field_numbers(::Type{StrikePriceInfo}) = (;price = 1, call_symbol = 2, put_symbol = 3, standard = 4)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:StrikePriceInfo})
        price = ""
        call_symbol = ""
        put_symbol = ""
        standard = false
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                price = decode(d, String)
            elseif field_number == 2
                call_symbol = decode(d, String)
            elseif field_number == 3
                put_symbol = decode(d, String)
            elseif field_number == 4
                standard = decode(d, Bool)
            else
                skip(d, wire_type)
            end
        end
        return StrikePriceInfo(price, call_symbol, put_symbol, standard)
    end

    # 证券盘口响应
    struct SecurityDepthResponse
        symbol::String
        ask::Vector{Depth}
        bid::Vector{Depth}
    end
    
    default_values(::Type{SecurityDepthResponse}) = (;symbol = "", ask = Depth[], bid = Depth[])
    field_numbers(::Type{SecurityDepthResponse}) = (;symbol = 1, ask = 2, bid = 3)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityDepthResponse})
        symbol = ""
        ask = Depth[]
        bid = Depth[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                len = decode(d, Int)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(ask, decode(sub_d, Depth))
            elseif field_number == 3
                len = decode(d, Int)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(bid, decode(sub_d, Depth))
            else
                skip(d, wire_type)
            end
        end
        return SecurityDepthResponse(symbol, ask, bid)
    end

    # 经纪队列响应
    struct SecurityBrokersResponse
        symbol::String
        ask_brokers::Vector{Brokers}
        bid_brokers::Vector{Brokers}
    end

    default_values(::Type{SecurityBrokersResponse}) = (;symbol = "", ask_brokers = Brokers[], bid_brokers = Brokers[])
    field_numbers(::Type{SecurityBrokersResponse}) = (;symbol = 1, ask_brokers = 2, bid_brokers = 3)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityBrokersResponse})
        symbol = ""
        ask_brokers = Brokers[]
        bid_brokers = Brokers[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                symbol = decode(d, String)
            elseif field_number == 2
                len = decode(d, Int)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(ask_brokers, decode(sub_d, Brokers))
            elseif field_number == 3
                len = decode(d, Int)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(bid_brokers, decode(sub_d, Brokers))
            else
                skip(d, wire_type)
            end
        end
        return SecurityBrokersResponse(symbol, ask_brokers, bid_brokers)
    end

    struct ParticipantInfo
        broker_ids::Vector{Int64}
        participant_name_cn::String
        participant_name_en::String
        participant_name_hk::String
    end

    default_values(::Type{ParticipantInfo}) = (;broker_ids = Int64[], participant_name_cn = "", participant_name_en = "", participant_name_hk = "")
    field_numbers(::Type{ParticipantInfo}) = (;broker_ids = 1, participant_name_cn = 2, participant_name_en = 3, participant_name_hk = 4)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:ParticipantInfo})
        broker_ids = BufferedVector{Int64}()
        participant_name_cn = ""
        participant_name_en = ""
        participant_name_hk = ""
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                decode!(d, wire_type, broker_ids)
            elseif field_number == 2
                participant_name_cn = decode(d, String)
            elseif field_number == 3
                participant_name_en = decode(d, String)
            elseif field_number == 4
                participant_name_hk = decode(d, String)
            else
                skip(d, wire_type)
            end
        end
        return ParticipantInfo(getindex(broker_ids), participant_name_cn, participant_name_en, participant_name_hk)
    end

    struct ParticipantBrokerIdsResponse
        participant_broker_numbers::Vector{ParticipantInfo}
    end

    ParticipantBrokerIdsResponse() = ParticipantBrokerIdsResponse(ParticipantInfo[])
    default_values(::Type{ParticipantBrokerIdsResponse}) = (;participant_broker_numbers = ParticipantInfo[])
    field_numbers(::Type{ParticipantBrokerIdsResponse}) = (;participant_broker_numbers = 1)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:ParticipantBrokerIdsResponse})
        participant_broker_numbers = ParticipantInfo[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                len = decode(d, UInt64)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(participant_broker_numbers, decode(sub_d, ParticipantInfo))
            else
                skip(d, wire_type)
            end
        end
        return ParticipantBrokerIdsResponse(participant_broker_numbers)
    end

end # module
