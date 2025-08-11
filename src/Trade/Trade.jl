module Trade

    using JSON3, Dates, Logging, DataFrames
    import ProtoBuf as PB

    using ..Constant
    using ..Config
    using ..Client
    using ..Errors
    using ..TradePush
    using ..TradeProtocol
    using ..Utils

    # --- Public API ---
    export TradeContext, disconnect!, subscribe, unsubscribe, history_executions, today_executions,
           history_orders, today_orders, replace_order, submit_order, cancel_order, account_balance,
           cash_flow, fund_positions, stock_positions, margin_ratio, order_detail, estimate_max_purchase_quantity,
           set_on_order_changed
    
    # --- Core Actor Implementation ---
    struct Arc{T}
        value::T
    end

    Base.getproperty(arc::Arc, sym::Symbol) = getproperty(getfield(arc, :value), sym)

    abstract type AbstractCommand end

    struct HttpGetCmd <: AbstractCommand
        path::String
        params::Dict{String,Any}
        resp_ch::Channel{Any}
    end

    struct HttpPostCmd <: AbstractCommand
        path::String
        body::Any
        resp_ch::Channel{Any}
    end

    struct HttpPutCmd <: AbstractCommand
        path::String
        body::Any
        resp_ch::Channel{Any}
    end

    struct HttpDeleteCmd <: AbstractCommand
        path::String
        params::Dict{String,Any}
        resp_ch::Channel{Any}
    end

    struct SubscribeCmd <: AbstractCommand
        topics::Vector{String}
        resp_ch::Channel{Any}
    end

    struct UnsubscribeCmd <: AbstractCommand
        topics::Vector{String}
        resp_ch::Channel{Any}
    end

    struct DisconnectCmd <: AbstractCommand end

    mutable struct InnerTradeContext
        config::Config.config
        ws_client::Union{Client.WSClient,Nothing}
        command_ch::Channel{Any}
        core_task::Union{Task,Nothing}
        callbacks::Callbacks
    end

    struct TradeContext
        inner::Arc{InnerTradeContext}
    end

    function core_run(inner::InnerTradeContext)
        should_run = true
        reconnect_attempts = 0

        while should_run
            try
                ws = Client.WSClient(inner.config.trade_ws_url)
                inner.ws_client = ws
                ws.on_push =
                    (cmd, body) -> begin
                        command = Command.T(cmd)
                        if command == Command.CMD_NOTIFY
                            n = PB.decode(IOBuffer(body), Notification)
                            handle_push_event!(inner.callbacks, n)
                        else
                            @warn "Unknown trade push command" cmd = cmd
                        end
                    end
                ws.auth_data = Client.create_auth_request(inner.config)
                Client.connect!(ws)
                reconnect_attempts = 0

                while isopen(inner.command_ch)
                    cmd = take!(inner.command_ch)
                    handle_command(inner, cmd)
                    if cmd isa DisconnectCmd
                        should_run = false
                        break
                    end
                end
            catch e
                if e isa InvalidStateException && e.state == :closed
                    should_run = false
                elseif e isa LongportError && e.code == "ws-disconnected"
                    reconnect_attempts += 1
                    delay = min(60.0, 2.0^reconnect_attempts)
                    @warn "Connection failed, reconnecting in $(delay)s..." exception =
                        (e, catch_backtrace())
                    sleep(delay)
                else
                    @error "Trade core actor failed" exception = (e, catch_backtrace())
                    should_run = false
                end
            finally
                if !isnothing(inner.ws_client)
                    Client.disconnect!(inner.ws_client)
                    inner.ws_client = nothing
                end
            end
        end
    end

    function handle_command(inner::InnerTradeContext, cmd::AbstractCommand)
        resp = try
            if cmd isa DisconnectCmd
                nothing
            elseif cmd isa SubscribeCmd
                req = TradeProtocol.Sub(cmd.topics)
                io_buf = IOBuffer()
                encoder = PB.ProtoEncoder(io_buf)
                PB.encode(encoder, req)
                resp_body = Client.ws_request(inner.ws_client, UInt8(TradeProtocol.Command.CMD_SUB), take!(io_buf))
                decoder = PB.ProtoDecoder(IOBuffer(resp_body))
                PB.decode(decoder, SubResponse)
            elseif cmd isa UnsubscribeCmd
                req = TradeProtocol.Unsub(cmd.topics)
                io_buf = IOBuffer()
                encoder = PB.ProtoEncoder(io_buf)
                PB.encode(encoder, req)
                resp_body = Client.ws_request(inner.ws_client, UInt8(TradeProtocol.Command.CMD_UNSUB), take!(io_buf))
                decoder = PB.ProtoDecoder(IOBuffer(resp_body))
                PB.decode(decoder, UnsubResponse)
            elseif cmd isa HttpGetCmd
                ApiResponse(Client.get(inner.config, cmd.path; params = cmd.params))
            elseif cmd isa HttpPostCmd
                ApiResponse(Client.post(inner.config, cmd.path; body = cmd.body))
            elseif cmd isa HttpPutCmd
                ApiResponse(Client.put(inner.config, cmd.path; body = cmd.body))
            elseif cmd isa HttpDeleteCmd
                ApiResponse(Client.delete(inner.config, cmd.path; params = cmd.params))
            end
        catch e
            @error "Failed to handle command" command = typeof(cmd) exception = (e, catch_backtrace())
            e
        end

        if !(cmd isa DisconnectCmd) && isopen(cmd.resp_ch)
            put!(cmd.resp_ch, resp)
        end
    end

    function TradeContext(config::Config.config)
        command_ch = Channel{Any}(32)

        inner = InnerTradeContext(config, nothing, command_ch, nothing, Callbacks())
        ctx = TradeContext(Arc(inner))

        inner.core_task = @async core_run(inner)

        return ctx
    end

    function disconnect!(ctx::TradeContext)
        inner = ctx.inner
        if !isnothing(inner.core_task) && !istaskdone(inner.core_task)
            put!(inner.command_ch, DisconnectCmd())
            close(inner.command_ch)
            wait(inner.core_task)
        end
    end

    function request(ctx::TradeContext, cmd::AbstractCommand)
        put!(ctx.inner.command_ch, cmd)
        resp = take!(cmd.resp_ch)
        if resp isa Exception
            throw(resp)
        end
        return resp
    end

    function to_dict(opts)
        d = Dict{String,Any}()
        for name in fieldnames(typeof(opts))
            val = getfield(opts, name)
            if !isnothing(val)
                key = string(name)
                if val isa Date || val isa DateTime
                    d[key] = string(round(Int, datetime2unix(DateTime(val))))
                elseif val isa Vector && !isempty(val)
                    d[key] = [v isa Enum ? Int(v) : string(v) for v in val]
                elseif val isa Enum
                    d[key] = Int(val)
                else
                    d[key] = val
                end
            end
        end
        d
    end

    function set_on_order_changed(ctx::TradeContext, cb::Function); TradePush.set_on_order_changed!(ctx.inner.callbacks, cb); end

    function subscribe(ctx::TradeContext, topics::Vector{TopicType.T})
        ch = Channel(1)
        cmd = SubscribeCmd([string(t) for t in topics], ch)
        request(ctx, cmd)
    end

    function unsubscribe(ctx::TradeContext, topics::Vector{TopicType.T})
        ch = Channel(1)
        cmd = UnsubscribeCmd([string(t) for t in topics], ch)
        request(ctx, cmd)
    end

    function history_executions(
        ctx::TradeContext;
        symbol::Union{String,Nothing}=nothing,
        start_at::Union{Date,Nothing}=nothing,
        end_at::Union{Date,Nothing}=nothing,
    )
        options = GetHistoryExecutionsOptions(symbol=symbol, start_at=start_at, end_at=end_at)
        cmd = HttpGetCmd("/v1/trade/execution/history", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return ExecutionResponse(Dict(resp.data))
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function today_executions(ctx::TradeContext; symbol::Union{String,Nothing}=nothing)
        options = GetTodayExecutionsOptions(symbol=symbol)
        cmd = HttpGetCmd("/v1/trade/execution/today", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return TodayExecutionResponse(Dict(resp.data))
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function history_orders(
        ctx::TradeContext;
        symbol::Union{String,Nothing}=nothing,
        status::Union{Vector{OrderStatus.T},Nothing}=nothing,
        side::Union{OrderSide.T,Nothing}=nothing,
        start_at::Union{Date,Nothing}=nothing,
        end_at::Union{Date,Nothing}=nothing,
    )
        options = GetHistoryOrdersOptions(symbol=symbol, status=status, side=side, start_at=start_at, end_at=end_at)
        cmd = HttpGetCmd("/v1/trade/order/history", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            orders = [Order(o) for o in resp.data["orders"]]
            df = to_dataframe(orders)
            sub_df = df[!, [:order_id, :symbol, :side, :status, :order_type, :quantity, :price, :submitted_at]]
            rename!(sub_df,
                :order_id => "Order ID",
                :symbol => "Symbol",
                :side => "Side",
                :status => "Status",
                :order_type => "Type",
                :quantity => "Quantity",
                :price => "Price",
                :submitted_at => "Submitted At",
            )
            return sub_df
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function today_orders(
        ctx::TradeContext;
        symbol::Union{String,Nothing}=nothing,
        status::Union{Vector{OrderStatus.T},Nothing}=nothing,
        side::Union{OrderSide.T,Nothing}=nothing,
    )
        options = GetTodayOrdersOptions(symbol=symbol, status=status, side=side)
        cmd = HttpGetCmd("/v1/trade/order/today", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            orders = [Order(o) for o in resp.data["orders"]]
            df = to_dataframe(orders)
            sub_df = df[!, [:order_id, :symbol, :side, :status, :order_type, :quantity, :price, :submitted_at]]
            rename!(sub_df,
                :order_id => "Order ID",
                :symbol => "Symbol",
                :side => "Side",
                :status => "Status",
                :order_type => "Order Type",
                :quantity => "Quantity",
                :price => "Price",
                :submitted_at => "Submitted At",
            )
            return sub_df
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function replace_order(ctx::TradeContext, options::ReplaceOrderOptions)
        cmd = HttpPutCmd("/v1/trade/order", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code != 0
            throw(LongportException(resp.code, "", resp.message))
        end
        return nothing
    end

    function submit_order(ctx::TradeContext, options::SubmitOrderOptions)
        cmd = HttpPostCmd("/v1/trade/order", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return SubmitOrderResponse(Dict(resp.data))
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function cancel_order(ctx::TradeContext, order_id::String)
        params = Dict{String,Any}("order_id" => string(order_id))
        cmd = HttpDeleteCmd("/v1/trade/order", params, Channel(1))
        resp = request(ctx, cmd)
        if resp.code != 0
            throw(LongportException(resp.code, "", resp.message))
        end
        return nothing
    end

    function account_balance(ctx::TradeContext; currency::Union{Currency.T, Nothing} = nothing)
        params = isnothing(currency) ? Dict{String,Any}() : Dict{String,Any}("currency" => String(Symbol(currency)))
        cmd = HttpGetCmd("/v1/asset/account", params, Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return [AccountBalance(Dict(b)) for b in resp.data["list"]]
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function cash_flow(ctx::TradeContext; start_at::Date, end_at::Date, business_type::Union{Vector{BalanceType.T},Nothing} = nothing,
        symbol::Union{String,Nothing} = nothing, page::Union{Int,Nothing} = nothing, size::Union{Int,Nothing} = nothing)
        
        options = GetCashFlowOptions(
            start_time = Int(datetime2unix(DateTime(start_at))),
            end_time = Int(datetime2unix(DateTime(end_at))),
            business_type = business_type,
            symbol = symbol,
            page = page,
            size = size,
        )
        cmd = HttpGetCmd("/v1/asset/cashflow", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return [CashFlow(Dict(f)) for f in resp.data.list]
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function fund_positions(ctx::TradeContext; symbol::Union{Vector{String},Nothing}=nothing)
        options = GetFundPositionsOptions(symbol=symbol)
        cmd = HttpGetCmd("/v1/asset/fund", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return FundPositionsResponse(Dict(resp.data))
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function stock_positions(ctx::TradeContext; symbol::Union{String,Nothing}=nothing)
        options = GetStockPositionsOptions(symbol=symbol)
        cmd = HttpGetCmd("/v1/asset/stock", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return StockPositionsResponse(Dict(resp.data))
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function margin_ratio(ctx::TradeContext, symbol::String)
        params = Dict{String,Any}("symbol" => string(symbol))
        cmd = HttpGetCmd("/v1/risk/margin-ratio", params, Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return MarginRatio(Dict(resp.data))
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function order_detail(ctx::TradeContext, order_id::String)
        params = Dict{String,Any}("order_id" => string(order_id))
        cmd = HttpGetCmd("/v1/trade/order", params, Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return OrderDetail(Dict(resp.data))
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end

    function estimate_max_purchase_quantity(ctx::TradeContext, options::EstimateMaxPurchaseQuantityOptions)
        cmd = HttpGetCmd("/v1/trade/estimate/buy_limit", to_dict(options), Channel(1))
        resp = request(ctx, cmd)
        if resp.code == 0
            return EstimateMaxPurchaseQuantityResponse(Dict(resp.data))
        else
            throw(LongportException(resp.code, "", resp.message))
        end
    end
end # module Trade
