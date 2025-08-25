# Release Notes

## v0.2.9 (2025-08-25)

### Bug Fixes

- **WebSocket Connection**: Fixed a critical bug where the `config` object was not being passed to the `WSClient` constructor in the `Quote` and `Trade` contexts. This caused connection failures by preventing necessary parameters, such as `enable_overnight`, from being correctly configured.

## v0.2.8 (2025-08-18)

### New Features

- **Intraday Data**: The `intraday` function now supports a `trade_session` parameter, allowing users to fetch data for specific trading sessions (e.g., pre-market, post-market).

### Refactoring

- **`disconnect!` Function**: Moved the `disconnect!` function from the `Quote` and `Trade` modules to the main `LongPort` module, using multiple dispatch to handle both `QuoteContext` and `TradeContext` types. This simplifies the API and improves code organization.

## v0.2.7 (2025-08-15)

### Major Improvements

- **Dependencies & Compatibility**: Updated `Project.toml` with strict `[compat]` bounds for all dependencies and raised the minimum Julia version to `1.10` for better performance and stability.
- **WebSocket Stability**: Implemented a robust WebSocket handling mechanism, including:
    - Heartbeat (ping/pong) to keep connections alive.
    - Automatic re-subscription of topics upon reconnection.
- **HTTP Performance**: Introduced `HTTP.ConnectionPool` to reuse connections, significantly reducing latency for frequent API calls. Added timeout and retry strategies for GET requests.
- **Protocol Correctness**: Ensured all `@enum` types have explicit integer values matching the server-side protocol, preventing potential misinterpretations.
- **Error Handling**: Replaced the basic exception type with a more informative `Long
