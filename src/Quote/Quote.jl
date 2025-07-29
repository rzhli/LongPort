module Quote

using ProtoBuf, JSON3, Dates, Logging, DataFrames
using ..Config, ..QuoteTypes, ..Push, ..Client, ..QuoteProtocol, ..ControlProtocol
using ..QuoteProtocol: CandlePeriod, AdjustType, TradeSession, SubType, QuoteCommand, Direction,
        SecurityCandlestickRequest, SecurityCandlestickResponse, QuoteSubscribeRequest,
        QuoteSubscribeResponse, QuoteUnsubscribeRequest, QuoteUnsubscribeResponse, 
        MultiSecurityRequest, SecurityQuoteResponse, SecurityRequest, SecurityDepthResponse,
        SecurityStaticInfo, SecurityStaticInfoResponse, OptionQuoteResponse, 
        WarrantQuoteResponse, SecurityBrokersResponse, ParticipantBrokerIdsResponse,
        SecurityTradeRequest, SecurityTradeResponse, SecurityIntradayRequest, SecurityIntradayResponse,
        SecurityHistoryCandlestickRequest, OffsetQuery, DateQuery, HistoryCandlestickQueryType,
        OptionChainDateListResponse, OptionChainDateStrikeInfoRequest, OptionChainDateStrikeInfoResponse
        
using ..Client: WSClient
using ..Cache: SimpleCache, CacheWithKey, get_or_update
using ..Utils: to_namedtuple
using ..Constant: Language
import ..Errors:LongportException

# A simple wrapper to mimic Rust's Arc for shared ownership semantics
struct Arc{T}
    value::T
end

Base.getproperty(arc::Arc, sym::Symbol) = getproperty(getfield(arc, :value), sym)
Base.setproperty!(arc::Arc, sym::Symbol, x) = setproperty!(getfield(arc, :value), sym, x)

export QuoteContext, 
       try_new, disconnect!,
       realtime_quote, subscribe, unsubscribe, static_info, depth, intraday,
       brokers, trades, candlesticks,
       history_candlesticks_by_offset, history_candlesticks_by_date, 
       option_chain_expiry_date_list, option_chain_info_by_date,
       set_on_quote, set_on_depth, set_on_brokers, set_on_trades, set_on_candlestick,
       
       option_quote, warrant_quote, participants, subscriptions,
       option_chain_dates, option_chain_strikes, warrant_issuers, warrant_filter,
       trading_sessions, trading_days, capital_flow_intraday, capital_flow_distribution,
       calc_indexes, member_id, quote_level, option_chain_expiry_date_list

# --- Command Types for the Core Actor ---
abstract type AbstractCommand end

struct GenericRequestCmd <: AbstractCommand
    cmd_code::QuoteCommand.T
    request_pb::Any
    response_type::Type
    resp_ch::Channel{Any}                   # response channel
end

struct HttpGetCmd <: AbstractCommand
    path::String
    params::Dict
    resp_ch::Channel{Any}           # response channel
end

struct DisconnectCmd <: AbstractCommand end

# --- Core Actor and Context Structs ---

mutable struct InnerQuoteContext
    config::Config.config
    ws_client::Union{WSClient, Nothing}
    command_ch::Channel{Any}
    core_task::Union{Task, Nothing}
    push_dispatcher_task::Union{Task, Nothing}
    callbacks::Push.Callbacks

    # Caches
    cache_participants::SimpleCache{Vector{Any}}
    cache_issuers::SimpleCache{Vector{Any}}
    cache_option_chain_expiry_dates::CacheWithKey{String, Vector{Any}}
    cache_option_chain_strike_info::CacheWithKey{Tuple{String, Any}, Vector{Any}}
    cache_trading_sessions::SimpleCache{Vector{Any}}

    # Info from Core
    member_id::Int64
    quote_level::String
end

@doc """
Quote context handle. It is a lightweight wrapper around the core actor.
"""
struct QuoteContext
    inner::Arc{InnerQuoteContext}
end

# --- Core Actor Logic ---

