# 基于官方 api.proto 的Julia实现  https://github.com/longportapp/openapi-protobufs/blob/main/quote/api.proto
# 专门用于行情 WebSocket 协议的 Protocol Buffer 消息

module QuoteProtocol

    using ProtoBuf
    import ProtoBuf: ProtoDecoder, decode, encode, _encoded_size, skip, message_done, decode_tag, default_values, field_numbers
    using ProtoBuf.EnumX: @enumx
    import Base: show

    export QuoteCommand, SubType, TradeStatus, TradeSession, AdjustType, CandlePeriod, PushQuoteTag, CalcIndex,     # 枚举类型Enums
           
           SecurityRequest, MultiSecurityRequest, SecurityStaticInfo, SecurityStaticInfoResponse,             # 结构体类型Struct
           PrePostQuote, SecurityQuote, SecurityQuoteResponse,
           
           HistoryCandlestickQueryType, Direction,                                                            # 枚举类型Enums

           QuoteSubscribeRequest, QuoteUnsubscribeRequest, QuoteUnsubscribeResponse,                          # 结构体类型Struct
           
           Depth, Brokers, Transaction, Candlestick, PushQuote, PushDepth, PushBrokers, PushTransaction,      # 结构体类型Struct
           OptionExtend, WarrantExtend, StrikePriceInfo,  SecurityDepthResponse
           
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

    # 证券静态信息
    struct SecurityStaticInfo
        symbol::String
        name_cn::String
        name_en::String
        name_hk::String
        listing_date::String
        exchange::String
        currency::String
        lot_size::Int32
        total_shares::Int64
        circulating_shares::Int64
        hk_shares::Int64
        eps::String
        eps_ttm::String
        bps::String
        dividend_yield::String
        stock_derivatives::Vector{Int32}
        board::String
    end
    default_values(::Type{SecurityStaticInfo}) = (;symbol = "", name_cn = "", name_en = "", name_hk = "", listing_date = "", exchange = "", currency = "", lot_size = zero(Int32), total_shares = zero(Int64), circulating_shares = zero(Int64), hk_shares = zero(Int64), eps = "", eps_ttm = "", bps = "", dividend_yield = "", stock_derivatives = Int32[], board = "")
    field_numbers(::Type{SecurityStaticInfo}) = (;symbol = 1, name_cn = 2, name_en = 3, name_hk = 4, listing_date = 5, exchange = 6, currency = 7, lot_size = 8, total_shares = 9, circulating_shares = 10, hk_shares = 11, eps = 12, eps_ttm = 13, bps = 14, dividend_yield = 15, stock_derivatives = 16, board = 17)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityStaticInfo})
        symbol = ""
        name_cn = ""
        name_en = ""
        name_hk = ""
        listing_date = ""
        exchange = ""
        currency = ""
        lot_size = zero(Int32)
        total_shares = zero(Int64)
        circulating_shares = zero(Int64)
        hk_shares = zero(Int64)
        eps = ""
        eps_ttm = ""
        bps = ""
        dividend_yield = ""
        stock_derivatives = Int32[]
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
                lot_size = decode(d, Int32)
            elseif field_number == 9
                total_shares = decode(d, Int64)
            elseif field_number == 10
                circulating_shares = decode(d, Int64)
            elseif field_number == 11
                hk_shares = decode(d, Int64)
            elseif field_number == 12
                eps = decode(d, String)
            elseif field_number == 13
                eps_ttm = decode(d, String)
            elseif field_number == 14
                bps = decode(d, String)
            elseif field_number == 15
                dividend_yield = decode(d, String)
            elseif field_number == 16
                decode!(d, wire_type, stock_derivatives)
            elseif field_number == 17
                board = decode(d, String)
            else
                skip(d, wire_type)
            end
        end
        return SecurityStaticInfo(symbol, name_cn, name_en, name_hk, listing_date, exchange, currency, lot_size, total_shares, circulating_shares, hk_shares, eps, eps_ttm, bps, dividend_yield, stock_derivatives, board)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::SecurityStaticInfo)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        !isempty(x.name_cn) && encode(e, 2, x.name_cn)
        !isempty(x.name_en) && encode(e, 3, x.name_en)
        !isempty(x.name_hk) && encode(e, 4, x.name_hk)
        !isempty(x.listing_date) && encode(e, 5, x.listing_date)
        !isempty(x.exchange) && encode(e, 6, x.exchange)
        !isempty(x.currency) && encode(e, 7, x.currency)
        x.lot_size != zero(Int32) && encode(e, 8, x.lot_size)
        x.total_shares != zero(Int64) && encode(e, 9, x.total_shares)
        x.circulating_shares != zero(Int64) && encode(e, 10, x.circulating_shares)
        x.hk_shares != zero(Int64) && encode(e, 11, x.hk_shares)
        !isempty(x.eps) && encode(e, 12, x.eps)
        !isempty(x.eps_ttm) && encode(e, 13, x.eps_ttm)
        !isempty(x.bps) && encode(e, 14, x.bps)
        !isempty(x.dividend_yield) && encode(e, 15, x.dividend_yield)
        !isempty(x.stock_derivatives) && encode(e, 16, x.stock_derivatives)
        !isempty(x.board) && encode(e, 17, x.board)
        return position(e.io) - initpos
    end
    function _encoded_size(x::SecurityStaticInfo)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        !isempty(x.name_cn) && (encoded_size += _encoded_size(x.name_cn, 2))
        !isempty(x.name_en) && (encoded_size += _encoded_size(x.name_en, 3))
        !isempty(x.name_hk) && (encoded_size += _encoded_size(x.name_hk, 4))
        !isempty(x.listing_date) && (encoded_size += _encoded_size(x.listing_date, 5))
        !isempty(x.exchange) && (encoded_size += _encoded_size(x.exchange, 6))
        !isempty(x.currency) && (encoded_size += _encoded_size(x.currency, 7))
        x.lot_size != zero(Int32) && (encoded_size += _encoded_size(x.lot_size, 8))
        x.total_shares != zero(Int64) && (encoded_size += _encoded_size(x.total_shares, 9))
        x.circulating_shares != zero(Int64) && (encoded_size += _encoded_size(x.circulating_shares, 10))
        x.hk_shares != zero(Int64) && (encoded_size += _encoded_size(x.hk_shares, 11))
        !isempty(x.eps) && (encoded_size += _encoded_size(x.eps, 12))
        !isempty(x.eps_ttm) && (encoded_size += _encoded_size(x.eps_ttm, 13))
        !isempty(x.bps) && (encoded_size += _encoded_size(x.bps, 14))
        !isempty(x.dividend_yield) && (encoded_size += _encoded_size(x.dividend_yield, 15))
        !isempty(x.stock_derivatives) && (encoded_size += _encoded_size(x.stock_derivatives, 16))
        !isempty(x.board) && (encoded_size += _encoded_size(x.board, 17))
        return encoded_size
    end

    # 证券静态信息响应
    struct SecurityStaticInfoResponse
        secu_static_info::Vector{SecurityStaticInfo}
    end
    default_values(::Type{SecurityStaticInfoResponse}) = (;secu_static_info = SecurityStaticInfo[])
    field_numbers(::Type{SecurityStaticInfoResponse}) = (;secu_static_info = 1)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityStaticInfoResponse})
        secu_static_info = SecurityStaticInfo[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                decode!(d, wire_type, secu_static_info)
            else
                skip(d, wire_type)
            end
        end
        return SecurityStaticInfoResponse(secu_static_info)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::SecurityStaticInfoResponse)
        initpos = position(e.io)
        !isempty(x.secu_static_info) && encode(e, 1, x.secu_static_info)
        return position(e.io) - initpos
    end
    function _encoded_size(x::SecurityStaticInfoResponse)
        encoded_size = 0
        !isempty(x.secu_static_info) && (encoded_size += _encoded_size(x.secu_static_info, 1))
        return encoded_size
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
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::PrePostQuote)
        initpos = position(e.io)
        x.last_done != 0.0 && encode(e, 1, string(x.last_done))
        x.timestamp != zero(Int64) && encode(e, 2, x.timestamp)
        x.volume != zero(Int64) && encode(e, 3, x.volume)
        x.turnover != 0.0 && encode(e, 4, string(x.turnover))
        x.high != 0.0 && encode(e, 5, string(x.high))
        x.low != 0.0 && encode(e, 6, string(x.low))
        x.prev_close != 0.0 && encode(e, 7, string(x.prev_close))
        return position(e.io) - initpos
    end
    function _encoded_size(x::PrePostQuote)
        encoded_size = 0
        x.last_done != 0.0 && (encoded_size += _encoded_size(string(x.last_done), 1))
        x.timestamp != zero(Int64) && (encoded_size += _encoded_size(x.timestamp, 2))
        x.volume != zero(Int64) && (encoded_size += _encoded_size(x.volume, 3))
        x.turnover != 0.0 && (encoded_size += _encoded_size(string(x.turnover), 4))
        x.high != 0.0 && (encoded_size += _encoded_size(string(x.high), 5))
        x.low != 0.0 && (encoded_size += _encoded_size(string(x.low), 6))
        x.prev_close != 0.0 && (encoded_size += _encoded_size(string(x.prev_close), 7))
        return encoded_size
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
        timestamp = 0,
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
        timestamp = 0
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
                    len = decode(d, UInt32)
                    sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                    pre_market_quote = decode(sub_d, PrePostQuote)
                elseif field_number == 12
                    len = decode(d, UInt32)
                    sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                    post_market_quote = decode(sub_d, PrePostQuote)
                elseif field_number == 13
                    len = decode(d, UInt32)
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
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::SecurityQuote)
        initpos = position(e.io)

        !isempty(x.symbol) && encode(e, 1, x.symbol)
        x.last_done != 0.0 && encode(e, 2, string(x.last_done))
        x.prev_close != 0.0 && encode(e, 3, string(x.prev_close))
        x.open != 0.0 && encode(e, 4, string(x.open))
        x.high != 0.0 && encode(e, 5, string(x.high))
        x.low != 0.0 && encode(e, 6, string(x.low))
        x.timestamp != 0 && encode(e, 7, x.timestamp)
        x.volume != 0 && encode(e, 8, x.volume)
        x.turnover != 0.0 && encode(e, 9, string(x.turnover))
        x.trade_status != TradeStatus.Normal && encode(e, 10, x.trade_status)
        x.pre_market_quote !== nothing && encode(e, 11, x.pre_market_quote)
        x.post_market_quote !== nothing && encode(e, 12, x.post_market_quote)
        x.over_night_quote !== nothing && encode(e, 13, x.over_night_quote)

        return position(e.io) - initpos
    end
    function _encoded_size(x::SecurityQuote)
        encoded_size = 0

        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        x.last_done != 0.0 && (encoded_size += _encoded_size(string(x.last_done), 2))
        x.prev_close != 0.0 && (encoded_size += _encoded_size(string(x.prev_close), 3))
        x.open != 0.0 && (encoded_size += _encoded_size(string(x.open), 4))
        x.high != 0.0 && (encoded_size += _encoded_size(string(x.high), 5))
        x.low != 0.0 && (encoded_size += _encoded_size(string(x.low), 6))
        x.timestamp != 0 && (encoded_size += _encoded_size(x.timestamp, 7))
        x.volume != 0 && (encoded_size += _encoded_size(x.volume, 8))
        x.turnover != 0.0 && (encoded_size += _encoded_size(string(x.turnover), 9))
        x.trade_status != TradeStatus.Normal && (encoded_size += _encoded_size(x.trade_status, 10))
        x.pre_market_quote !== nothing && (encoded_size += _encoded_size(x.pre_market_quote, 11))
        x.post_market_quote !== nothing && (encoded_size += _encoded_size(x.post_market_quote, 12))
        x.over_night_quote !== nothing && (encoded_size += _encoded_size(x.over_night_quote, 13))

        return encoded_size
    end

    # 证券行情响应
    struct SecurityQuoteResponse
        secu_quote::Vector{SecurityQuote}
    end
    default_values(::Type{SecurityQuoteResponse}) = (;secu_quote = SecurityQuote[])
    field_numbers(::Type{SecurityQuoteResponse}) = (;secu_quote = 1)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityQuoteResponse})
        secu_quote = SecurityQuote[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                len = decode(d, UInt32)
                sub_d = ProtoDecoder(IOBuffer(read(d.io, len)))
                push!(secu_quote, decode(sub_d, SecurityQuote))
            else
                skip(d, wire_type)
            end
        end
        return SecurityQuoteResponse(secu_quote)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::SecurityQuoteResponse)
        initpos = position(e.io)
        for _quote in x.secu_quote
            encode(e, 1, _quote)
        end
        return position(e.io) - initpos
    end
    function _encoded_size(x::SecurityQuoteResponse)
        encoded_size = 0
        for _quote in x.secu_quote
            encoded_size += _encoded_size(_quote, 1)
        end
        return encoded_size
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
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::QuoteUnsubscribeResponse)
        return 0
    end
    function _encoded_size(x::QuoteUnsubscribeResponse)
        return 0
    end

    # 盘口数据
    struct Depth
        position::Int32
        price::String
        volume::Int64
        order_num::Int64
    end
    default_values(::Type{Depth}) = (;position = zero(Int32), price = "", volume = zero(Int64), order_num = zero(Int64))
    field_numbers(::Type{Depth}) = (;position = 1, price = 2, volume = 3, order_num = 4)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:Depth})
        position = zero(Int32)
        price = ""
        volume = zero(Int64)
        order_num = zero(Int64)
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                position = decode(d, Int32)
            elseif field_number == 2
                price = decode(d, String)
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
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::Depth)
        initpos = position(e.io)
        x.position != zero(Int32) && encode(e, 1, x.position)
        !isempty(x.price) && encode(e, 2, x.price)
        x.volume != zero(Int64) && encode(e, 3, x.volume)
        x.order_num != zero(Int64) && encode(e, 4, x.order_num)
        return position(e.io) - initpos
    end
    function _encoded_size(x::Depth)
        encoded_size = 0
        x.position != zero(Int32) && (encoded_size += _encoded_size(x.position, 1))
        !isempty(x.price) && (encoded_size += _encoded_size(x.price, 2))
        x.volume != zero(Int64) && (encoded_size += _encoded_size(x.volume, 3))
        x.order_num != zero(Int64) && (encoded_size += _encoded_size(x.order_num, 4))
        return encoded_size
    end

    # 经纪队列
    struct Brokers
        position::Int32
        broker_ids::Vector{Int32}
    end
    default_values(::Type{Brokers}) = (;position = zero(Int32), broker_ids = Int32[])
    field_numbers(::Type{Brokers}) = (;position = 1, broker_ids = 2)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:Brokers})
        position = zero(Int32)
        broker_ids = Int32[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                position = decode(d, Int32)
            elseif field_number == 2
                decode!(d, wire_type, broker_ids)
            else
                skip(d, wire_type)
            end
        end
        return Brokers(position, broker_ids)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::Brokers)
        initpos = position(e.io)
        x.position != zero(Int32) && encode(e, 1, x.position)
        !isempty(x.broker_ids) && encode(e, 2, x.broker_ids)
        return position(e.io) - initpos
    end
    function _encoded_size(x::Brokers)
        encoded_size = 0
        x.position != zero(Int32) && (encoded_size += _encoded_size(x.position, 1))
        !isempty(x.broker_ids) && (encoded_size += _encoded_size(x.broker_ids, 2))
        return encoded_size
    end

    # 成交明细
    struct Transaction
        price::String
        volume::Int64
        timestamp::Int64
        trade_type::String
        direction::Int32
        trade_session::TradeSession.T
    end
    default_values(::Type{Transaction}) = (;price = "", volume = zero(Int64), timestamp = zero(Int64), trade_type = "", direction = zero(Int32), trade_session = TradeSession.Intraday)
    field_numbers(::Type{Transaction}) = (;price = 1, volume = 2, timestamp = 3, trade_type = 4, direction = 5, trade_session = 6)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:Transaction})
        price = ""
        volume = zero(Int64)
        timestamp = zero(Int64)
        trade_type = ""
        direction = zero(Int32)
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
                direction = decode(d, Int32)
            elseif field_number == 6
                trade_session = decode(d, TradeSession.T)
            else
                skip(d, wire_type)
            end
        end
        return Transaction(price, volume, timestamp, trade_type, direction, trade_session)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::Transaction)
        initpos = position(e.io)
        !isempty(x.price) && encode(e, 1, x.price)
        x.volume != zero(Int64) && encode(e, 2, x.volume)
        x.timestamp != zero(Int64) && encode(e, 3, x.timestamp)
        !isempty(x.trade_type) && encode(e, 4, x.trade_type)
        x.direction != zero(Int32) && encode(e, 5, x.direction)
        x.trade_session != TradeSession.Intraday && encode(e, 6, x.trade_session)
        return position(e.io) - initpos
    end
    function _encoded_size(x::Transaction)
        encoded_size = 0
        !isempty(x.price) && (encoded_size += _encoded_size(x.price, 1))
        x.volume != zero(Int64) && (encoded_size += _encoded_size(x.volume, 2))
        x.timestamp != zero(Int64) && (encoded_size += _encoded_size(x.timestamp, 3))
        !isempty(x.trade_type) && (encoded_size += _encoded_size(x.trade_type, 4))
        x.direction != zero(Int32) && (encoded_size += _encoded_size(x.direction, 5))
        x.trade_session != TradeSession.Intraday && (encoded_size += _encoded_size(x.trade_session, 6))
        return encoded_size
    end

    # K线数据
    struct Candlestick
        close::String
        open::String
        low::String
        high::String
        volume::Int64
        turnover::String
        timestamp::Int64
        trade_session::TradeSession.T
    end
    default_values(::Type{Candlestick}) = (;close = "", open = "", low = "", high = "", volume = zero(Int64), turnover = "", timestamp = zero(Int64), trade_session = TradeSession.Intraday)
    field_numbers(::Type{Candlestick}) = (;close = 1, open = 2, low = 3, high = 4, volume = 5, turnover = 6, timestamp = 7, trade_session = 8)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:Candlestick})
        close = ""
        open = ""
        low = ""
        high = ""
        volume = zero(Int64)
        turnover = ""
        timestamp = zero(Int64)
        trade_session = TradeSession.Intraday
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                close = decode(d, String)
            elseif field_number == 2
                open = decode(d, String)
            elseif field_number == 3
                low = decode(d, String)
            elseif field_number == 4
                high = decode(d, String)
            elseif field_number == 5
                volume = decode(d, Int64)
            elseif field_number == 6
                turnover = decode(d, String)
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
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::Candlestick)
        initpos = position(e.io)
        !isempty(x.close) && encode(e, 1, x.close)
        !isempty(x.open) && encode(e, 2, x.open)
        !isempty(x.low) && encode(e, 3, x.low)
        !isempty(x.high) && encode(e, 4, x.high)
        x.volume != zero(Int64) && encode(e, 5, x.volume)
        !isempty(x.turnover) && encode(e, 6, x.turnover)
        x.timestamp != zero(Int64) && encode(e, 7, x.timestamp)
        x.trade_session != TradeSession.Intraday && encode(e, 8, x.trade_session)
        return position(e.io) - initpos
    end
    function _encoded_size(x::Candlestick)
        encoded_size = 0
        !isempty(x.close) && (encoded_size += _encoded_size(x.close, 1))
        !isempty(x.open) && (encoded_size += _encoded_size(x.open, 2))
        !isempty(x.low) && (encoded_size += _encoded_size(x.low, 3))
        !isempty(x.high) && (encoded_size += _encoded_size(x.high, 4))
        x.volume != zero(Int64) && (encoded_size += _encoded_size(x.volume, 5))
        !isempty(x.turnover) && (encoded_size += _encoded_size(x.turnover, 6))
        x.timestamp != zero(Int64) && (encoded_size += _encoded_size(x.timestamp, 7))
        x.trade_session != TradeSession.Intraday && (encoded_size += _encoded_size(x.trade_session, 8))
        return encoded_size
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
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::PushQuote)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        x.sequence != zero(Int64) && encode(e, 2, x.sequence)
        x.last_done != 0.0 && encode(e, 3, string(x.last_done))
        x.open != 0.0 && encode(e, 4, string(x.open))
        x.high != 0.0 && encode(e, 5, string(x.high))
        x.low != 0.0 && encode(e, 6, string(x.low))
        x.timestamp != zero(Int64) && encode(e, 7, x.timestamp)
        x.volume != zero(Int64) && encode(e, 8, x.volume)
        x.turnover != 0.0 && encode(e, 9, string(x.turnover))
        x.trade_status != TradeStatus.Normal && encode(e, 10, x.trade_status)
        x.trade_session != TradeSession.Intraday && encode(e, 11, x.trade_session)
        x.current_volume != zero(Int64) && encode(e, 12, x.current_volume)
        x.current_turnover != 0.0 && encode(e, 13, string(x.current_turnover))
        x.tag != PushQuoteTag.Normal && encode(e, 14, x.tag)
        return position(e.io) - initpos
    end
    function _encoded_size(x::PushQuote)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        x.sequence != zero(Int64) && (encoded_size += _encoded_size(x.sequence, 2))
        x.last_done != 0.0 && (encoded_size += _encoded_size(string(x.last_done), 3))
        x.open != 0.0 && (encoded_size += _encoded_size(string(x.open), 4))
        x.high != 0.0 && (encoded_size += _encoded_size(string(x.high), 5))
        x.low != 0.0 && (encoded_size += _encoded_size(string(x.low), 6))
        x.timestamp != zero(Int64) && (encoded_size += _encoded_size(x.timestamp, 7))
        x.volume != zero(Int64) && (encoded_size += _encoded_size(x.volume, 8))
        x.turnover != 0.0 && (encoded_size += _encoded_size(string(x.turnover), 9))
        x.trade_status != TradeStatus.Normal && (encoded_size += _encoded_size(x.trade_status, 10))
        x.trade_session != TradeSession.Intraday && (encoded_size += _encoded_size(x.trade_session, 11))
        x.current_volume != zero(Int64) && (encoded_size += _encoded_size(x.current_volume, 12))
        x.current_turnover != 0.0 && (encoded_size += _encoded_size(string(x.current_turnover), 13))
        x.tag != PushQuoteTag.Normal && (encoded_size += _encoded_size(x.tag, 14))
        return encoded_size
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
                decode!(d, wire_type, ask)
            elseif field_number == 4
                decode!(d, wire_type, bid)
            else
                skip(d, wire_type)
            end
        end
        return PushDepth(symbol, sequence, ask, bid)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::PushDepth)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        x.sequence != zero(Int64) && encode(e, 2, x.sequence)
        !isempty(x.ask) && encode(e, 3, x.ask)
        !isempty(x.bid) && encode(e, 4, x.bid)
        return position(e.io) - initpos
    end
    function _encoded_size(x::PushDepth)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        x.sequence != zero(Int64) && (encoded_size += _encoded_size(x.sequence, 2))
        !isempty(x.ask) && (encoded_size += _encoded_size(x.ask, 3))
        !isempty(x.bid) && (encoded_size += _encoded_size(x.bid, 4))
        return encoded_size
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
                decode!(d, wire_type, ask_brokers)
            elseif field_number == 4
                decode!(d, wire_type, bid_brokers)
            else
                skip(d, wire_type)
            end
        end
        return PushBrokers(symbol, sequence, ask_brokers, bid_brokers)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::PushBrokers)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        x.sequence != zero(Int64) && encode(e, 2, x.sequence)
        !isempty(x.ask_brokers) && encode(e, 3, x.ask_brokers)
        !isempty(x.bid_brokers) && encode(e, 4, x.bid_brokers)
        return position(e.io) - initpos
    end
    function _encoded_size(x::PushBrokers)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        x.sequence != zero(Int64) && (encoded_size += _encoded_size(x.sequence, 2))
        !isempty(x.ask_brokers) && (encoded_size += _encoded_size(x.ask_brokers, 3))
        !isempty(x.bid_brokers) && (encoded_size += _encoded_size(x.bid_brokers, 4))
        return encoded_size
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
                decode!(d, wire_type, transaction)
            else
                skip(d, wire_type)
            end
        end
        return PushTransaction(symbol, sequence, transaction)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::PushTransaction)
        initpos = position(e.io)
        !isempty(x.symbol) && encode(e, 1, x.symbol)
        x.sequence != zero(Int64) && encode(e, 2, x.sequence)
        !isempty(x.transaction) && encode(e, 3, x.transaction)
        return position(e.io) - initpos
    end
    function _encoded_size(x::PushTransaction)
        encoded_size = 0
        !isempty(x.symbol) && (encoded_size += _encoded_size(x.symbol, 1))
        x.sequence != zero(Int64) && (encoded_size += _encoded_size(x.sequence, 2))
        !isempty(x.transaction) && (encoded_size += _encoded_size(x.transaction, 3))
        return encoded_size
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
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::OptionExtend)
        initpos = position(e.io)
        !isempty(x.implied_volatility) && encode(e, 1, x.implied_volatility)
        x.open_interest != zero(Int64) && encode(e, 2, x.open_interest)
        !isempty(x.expiry_date) && encode(e, 3, x.expiry_date)
        !isempty(x.strike_price) && encode(e, 4, x.strike_price)
        !isempty(x.contract_multiplier) && encode(e, 5, x.contract_multiplier)
        !isempty(x.contract_type) && encode(e, 6, x.contract_type)
        !isempty(x.contract_size) && encode(e, 7, x.contract_size)
        !isempty(x.direction) && encode(e, 8, x.direction)
        !isempty(x.historical_volatility) && encode(e, 9, x.historical_volatility)
        !isempty(x.underlying_symbol) && encode(e, 10, x.underlying_symbol)
        return position(e.io) - initpos
    end
    function _encoded_size(x::OptionExtend)
        encoded_size = 0
        !isempty(x.implied_volatility) && (encoded_size += _encoded_size(x.implied_volatility, 1))
        x.open_interest != zero(Int64) && (encoded_size += _encoded_size(x.open_interest, 2))
        !isempty(x.expiry_date) && (encoded_size += _encoded_size(x.expiry_date, 3))
        !isempty(x.strike_price) && (encoded_size += _encoded_size(x.strike_price, 4))
        !isempty(x.contract_multiplier) && (encoded_size += _encoded_size(x.contract_multiplier, 5))
        !isempty(x.contract_type) && (encoded_size += _encoded_size(x.contract_type, 6))
        !isempty(x.contract_size) && (encoded_size += _encoded_size(x.contract_size, 7))
        !isempty(x.direction) && (encoded_size += _encoded_size(x.direction, 8))
        !isempty(x.historical_volatility) && (encoded_size += _encoded_size(x.historical_volatility, 9))
        !isempty(x.underlying_symbol) && (encoded_size += _encoded_size(x.underlying_symbol, 10))
        return encoded_size
    end

    # 权证扩展信息
    struct WarrantExtend
        implied_volatility::String
        expiry_date::String
        last_trade_date::String
        outstanding_ratio::String
        outstanding_qty::Int64
        conversion_ratio::String
        category::String
        strike_price::String
        upper_strike_price::String
        lower_strike_price::String
        call_price::String
        underlying_symbol::String
    end
    default_values(::Type{WarrantExtend}) = (;implied_volatility = "", expiry_date = "", last_trade_date = "", outstanding_ratio = "", outstanding_qty = zero(Int64), conversion_ratio = "", category = "", strike_price = "", upper_strike_price = "", lower_strike_price = "", call_price = "", underlying_symbol = "")
    field_numbers(::Type{WarrantExtend}) = (;implied_volatility = 1, expiry_date = 2, last_trade_date = 3, outstanding_ratio = 4, outstanding_qty = 5, conversion_ratio = 6, category = 7, strike_price = 8, upper_strike_price = 9, lower_strike_price = 10, call_price = 11, underlying_symbol = 12)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:WarrantExtend})
        implied_volatility = ""
        expiry_date = ""
        last_trade_date = ""
        outstanding_ratio = ""
        outstanding_qty = zero(Int64)
        conversion_ratio = ""
        category = ""
        strike_price = ""
        upper_strike_price = ""
        lower_strike_price = ""
        call_price = ""
        underlying_symbol = ""
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                implied_volatility = decode(d, String)
            elseif field_number == 2
                expiry_date = decode(d, String)
            elseif field_number == 3
                last_trade_date = decode(d, String)
            elseif field_number == 4
                outstanding_ratio = decode(d, String)
            elseif field_number == 5
                outstanding_qty = decode(d, Int64)
            elseif field_number == 6
                conversion_ratio = decode(d, String)
            elseif field_number == 7
                category = decode(d, String)
            elseif field_number == 8
                strike_price = decode(d, String)
            elseif field_number == 9
                upper_strike_price = decode(d, String)
            elseif field_number == 10
                lower_strike_price = decode(d, String)
            elseif field_number == 11
                call_price = decode(d, String)
            elseif field_number == 12
                underlying_symbol = decode(d, String)
            else
                skip(d, wire_type)
            end
        end
        return WarrantExtend(implied_volatility, expiry_date, last_trade_date, outstanding_ratio, outstanding_qty, conversion_ratio, category, strike_price, upper_strike_price, lower_strike_price, call_price, underlying_symbol)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::WarrantExtend)
        initpos = position(e.io)
        !isempty(x.implied_volatility) && encode(e, 1, x.implied_volatility)
        !isempty(x.expiry_date) && encode(e, 2, x.expiry_date)
        !isempty(x.last_trade_date) && encode(e, 3, x.last_trade_date)
        !isempty(x.outstanding_ratio) && encode(e, 4, x.outstanding_ratio)
        x.outstanding_qty != zero(Int64) && encode(e, 5, x.outstanding_qty)
        !isempty(x.conversion_ratio) && encode(e, 6, x.conversion_ratio)
        !isempty(x.category) && encode(e, 7, x.category)
        !isempty(x.strike_price) && encode(e, 8, x.strike_price)
        !isempty(x.upper_strike_price) && encode(e, 9, x.upper_strike_price)
        !isempty(x.lower_strike_price) && encode(e, 10, x.lower_strike_price)
        !isempty(x.call_price) && encode(e, 11, x.call_price)
        !isempty(x.underlying_symbol) && encode(e, 12, x.underlying_symbol)
        return position(e.io) - initpos
    end
    function _encoded_size(x::WarrantExtend)
        encoded_size = 0
        !isempty(x.implied_volatility) && (encoded_size += _encoded_size(x.implied_volatility, 1))
        !isempty(x.expiry_date) && (encoded_size += _encoded_size(x.expiry_date, 2))
        !isempty(x.last_trade_date) && (encoded_size += _encoded_size(x.last_trade_date, 3))
        !isempty(x.outstanding_ratio) && (encoded_size += _encoded_size(x.outstanding_ratio, 4))
        x.outstanding_qty != zero(Int64) && (encoded_size += _encoded_size(x.outstanding_qty, 5))
        !isempty(x.conversion_ratio) && (encoded_size += _encoded_size(x.conversion_ratio, 6))
        !isempty(x.category) && (encoded_size += _encoded_size(x.category, 7))
        !isempty(x.strike_price) && (encoded_size += _encoded_size(x.strike_price, 8))
        !isempty(x.upper_strike_price) && (encoded_size += _encoded_size(x.upper_strike_price, 9))
        !isempty(x.lower_strike_price) && (encoded_size += _encoded_size(x.lower_strike_price, 10))
        !isempty(x.call_price) && (encoded_size += _encoded_size(x.call_price, 11))
        !isempty(x.underlying_symbol) && (encoded_size += _encoded_size(x.underlying_symbol, 12))
        return encoded_size
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
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::StrikePriceInfo)
        initpos = position(e.io)
        !isempty(x.price) && encode(e, 1, x.price)
        !isempty(x.call_symbol) && encode(e, 2, x.call_symbol)
        !isempty(x.put_symbol) && encode(e, 3, x.put_symbol)
        x.standard != false && encode(e, 4, x.standard)
        return position(e.io) - initpos
    end
    function _encoded_size(x::StrikePriceInfo)
        encoded_size = 0
        !isempty(x.price) && (encoded_size += _encoded_size(x.price, 1))
        !isempty(x.call_symbol) && (encoded_size += _encoded_size(x.call_symbol, 2))
        !isempty(x.put_symbol) && (encoded_size += _encoded_size(x.put_symbol, 3))
        x.standard != false && (encoded_size += _encoded_size(x.standard, 4))
        return encoded_size
    end

    # 证券深度响应
    struct SecurityDepthResponse
        ask::Vector{Depth}
        bid::Vector{Depth}
    end
    default_values(::Type{SecurityDepthResponse}) = (;ask = Depth[], bid = Depth[])
    field_numbers(::Type{SecurityDepthResponse}) = (;ask = 1, bid = 2)

    function decode(d::ProtoBuf.AbstractProtoDecoder, ::Type{<:SecurityDepthResponse})
        ask = Depth[]
        bid = Depth[]
        while !message_done(d)
            field_number, wire_type = decode_tag(d)
            if field_number == 1
                decode!(d, wire_type, ask)
            elseif field_number == 2
                decode!(d, wire_type, bid)
            else
                skip(d, wire_type)
            end
        end
        return SecurityDepthResponse(ask, bid)
    end
    function encode(e::ProtoBuf.AbstractProtoEncoder, x::SecurityDepthResponse)
        initpos = position(e.io)
        !isempty(x.ask) && encode(e, 1, x.ask)
        !isempty(x.bid) && encode(e, 2, x.bid)
        return position(e.io) - initpos
    end
    function _encoded_size(x::SecurityDepthResponse)
        encoded_size = 0
        !isempty(x.ask) && (encoded_size += _encoded_size(x.ask, 1))
        !isempty(x.bid) && (encoded_size += _encoded_size(x.bid, 2))
        return encoded_size
    end

end # module
