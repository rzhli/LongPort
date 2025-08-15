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