function core_run(inner::InnerQuoteContext, push_tx::Channel)
    # @info "Quote core actor started."
    should_run = true
    reconnect_attempts = 0

    while should_run
        try
            # 1. Establish Connection
            ws = WSClient(inner.config.quote_ws_url)
            inner.ws_client = ws
            ws.on_push = (cmd, body) -> put!(push_tx, (cmd, body))
            ws.auth_data = Client.create_auth_request(inner.config)
            Client.connect!(ws)
            # @info "Quote WebSocket connected."
            reconnect_attempts = 0 # Reset on successful connection

            # TODO: Fetch member_id and quote_level after connection
            # For now, we'll leave them as default.
            # inner.member_id = ...
            # inner.quote_level = ...

            # 2. Main Command Processing Loop
            for cmd in inner.command_ch
                handle_command(inner, cmd)
                if cmd isa DisconnectCmd
                    should_run = false
                    break
                end
            end

        catch e
            if e isa InvalidStateException && e.state == :closed
                # @warn "Command channel closed, shutting down core actor."
                should_run = false
            elseif e isa LongportException && occursin("WebSocket", e.message)
                reconnect_attempts += 1
                delay = min(60.0, 2.0^reconnect_attempts) # Exponential backoff with max delay
                @warn "Connection failed, attempting to reconnect in $(delay)s..." exception=(e, catch_backtrace())
                sleep(delay)
            else
                @error "Quote core actor failed with an unhandled exception" exception=(e, catch_backtrace())
                should_run = false # Exit on unhandled errors
            end
        finally
            # 3. Cleanup before next loop iteration or exit
            if !isnothing(inner.ws_client)
                Client.disconnect!(inner.ws_client)
                inner.ws_client = nothing
            end
        end
    end

    close(push_tx)
    # @info "Quote core actor stopped."
end

function handle_command(inner::InnerQuoteContext, cmd::AbstractCommand)
    resp = try
        if cmd isa DisconnectCmd
            # No response needed, just break the loop
            nothing
        elseif cmd isa GenericRequestCmd
            # Handle Protobuf requests over WebSocket
            if isnothing(inner.ws_client) || !inner.ws_client.connected
                throw(LongportException("WebSocket not connected"))
            end
            
            local req_body::Vector{UInt8}
            if cmd.request_pb isa Vector{UInt8}
                req_body = cmd.request_pb
            else
                io_buf = IOBuffer()
                encoder = ProtoBuf.ProtoEncoder(io_buf)
                ProtoBuf.encode(encoder, cmd.request_pb)
                req_body = take!(io_buf)
            end

            resp_body = Client.ws_request(inner.ws_client, UInt8(cmd.cmd_code), req_body)

            if isempty(resp_body)
                if cmd.cmd_code == QuoteCommand.Unsubscribe
                    # Unsubscribe sends no response body, this is expected.
                    resp = QuoteUnsubscribeResponse()
                else
                    # @warn "Received empty response for command" cmd_code = cmd.cmd_code
                    resp = cmd.response_type() # Return empty response object
                end
            else
                @info "Received response body" cmd_code=cmd.cmd_code hex_body=bytes2hex(resp_body) length(resp_body)
                decoder = ProtoBuf.ProtoDecoder(IOBuffer(resp_body))
                resp = ProtoBuf.decode(decoder, cmd.response_type)
            end
        elseif cmd isa HttpGetCmd
            # Handle HTTP GET requests
            Client.get(inner.config, cmd.path; params=cmd.params)
        end
    catch e
        @error "Failed to handle command" command=typeof(cmd) exception=(e, catch_backtrace())
        e # Propagate exception as the response
    end

    # Send response back to the caller
    if !(cmd isa DisconnectCmd) && isopen(cmd.resp_ch)
        put!(cmd.resp_ch, resp)
    end
end

# --- Push Dispatcher ---

