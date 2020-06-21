# 0.1.4 (21 June 2020)

This is a bugfix release that fixes the `dev.js` bundle broken in 0.1.3.

# 0.1.3 (21 June 2020)

This is a bugfix release that includes the latest version of
[JavaScriptKit](https://github.com/kateinoigakukun/JavaScriptKit/) runtime
in the `dev.js` bundle. It fixes a bug with reference counting of `JSObjectRef`
instances, which could lead to crashes.

# 0.1.2 (19 June 2020)

This is a bugfix release that fixes stdout and stderr WASI output in async handlers.
Previously stdout output was redirected with `console.log` only on the first pass
of execution of top-level code, while none of the output from async handlers (such
as DOM listeners) was redirected. Now in this release, stdout and stderr output
is consistently redirected with `console.log` and `console.error` respectively,
in all cases.

# 0.1.1 (19 June 2020)

This is a bugfix release that fixes dependency downloads on Linux. The issue was
caused by [Foundation not supporting HTTP
redirects](https://github.com/apple/swift-corelibs-foundation/pull/2744) in Swift 5.2 on Linux,
and is now resolved by using [AsyncHTTPClient](https://github.com/swift-server/async-http-client)
instead of Foundation's `URLSession` for dependency downloads.

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
