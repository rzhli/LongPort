using Revise
using Longport

# 从配置文件创建客户端
client = LongportClient("config.toml")

# 连接并认证
connect!(client)

# 订阅行情
subscribe_quotes(client, ["AAPL.US", "00700.HK"])