function dispatch_push_events(ctx::QuoteContext, push_rx::Channel)
    # @info "Push event dispatcher started."
    for (cmd_code, body) in push_rx
        command = QuoteCommand.T(cmd_code)
        io = IOBuffer(body)
        decoder = ProtoBuf.ProtoDecoder(io)
        callbacks = ctx.inner.callbacks

        try
            if command == QuoteCommand.PushQuoteData
                data = ProtoBuf.decode(decoder, QuoteProtocol.PushQuote)
                Push.handle_quote(callbacks, data.symbol, data)
            elseif command == QuoteCommand.PushDepthData
                data = ProtoBuf.decode(decoder, QuoteProtocol.PushDepth)
                Push.handle_depth(callbacks, data.symbol, data)
            elseif command == QuoteCommand.PushBrokersData
                data = ProtoBuf.decode(decoder, QuoteProtocol.PushBrokers)
                Push.handle_brokers(callbacks, data.symbol, data)
            elseif command == QuoteCommand.PushTradeData
                data = ProtoBuf.decode(decoder, QuoteProtocol.PushTrade)
                Push.handle_trades(callbacks, data.symbol, data)
            else
                # @warn "Unknown push command" cmd=cmd_code
            end
        catch e
            @error "Failed to decode or dispatch push event" exception=(e, catch_backtrace())
        end
    end
    # @info "Push event dispatcher stopped."
end


# --- Public API ---

@doc """
Asynchronously creates and initializes a `QuoteContext`.

This is the main entry point for using the quote API. It sets up the WebSocket connection
and the background processing task (Actor).

# Arguments
- `config::Config.config`: The configuration object.

# Returns
- `(QuoteContext, Channel)`: A tuple containing the `QuoteContext` handle and a `Channel` for receiving raw push events.
"""
function try_new(config::Config.config)
    command_ch = Channel{Any}(32)
    push_ch = Channel{Any}(Inf)     # a `Channel` for receiving raw push events

    inner = InnerQuoteContext(
        config,
        nothing, # ws_client
        command_ch,
        nothing, # core_task
        nothing, # push_dispatcher_task
        Push.Callbacks(),
        # Caches
        SimpleCache{Vector{Any}}(1800.0),
        SimpleCache{Vector{Any}}(1800.0),
        CacheWithKey{String, Vector{Any}}(1800.0),
        CacheWithKey{Tuple{String, Any}, Vector{Any}}(1800.0),
        SimpleCache{Vector{Any}}(7200.0),
        # Core info
        0, "",
    )
    
    ctx = QuoteContext(Arc(inner))

    # Start background tasks
    inner.core_task = @async core_run(inner, push_ch)
    inner.push_dispatcher_task = @async dispatch_push_events(ctx, push_ch)

    return (ctx, push_ch)
end

@doc """
Disconnects the WebSocket and shuts down the background actor.
"""
function disconnect!(ctx::QuoteContext)
    inner = ctx.inner
    if !isnothing(inner.core_task) && !istaskdone(inner.core_task)
        put!(inner.command_ch, DisconnectCmd())
        close(inner.command_ch) # Signal shutdown
        wait(inner.core_task)
        if !isnothing(inner.push_dispatcher_task)
            wait(inner.push_dispatcher_task)
        end
        # @info "QuoteContext disconnected and cleaned up."
    end
end

# Internal helper to send a command and wait for response
function request(ctx::QuoteContext, cmd::AbstractCommand)
    put!(ctx.inner.command_ch, cmd)
    resp = take!(cmd.resp_ch)
    if resp isa Exception
        throw(resp)
    end
    return resp
end

# --- Callback Setters ---
function set_on_quote(ctx::QuoteContext, cb::Function); Push.set_on_quote!(ctx.inner.callbacks, cb); end
function set_on_depth(ctx::QuoteContext, cb::Function); Push.set_on_depth!(ctx.inner.callbacks, cb); end
function set_on_brokers(ctx::QuoteContext, cb::Function); Push.set_on_brokers!(ctx.inner.callbacks, cb); end
function set_on_trades(ctx::QuoteContext, cb::Function); Push.set_on_trades!(ctx.inner.callbacks, cb); end
function set_on_candlestick(ctx::QuoteContext, cb::Function); Push.set_on_candlestick!(ctx.inner.callbacks, cb); end

# --- Data API ---

