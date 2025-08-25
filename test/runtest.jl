using Test
using LongPort
using LongPort.Config

@testset "Config defaults" begin
    mktemp() do f, io
        write(io, """
        base_url = "https://openapi.longportapp.com"
        app_key = "k"
        app_secret = "s"
        access_token = "t"
        token_expire_time = "2099-01-01T00:00:00Z"
        """)
        close(io)
        cfg = from_toml(f)
        @test cfg.language == LongPort.Constant.Language.EN
        @test cfg.enable_overnight == false
    end
end

@testset "Disconnect" begin
    cfg = config(
        base_url = "https://openapi.longportapp.com",
        app_key = "test",
        app_secret = "test",
        access_token = "test",
    )
    
    quote_ctx = QuoteContext(cfg)
    trade_ctx = TradeContext(cfg)
    
    disconnect!(quote_ctx)
    disconnect!(trade_ctx)

    @test istaskdone(quote_ctx.inner.core_task)
    @test istaskdone(trade_ctx.inner.core_task)
end
