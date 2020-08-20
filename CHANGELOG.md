# 0.5.0 (20 August 2020)

This release updates both `basic` and `tokamak` templates in `carton init` for compatibility with
the latest [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) and
[Tokamak](https://tokamak.dev) versions. Additionally, `carton dev` now cleans build logs from
previous builds when its watcher is triggered. New `--verbose` flag was added, which restores the
previous behavior with all build logs listed on the same screen.

`carton dev` and `carton test` now install 5.3 SwiftWasm snapshots by default, which in general are
more stable than the previously used SwiftWasm development snapshots, and are compatible with Xcode
12 betas. You can now also add direct dependencies on a specific JavaScriptKit version instead of a
revision with these 5.3 snapshots, as they contain a workaround for [the unsafe flags
issue](https://github.com/swiftwasm/JavaScriptKit/issues/6) reproducible with SwiftWasm development
snapshots.

Allowing `carton` to select a default snapshot is now the recommended approach, so in general we
suggest avoiding `.swif-version` files in projects that use `carton`.

The issue where `carton dev` hangs on exit after establishing at least one WebSocket connection with
a browser is now fixed in our Vapor dependency. Kudos to
[@tanner0101](https://github.com/tanner0101) for diagnosing and fixing the issue!

Thanks to [@carson-katri](https://github.com/carson-katri),
[@RayZhao1998](https://github.com/RayZhao1998) for their contributions to this release!

**Closed issues:**

- Compiling swift packages that depend on Darwin or Glibc
  ([#89](https://github.com/swiftwasm/carton/issues/89))
- Detect the currently selected version of Xcode and warn if it's 12 beta
  ([#81](https://github.com/swiftwasm/carton/issues/81))
- Print the error output of `swift package dump-package`
  ([#78](https://github.com/swiftwasm/carton/issues/78))
- JavaScriptKit dependency missing in the `basic` template
  ([#77](https://github.com/swiftwasm/carton/issues/77))
- `carton sdk install` crashes when passed an invalid version
  ([#72](https://github.com/swiftwasm/carton/issues/72))
- No package found when invoking `carton dev` ([#71](https://github.com/swiftwasm/carton/issues/71))
- Xcode 12 beta 3 compatibility ([#65](https://github.com/swiftwasm/carton/issues/65))
- Delay on Ctrl-C with error: Could not stop HTTP server
  ([#7](https://github.com/swiftwasm/carton/issues/7))

**Merged pull requests:**

- Update `README.md` to reflect the current feature set
  ([#90](https://github.com/swiftwasm/carton/pull/90)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix broken `carton init` templates ([#88](https://github.com/swiftwasm/carton/pull/88)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Propagate package manifest parsing errors ([#86](https://github.com/swiftwasm/carton/pull/86)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update default toolchain version ([#87](https://github.com/swiftwasm/carton/pull/87)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Close WebSocket connections after HTTP server exits
  ([#85](https://github.com/swiftwasm/carton/pull/85)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix crash caused by use of `try!` while installing invalid version
  ([#73](https://github.com/swiftwasm/carton/pull/73)) via
  [@RayZhao1998](https://github.com/RayZhao1998)
- Update TSC and add sqlite dependency ([#74](https://github.com/swiftwasm/carton/pull/74)) via
  [@ie-ahm-robox](https://github.com/ie-ahm-robox)
- Avoid using 3rd-party action for the Linux build
  ([#75](https://github.com/swiftwasm/carton/pull/75)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add verbose/concise logging levels ([#69](https://github.com/swiftwasm/carton/pull/69)) via
  [@carson-katri](https://github.com/carson-katri)
- Fix watcher crashing in package subdirectories
  ([#67](https://github.com/swiftwasm/carton/pull/67)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Warn against Xcode 12 betas in `README.md` ([#66](https://github.com/swiftwasm/carton/pull/66))
  via [@MaxDesiatov](https://github.com/MaxDesiatov)

# 0.4.1 (22 July 2020)

This release modifies the `tokamak` template for `carton init` to use the `main` branch of
[Tokamak](https://tokamak.dev). This fixes dependency resolution issues caused by unsafe build flags
in JavaScriptKit. Please see
[swiftwasm/JavaScriptKit#6](https://github.com/swiftwasm/JavaScriptKit/issues/6) for more details.

# 0.4.0 (21 July 2020)

This release adds a few major features, namely `carton init` and `carton test` commands, `carton sdk local` subcommand, and enables support for linking with Foundation automatically.

Thanks to [@carson-katri](https://github.com/carson-katri),
[@RayZhao1998](https://github.com/RayZhao1998), [@JaapWijnen](https://github.com/JaapWijnen) and
[@broadwaylamb](https://github.com/broadwaylamb) for their contributions to this release!

**New features:**

Firstly, `carton dev` no longer requires a `--destination` flag with a manually crafted
`destination.json` file to link with Foundation. If your project has `import Foundation` anywhere in
its source code, a subset of Foundation provided with SwiftWasm is automatically linked. Please
check [the list of Foundation types currently unavailable in
SwiftWasm](https://github.com/swiftwasm/swift-corelibs-foundation/blob/23ec1a2948b823e324d8e88e446c9a2db012acfd/Sources/Foundation/CMakeLists.txt#L3)
for more details on Foundation compatibility (mostly filesystem, socket, multi-threading, and APIs
depending on those are disabled).

The new `carton init` command initializes a new SwiftWasm project for you (similarly to `swift package init`) with multiple templates available at your choice. `carton init --template tokamak`
creates a new [Tokamak](https://tokamak.dev/) project, while `carton init --template basic` (equivalent to
`carton init`) creates an empty SwiftWasm project with no dependencies. Also, `carton init list-templates` provides a complete list of templates (with only `basic` and `tokamak` available
currently).

The new `carton test` command runs your test suite in the [`wasmer`](https://wasmer.io/)
environment. Unfortunately, this currently requires a presence of `LinuxMain.swift` file and
explicit test manifests, `--enable-test-discovery` flag is not supported yet. Projects that can
build their test suite on macOS can use `swift test --generate-linuxmain` command to generate this
file.

**Breaking changes:**

The bundled `carton dev` JavaScript entrypoint has been updated to fix runtime issues in the
Swift-to-JavaScript bridge API. Because of this, projects that depend on
[JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) should specify `c90e82f` revision as a
dependency:

```swift
  dependencies: [
    .package(url: "https://github.com/kateinoigakukun/JavaScriptKit", .revision("c90e82f")),
  ],
```

Unfortunately, specifying a JavaScriptKit version in `Package.swift` as a dependency is not
supported by SwiftPM due to the use of unsafe flags, see
[swiftwasm/JavaScriptKit#6](https://github.com/swiftwasm/JavaScriptKit/issues/6) for more details.

**Closed issues:**

- Avoid running the tests if can't build them ([#56](https://github.com/swiftwasm/carton/issues/56))
- Verify SDK is already installed before installing the same version
  ([#45](https://github.com/swiftwasm/carton/issues/45))
- Automatically create destination JSON to allow linking Foundation
  ([#4](https://github.com/swiftwasm/carton/issues/4))
- Watcher should detect custom paths in Package.swift
  ([#1](https://github.com/swiftwasm/carton/issues/1))

**Merged pull requests:**

- Propagate test build/run failures in the exit code
  ([#61](https://github.com/swiftwasm/carton/pull/61)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update static.zip, automate its release process
  ([#60](https://github.com/swiftwasm/carton/pull/60)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Upgrade JavaScriptKit to 0.5.0 ([#59](https://github.com/swiftwasm/carton/pull/59)) via
  [@carson-katri](https://github.com/carson-katri)
- Add `carton init` command ([#54](https://github.com/swiftwasm/carton/pull/54)) via
  [@carson-katri](https://github.com/carson-katri)
- Fix `carton test` output skipping lines ([#53](https://github.com/swiftwasm/carton/pull/53)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Implement `carton sdk local` subcommand ([#40](https://github.com/swiftwasm/carton/pull/40)) via
  [@RayZhao1998](https://github.com/RayZhao1998)
- Add `list` flag and `testCases` argument to `test`
  ([#52](https://github.com/swiftwasm/carton/pull/52)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Implement simple wasmer runner for `test` command
  ([#51](https://github.com/swiftwasm/carton/pull/51)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Always pass --enable-test-discovery to swift build
  ([#49](https://github.com/swiftwasm/carton/pull/49)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix watcher missing root directories ([#48](https://github.com/swiftwasm/carton/pull/48)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update to Vapor 4.15.2, fix formatting ([#47](https://github.com/swiftwasm/carton/pull/47)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add sources to watcher per target ([#46](https://github.com/swiftwasm/carton/pull/46)) via
  [@JaapWijnen](https://github.com/JaapWijnen)
- Avoid displaying destination files as SDK versions
  ([#44](https://github.com/swiftwasm/carton/pull/44)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Automatically link Foundation w/ destination.json
  ([#41](https://github.com/swiftwasm/carton/pull/41)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Use Combine instead of OpenCombine where possible
  ([#39](https://github.com/swiftwasm/carton/pull/39)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add separate CartonHelpers/SwiftToolchain modules
  ([#35](https://github.com/swiftwasm/carton/pull/35)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Use `from` instead of `upToNextMinor` for OpenCombine
  ([#34](https://github.com/swiftwasm/carton/pull/34)) via
  [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump OpenCombine version to 0.10.0 ([#33](https://github.com/swiftwasm/carton/pull/33)) via
  [@broadwaylamb](https://github.com/broadwaylamb)

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