function subscribe(ctx::QuoteContext, symbols::Vector{String}, sub_types::Vector{SubType.T}; is_first_push::Bool=false)
    req = QuoteSubscribeRequest(symbols, sub_types, is_first_push)
    cmd = GenericRequestCmd(QuoteCommand.Subscribe, req, QuoteSubscribeResponse, Channel(1))
    request(ctx, cmd)
    return [(symbol = s, sub_types = sub_types) for s in symbols]
end

function unsubscribe(ctx::QuoteContext, symbols::Vector{String}, sub_types::Vector{SubType.T})
    req = QuoteUnsubscribeRequest(symbols, sub_types, false)
    cmd = GenericRequestCmd(QuoteCommand.Unsubscribe, req, QuoteUnsubscribeResponse, Channel(1))
    request(ctx, cmd)

    return [(symbol = s, sub_types = sub_types) for s in symbols]
end

function realtime_quote(ctx::QuoteContext, symbols::Vector{String})
    req = MultiSecurityRequest(symbols)
    cmd = GenericRequestCmd(QuoteCommand.QuerySecurityQuote, req, SecurityQuoteResponse, Channel(1))
    resp = request(ctx, cmd)
    return to_namedtuple(resp.secu_quote)
end

function candlesticks(
    ctx::QuoteContext, symbol::String, period::CandlePeriod.T = DAY, count::Int64 = 365; 
    trade_sessions::TradeSession.T = TradeSession.Intraday, adjust_type::AdjustType.T = AdjustType.FORWARD_ADJUST
    )
    req = SecurityCandlestickRequest(symbol, period, count, adjust_type, trade_sessions)
    cmd = GenericRequestCmd(QuoteCommand.QueryCandlestick, req, SecurityCandlestickResponse, Channel(1))
    resp = request(ctx, cmd)
    
    data = map(resp.candlesticks) do c
        (
            symbol = resp.symbol,
            close = c.close,
            open = c.open,
            low = c.low,
            high = c.high,
            volume = c.volume,
            turnover = c.turnover,
            timestamp = unix2datetime(c.timestamp)
        )
    end
    return DataFrame(data)
end

function history_candlesticks_by_offset(
    ctx::QuoteContext, symbol::String, period::CandlePeriod.T, adjust_type::AdjustType.T, direction::Direction.T, count::Int; 
    date::Union{DateTime, Nothing}=nothing, trade_sessions::TradeSession.T=TradeSession.Intraday
    )
    
    offset_request = OffsetQuery(
        direction, 
        isnothing(date) ? "" : Dates.format(date, "yyyymmdd"), 
        isnothing(date) ? "" : Dates.format(date, "HHMM"), 
        count
    )

    req = SecurityHistoryCandlestickRequest(symbol, period, adjust_type, HistoryCandlestickQueryType.QUERY_BY_OFFSET, offset_request, nothing, trade_sessions)
    cmd = GenericRequestCmd(QuoteCommand.QueryHistoryCandlestick, req, SecurityCandlestickResponse, Channel(1))
    resp = request(ctx, cmd)

    data = map(resp.candlesticks) do c
        (
            symbol = resp.symbol,
            close = c.close,
            open = c.open,
            low = c.low,
            high = c.high,
            volume = c.volume,
            turnover = c.turnover,
            timestamp = unix2datetime(c.timestamp)
        )
    end
    return DataFrame(data)
end

function history_candlesticks_by_date(
    ctx::QuoteContext, symbol::String, period::CandlePeriod.T, adjust_type::AdjustType.T; 
    start_date::Union{Date, Nothing}=nothing, end_date::Union{Date, Nothing}=nothing, trade_sessions::TradeSession.T=TradeSession.Intraday
    )

    date_request = DateQuery(
        isnothing(start_date) ? "" : Dates.format(start_date, "yyyymmdd"),
        isnothing(end_date) ? "" : Dates.format(end_date, "yyyymmdd")
    )

    req = SecurityHistoryCandlestickRequest(symbol, period, adjust_type, HistoryCandlestickQueryType.QUERY_BY_DATE, nothing, date_request, trade_sessions)
    cmd = GenericRequestCmd(QuoteCommand.QueryHistoryCandlestick, req, SecurityCandlestickResponse, Channel(1))
    resp = request(ctx, cmd)

    data = map(resp.candlesticks) do c
        (
            symbol = resp.symbol,
            close = c.close,
            open = c.open,
            low = c.low,
            high = c.high,
            volume = c.volume,
            turnover = c.turnover,
            timestamp = unix2datetime(c.timestamp)
        )
    end
    return DataFrame(data)
