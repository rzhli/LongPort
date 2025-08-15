# Release Notes

## v0.2.7 (2025-08-15)

### Major Improvements

- **Dependencies & Compatibility**: Updated `Project.toml` with strict `[compat]` bounds for all dependencies and raised the minimum Julia version to `1.10` for better performance and stability.
- **WebSocket Stability**: Implemented a robust WebSocket handling mechanism, including:
    - Heartbeat (ping/pong) to keep connections alive.
    - Automatic re-subscription of topics upon reconnection.
- **HTTP Performance**: Introduced `HTTP.ConnectionPool` to reuse connections, significantly reducing latency for frequent API calls. Added timeout and retry strategies for GET requests.
- **Protocol Correctness**: Ensured all `@enum` types have explicit integer values matching the server-side protocol, preventing potential misinterpretations.
- **Error Handling**: Replaced the basic exception type with a more informative `LongPortError`, including a helper macro (`@lperror`) for easier diagnostics.
- **JSON Decoding**: Integrated `StructTypes.jl` for direct, high-performance JSON-to-struct decoding, removing manual dictionary conversions.
- **Testing**: Enhanced the test suite with mocking capabilities, allowing for more reliable and isolated unit tests.
- **API Consistency**: Standardized the API by removing the export of `from_toml`, requiring users to call it via `Config.from_toml()` for clarity.

### Documentation

- Added a "Release Notes" section to `README.md` and `README.zh-CN.md`.

## v0.2.4 (2025-08-10)

### New Features

- Updated the `README.md` to support both English and Chinese.
- Added a Chinese version of the `README.md` (`README.zh-CN.md`).
