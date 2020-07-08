# 0.3.1 (7 July 2020)

This is a bugfix release that fixes SwiftWasm backtrace reporting in certain cases and also enables
sorting for the output of the `carton sdk versions` subcommand.

**Merged pull requests:**

- Fix backtrace logging for async startWasiTask ([#30](https://github.com/swiftwasm/carton/pull/30)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Sort the output of `carton sdk versions` ([#29](https://github.com/swiftwasm/carton/pull/29)) via [@MaxDesiatov](https://github.com/MaxDesiatov)

# 0.3.0 (7 July 2020)

This is a release that adds a new `carton sdk versions` subcommand, new `--release` flag and a new
`--destination` option to the `carton dev` command. Additionally, archive size is logged when a new
SDK is downloaded, and backtrace logging is improved in browser consoles for crashing SwiftWasm
apps. Many thanks to [@RayZhao1998](https://github.com/RayZhao1998) and
[@ratranqu](https://github.com/ratranqu) for their contributions! 👏

**Closed issues:**

- Support linking with Foundation/CoreFoundation ([#11](https://github.com/swiftwasm/carton/issues/11))

**Merged pull requests:**

- Log archive size when downloading new SDK ([#28](https://github.com/swiftwasm/carton/pull/28)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update WASI polyfill, print a backtrace on crash ([#27](https://github.com/swiftwasm/carton/pull/27)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Support `carton sdk versions` ([#21](https://github.com/swiftwasm/carton/pull/21)) via [@RayZhao1998](https://github.com/RayZhao1998)
- Add a --release flag to the carton dev command ([#19](https://github.com/swiftwasm/carton/pull/19)) via [@ratranqu](https://github.com/ratranqu)
- Add --destination option to the `carton dev` command ([#18](https://github.com/swiftwasm/carton/pull/18)) via [@ratranqu](https://github.com/ratranqu)

# 0.2.0 (26 June 2020)

This release introduces a new `carton sdk install` command that allows
you to quickly install the [SwftWasm](https://swiftwasm.org/) toolchain and SDK
without requiring any additional dependencies such as `swiftenv`. Also,
`carton dev` now automatically installs SwiftWasm through the same code paths
as `carton sdk install`, when no suitable SDK is detected.

# 0.1.5 (22 June 2020)

This is a refinement release that adds a `--version` flag. Additionally, the
`dev` command is no longer the default, now a simple `carton` invocation without
any arguments prints a help message describing available commands.

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
an explicit `--product` option, the `dev` command now requires the presence of an executable
target in your `Package.swift`. Use the new `--product` option instead of `--target` to
disambiguate between multiple executable targets.

# 0.0.5 (16 June 2020)

Pass `--target` option to `swift build` when running the `dev` command.

# 0.0.4 (16 June 2020)

Fix index page body served by HTTP when running the `dev` command.

# 0.0.3 (9 June 2020)

Fix expected polyfill hashes and a fatal error triggered when hashes didn't match.

# 0.0.2 (9 June 2020)

Fix watching and reloading, allow multiple WebSocket connections in the watcher code. The
latter allows multiple browser windows to stay open and get reloaded simultaneously.

# 0.0.1 (6 June 2020)

First preview release, only a basic `dev` command is implemented.