end

function depth(ctx::QuoteContext, symbol::String)
    req = SecurityRequest(symbol)
    cmd = GenericRequestCmd(QuoteCommand.QueryDepth, req, SecurityDepthResponse, Channel(1))
    resp = request(ctx, cmd)
    return (symbol = resp.symbol, ask = to_namedtuple(resp.ask), bid = to_namedtuple(resp.bid))
end

function participants(ctx::QuoteContext)
    req = Vector{UInt8}()
    cmd = GenericRequestCmd(QuoteCommand.QueryParticipantBrokerIds, req, ParticipantBrokerIdsResponse, Channel(1))
    resp = request(ctx, cmd)
    return to_namedtuple(resp.participant_broker_numbers)
end

function subscriptions(ctx::QuoteContext)
    req = Vector{UInt8}()  # Empty request body for subscription query
    cmd = GenericRequestCmd(QuoteCommand.Subscription, req, QuoteSubscribeResponse, Channel(1))
    resp = request(ctx, cmd)
    
    # Return subscriptions in a structured format
    return [(symbol = s, sub_types = resp.sub_types) for s in resp.symbols]
end

function static_info(ctx::QuoteContext, symbols::Vector{String})
    req = MultiSecurityRequest(symbols)
    cmd = GenericRequestCmd(QuoteCommand.QuerySecurityStaticInfo, req, SecurityStaticInfoResponse, Channel(1))
    resp = request(ctx, cmd)
    return to_namedtuple(resp.secu_static_info)
end

function trades(ctx::QuoteContext, symbol::String, count::Int)
    req = SecurityTradeRequest(symbol, count)
    cmd = GenericRequestCmd(QuoteCommand.QueryTrade, req, SecurityTradeResponse, Channel(1))
    resp = request(ctx, cmd)
    return (symbol = resp.symbol, trades = to_namedtuple(resp.trades))
end

function brokers(ctx::QuoteContext, symbol::String)
    req = SecurityRequest(symbol)
    cmd = GenericRequestCmd(QuoteCommand.QueryBrokers, req, SecurityBrokersResponse, Channel(1))
    resp = request(ctx, cmd)
    return (symbol = resp.symbol, ask_brokers = to_namedtuple(resp.ask_brokers), bid_brokers = to_namedtuple(resp.bid_brokers))
end

function intraday(ctx::QuoteContext, symbol::String)
    req = SecurityIntradayRequest(symbol)
    cmd = GenericRequestCmd(QuoteCommand.QueryIntraday, req, SecurityIntradayResponse, Channel(1))
    resp = request(ctx, cmd)

    return (symbol = resp.symbol, lines = to_namedtuple(resp.lines))
end

function option_chain_expiry_date_list(ctx::QuoteContext, symbol::String)
    req = SecurityRequest(symbol)
    cmd = GenericRequestCmd(QuoteCommand.QueryOptionChainDate, req, OptionChainDateListResponse, Channel(1))
    resp = request(ctx, cmd)
    return resp.expiry_date
end

function option_chain_info_by_date(ctx::QuoteContext, symbol::String, expiry_date::Date)
    req = OptionChainDateStrikeInfoRequest(symbol, expiry_date)
    cmd = GenericRequestCmd(QuoteCommand.QueryOptionChainDateStrikeInfo, req, OptionChainDateStrikeInfoResponse, Channel(1))
    resp = request(ctx, cmd)
    return to_namedtuple(resp.strike_price_info)
end

# --- Additional Market Data Endpoints ---

function option_chain_dates(ctx::QuoteContext, symbol::String)
    """Get option chain expiry dates for a symbol"""
    cmd = HttpGetCmd("/v1/quote/option-chain-dates", Dict("symbol" => symbol), Channel(1))
    return request(ctx, cmd)
