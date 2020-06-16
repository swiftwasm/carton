# 0.1.0 (16 June 2020)

Since SwiftPM doesn't always build an executable target even if one is present without
an explicit `--product` flag, the `dev` command now requires the presence of an executable
target in your `Package.swift`. Use the new `--product` flag instead of `--target` to
disambiguate between multiple executable targets.

# 0.0.5 (16 June 2020)

Pass `--target` flag to `swift build` when running the `dev` command.

# 0.0.4 (16 June 2020)

Fix index page body served by HTTP when running the `dev` command.

# 0.0.3 (9 June 2020)

Fix expected polyfill hashes and a fatal error triggered when hashes didn't match.

# 0.0.2 (9 June 2020)

Fix watching and reloading, allow multiple WebSocket connections in the watcher code. The
latter allows multiple browser windows to stay open and get reloaded simultaneously.

# 0.0.1 (6 June 2020)

First preview release, only a basic `dev` command is implemented.