end

function option_chain_strikes(ctx::QuoteContext, symbol::String, expiry_date::String)
    """Get option chain strike prices for a symbol and expiry date"""
    cmd = HttpGetCmd("/v1/quote/option-chain-strikes", 
        Dict("symbol" => symbol, "expiry_date" => expiry_date), Channel(1))
    return request(ctx, cmd)
end

function warrant_issuers(ctx::QuoteContext)
    """Get warrant issuer information"""
    return get_or_update(ctx.inner.cache_issuers) do
        result = Client.get(ctx.inner.config, "/v1/quote/warrant-issuers")
        haskey(result, "data") ? result.data : []
    end
end

function warrant_filter(ctx::QuoteContext; symbol::String="", issuer_id::String="", 
                       warrant_type::String="", sort_by::String="", sort_order::String="")
    """Filter warrants based on criteria"""
    params = Dict{String, String}()
    !isempty(symbol) && (params["symbol"] = symbol)
    !isempty(issuer_id) && (params["issuer_id"] = issuer_id)
    !isempty(warrant_type) && (params["warrant_type"] = warrant_type)
    !isempty(sort_by) && (params["sort_by"] = sort_by)
    !isempty(sort_order) && (params["sort_order"] = sort_order)
    
    cmd = HttpGetCmd("/v1/quote/warrant-filter", params, Channel(1))
    return request(ctx, cmd)
end

function trading_sessions(ctx::QuoteContext, market::String="")
    """Get trading sessions information"""
    return get_or_update(ctx.inner.cache_trading_sessions) do
        params = isempty(market) ? Dict{String, String}() : Dict("market" => market)
        result = Client.get(ctx.inner.config, "/v1/quote/trading-sessions"; params=params)
        haskey(result, "data") ? result.data : []
    end
end

function trading_days(ctx::QuoteContext, market::String, start_date::String, end_date::String)
    """Get trading days for a market within date range"""
    params = Dict(
        "market" => market,
        "start_date" => start_date, 
        "end_date" => end_date
    )
    cmd = HttpGetCmd("/v1/quote/trading-days", params, Channel(1))
    return request(ctx, cmd)
end

function capital_flow_intraday(ctx::QuoteContext, symbol::String)
    """Get intraday capital flow for a symbol"""
    cmd = HttpGetCmd("/v1/quote/capital-flow-intraday", Dict("symbol" => symbol), Channel(1))
    return request(ctx, cmd)
end

function capital_flow_distribution(ctx::QuoteContext, symbol::String)
    """Get capital flow distribution for a symbol"""
    cmd = HttpGetCmd("/v1/quote/capital-flow-distribution", Dict("symbol" => symbol), Channel(1))
    return request(ctx, cmd)
end

function calc_indexes(ctx::QuoteContext, symbols::Vector{String}, indexes::Vector{String})
    """Get calculated indexes for symbols"""
    params = Dict(
        "symbol" => join(symbols, ","),
        "indexes" => join(indexes, ",")
    )
    cmd = HttpGetCmd("/v1/quote/calc-indexes", params, Channel(1))
    return request(ctx, cmd)
end




function option_quote(ctx::QuoteContext, symbols::Vector{String})
    req = MultiSecurityRequest(symbols)
    cmd = GenericRequestCmd(QuoteCommand.QueryOptionQuote, req, OptionQuoteResponse, Channel(1))
    resp = request(ctx, cmd)
    
    # Convert to structured format including option-specific data
    return to_namedtuple(resp.secu_quote)
end

function warrant_quote(ctx::QuoteContext, symbols::Vector{String})
    req = MultiSecurityRequest(symbols)
    cmd = GenericRequestCmd(QuoteCommand.QueryWarrantQuote, req, WarrantQuoteResponse, Channel(1))
    resp = request(ctx, cmd)
    
    # Convert to structured format including warrant-specific data
    return to_namedtuple(resp.secu_quote)
end

member_id(ctx::QuoteContext) = ctx.inner.member_id
quote_level(ctx::QuoteContext) = ctx.inner.quote_level

end # module Quote
