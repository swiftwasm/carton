# 0.8.2 (9 November 2020)

This patch release updates the default version of Tokamak in the `carton init` template to fix autocomplete in Xcode.

**Merged pull requests:**

- Add minimum deployment target in template ([#165](https://github.com/swiftwasm/carton/pull/165)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Remove wasm-strip from log comment ([#164](https://github.com/swiftwasm/carton/pull/164)) via [@kateinoigakukun](https://github.com/kateinoigakukun)

# 0.8.1 (9 November 2020)

This patch release updates the default version of Tokamak in templates used by `carton init`.

**Merged pull requests:**

- Update Tokamak version used in init template ([#160](https://github.com/swiftwasm/carton/pull/160)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Update dependencies ([#159](https://github.com/swiftwasm/carton/pull/159)) via [@ie-ahm-robox](https://github.com/ie-ahm-robox)
- Add image source label ([#161](https://github.com/swiftwasm/carton/pull/161)) via [@kateinoigakukun](https://github.com/kateinoigakukun)

# 0.8.0 (8 November 2020)

This is a bugfix and feature release that coincides with the stable 5.3.0 release of SwiftWasm,
uses it as the default toolchain, and enables compatibility with it. This is the recommended version
of SwiftWasm, and older development snapshots are no longer supported in `carton`. We also
discourage you from adding `.swift-version` files to your project or using new development
snapshots, unless you'd like to try a preview of a new Swift feature. If there's anything that
prevents you from using the 5.3.0 release of SwiftWasm instead of a specific 5.3 development
snapshot, please report it as a bug.

Many thanks to [@carson-katri](https://github.com/carson-katri),
[@kateinoigakukun](https://github.com/kateinoigakukun) for their contributions to this release!

**Notable changes:**

- `carton test` now parses output of XCTest and reformats as a clear test summary with colors
  highlighted in terminals that support it.
- Our [`WasmTransformer`](https://github.com/swiftwasm/WasmTransformer) dependency now can strip
  debug information from release bundles, which means `carton bundle` no longer requires
  [WABT](github.com/webassembly/wabt) with its `wasm-strip` utility to run.
- `carton test` previously built all targets in a SwiftPM package even when they weren't direct or
  indirect dependencies of test targets, which mirrored the behavior of `swift test`. This could
  cause issues with packages that have some targets that are incompatible with the WASI platform,
  but are excluded from dependency trees otherwise. This is no longer the case, `carton test` now
  only builds targets that are actually needed to run the tests in a given package.
- SwiftPM included in the SwiftWasm 5.3.0 toolchain produces executable binaries with the `.wasm`
  extension. This version of `carton` now assumes this extension is present in filenames of
  WebAssembly binaries, which makes old development snapshots incompatible.
- `carton` now looks for SwiftWasm SDKs installed in the `/Library/Developer/Toolchains` directory
  in addition to the `~/.carton/sdk` and `~/Library/Developer/Toolchains` directories on macOS.

**Closed issues:**

- Search /Library/Developer/Toolchains also ([#146](https://github.com/swiftwasm/carton/issues/146))

**Merged pull requests:**

- Support system installed toolchain ([#157](https://github.com/swiftwasm/carton/pull/157)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Remove wabt dependency ([#156](https://github.com/swiftwasm/carton/pull/156)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Use ghcr.io/swiftwasm/swift as base image ([#154](https://github.com/swiftwasm/carton/pull/154)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Fix handling of test products with .wasm extension ([#153](https://github.com/swiftwasm/carton/pull/153)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Format testing time to two decimal places ([#152](https://github.com/swiftwasm/carton/pull/152)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Build only test product and its deps for testing ([#150](https://github.com/swiftwasm/carton/pull/150)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#149](https://github.com/swiftwasm/carton/pull/149)) via [@ie-ahm-robox](https://github.com/ie-ahm-robox)
- Update toolchain and remove extra compiler flags ([#147](https://github.com/swiftwasm/carton/pull/147)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Fix handling of binaries with `.wasm` extension ([#148](https://github.com/swiftwasm/carton/pull/148)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Pretty print `carton test` output ([#144](https://github.com/swiftwasm/carton/pull/144)) via [@carson-katri](https://github.com/carson-katri)
- Stop using destination.json ([#141](https://github.com/swiftwasm/carton/pull/141)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Use Xcode 12.2 on macOS Big Sur ([#145](https://github.com/swiftwasm/carton/pull/145)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix error message output ([#142](https://github.com/swiftwasm/carton/pull/142)) via [@carson-katri](https://github.com/carson-katri)
- Update dependencies ([#143](https://github.com/swiftwasm/carton/pull/143)) via [@ie-ahm-robox](https://github.com/ie-ahm-robox)
- Update JavaScriptKit version in TestApp ([#140](https://github.com/swiftwasm/carton/pull/140)) via [@kateinoigakukun](https://github.com/kateinoigakukun)

# 0.7.1 (22 October 2020)

This is a bugfix release that prevents `carton` commands from re-downloading `.pkg` toolchains
on macOS on every CLI invocation.

# 0.7.0 (22 October 2020)

This release contains bugfixes and improvements.

Now SwiftWasm binaries built with `carton` are
fully compatible with Safari, even when they use functions that return 64-bit integers. This was
caused by [the lack of support for conversions between `i64` and `BigInt` types in
Safari](https://bugs.webkit.org/show_bug.cgi?id=213528).

Additionally, when you run `carton dev` a new tab with your app is opened in your default browser
automatically. You can now also specify a port to use for the development server with the `--port`
option (`-p` for short).

All `carton` commands that build Swift code now pretty-print error messages in case of failures.
If an error message points to a specific location in your code, surrounding code has its syntax
highlighted in terminals.

`carton test` now automatically passes `--enable-test-discovery` flag when building your tests, so
you no longer need to manually maintain `LinuxMain.swift` and `XCTestManifests.swift` files in your
test suites.

`carton` now uses the `wasm-5.3-SNAPSHOT-2020-10-21-a` toolchain and SDK by default. This and most
of our recent snapshots are built for both Ubuntu 18.04 and 20.04, the latter supported in `carton`
for the first time. `carton` automatically detects the version of your OS and downloads an
appropriate snapshot. Recent snapshots for macOS are also tested on macOS Big Sur on Intel CPUs
(Apple Silicon is not supported yet), and are signed and distributed as `.pkg` files, which `carton`
fully supports now.

Lastly, we've prepared [a prebuilt Docker
image](https://github.com/orgs/swiftwasm/packages/container/package/carton) for you that you can get
by running

```
docker pull ghcr.io/swiftwasm/carton:latest
```

This image has the toolchain and all required dependencies preinstalled.

Many thanks to [@carson-katri](https://github.com/carson-katri),
[@kateinoigakukun](https://github.com/kateinoigakukun), and [@yonihemi](https://github.com/yonihemi)
for their contributions to this release!

**Closed issues:**

- Method with i64 return type fails on Safari 13+14 ([#127](https://github.com/swiftwasm/carton/issues/127))
- Provide a Dockerfile for easier distribution and testing on Linux ([#119](https://github.com/swiftwasm/carton/issues/119))
- Support downloading Ubuntu 20.04 SDK ([#114](https://github.com/swiftwasm/carton/issues/114))
- `carton dev` should open a browser window when server starts ([#92](https://github.com/swiftwasm/carton/issues/92))

**Merged pull requests:**

- Bump JavaScriptKit to 0.8, stop checking revision ([#139](https://github.com/swiftwasm/carton/pull/139)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Avoid repeated `loadingMessage` in `ProcessRunner` ([#138](https://github.com/swiftwasm/carton/pull/138)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add support for signed `.pkg` archives on macOS ([#137](https://github.com/swiftwasm/carton/pull/137)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add Dockerfile, mention the Docker image in `README.md` ([#136](https://github.com/swiftwasm/carton/pull/136)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix support for Ubuntu 20.04, use GHA for SwiftLint ([#134](https://github.com/swiftwasm/carton/pull/134)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Build on macOS Big Sur with GitHub Actions ([#132](https://github.com/swiftwasm/carton/pull/132)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Remove sudo usage from `install_ubuntu_deps.sh` ([#135](https://github.com/swiftwasm/carton/pull/135)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add separate Builder class, use WasmTransformer ([#131](https://github.com/swiftwasm/carton/pull/131)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump toolchain, use `--enable-test-discovery` ([#130](https://github.com/swiftwasm/carton/pull/130)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#133](https://github.com/swiftwasm/carton/pull/133)) via [@ie-ahm-robox](https://github.com/ie-ahm-robox)
- Bump default toolchain, make i64 bug reproducible ([#128](https://github.com/swiftwasm/carton/pull/128)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Pretty print diagnostics ([#122](https://github.com/swiftwasm/carton/pull/122)) via [@carson-katri](https://github.com/carson-katri)
- Update dependencies ([#125](https://github.com/swiftwasm/carton/pull/125)) via [@ie-ahm-robox](https://github.com/ie-ahm-robox)
- Add @carson-katri and @kateinoigakukun to `FUNDING.yml` ([#124](https://github.com/swiftwasm/carton/pull/124)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#118](https://github.com/swiftwasm/carton/pull/118)) via [@ie-ahm-robox](https://github.com/ie-ahm-robox)
- Automatically open a browser window when Dev Server starts ([#117](https://github.com/swiftwasm/carton/pull/117)) via [@yonihemi](https://github.com/yonihemi)
- Allow changing dev server's port ([#116](https://github.com/swiftwasm/carton/pull/116)) via [@yonihemi](https://github.com/yonihemi)

# 0.6.1 (29 September 2020)

This release fixes basic `carton init` template that was pulling an incompatible version of
JavaScriptKit in `carton` 0.6.0.

# 0.6.0 (28 September 2020)

This release introduces a new `carton bundle` command that produces an optimized build of your app
and writes it to the `Bundle` subdirectory of your package. Additionally, [SwiftPM
resources](https://github.com/apple/swift-evolution/blob/main/proposals/0271-package-manager-resources.md)
are supported by both `carton dev` (served as static files) and `carton bundle` (copied with the
rest of the assets), if any package resources are declared in your `Package.swift`.

New `carton package` command is introduced, which proxies its subcommands to `swift package`
invocations on the currently-installed toolchain. This may be useful in situations where you'd like
to generate an Xcode project file for your app with something like `carton package generate-xcodeproj`. It would be equivalent to `swift package generate-xcodeproj`, but invoked with
the SwiftWasm toolchain instead of the toolchain supplied by Xcode. Many thanks to
[@kateinoigakukun](https://github.com/kateinoigakukun) for the implementation!

Compatibility with Safari 14 is fixed for `carton dev` and is maintained for the new `carton bundle`
command as well.

This version of `carton` ships with new JavaScript runtime compatible with [JavaScriptKit
0.7](https://github.com/swiftwasm/JavaScriptKit/releases/tag/0.7.0). You should update JavaScriptKit
dependency to 0.7 if you had an older version specified in `Package.swift` of your project.

A regression in `carton test` was fixed in the latest 5.3 toolchain snapshot, which became the
default snapshot version in this version of `carton`. In general we advise against having a
`.swift-version` file in your project, but if you need one, please specify
`wasm-5.3-SNAPSHOT-2020-09-25-a` snapshot or a later one from the 5.3 branch in this file for
`carton test` to work.

**Closed issues:**

- `carton` crashes when it fails to instantiate `TerminalController` ([#112](https://github.com/swiftwasm/carton/issues/112))
- Allow carton to use a provided HTML template file ([#100](https://github.com/swiftwasm/carton/issues/100))
- Add static file support ([#38](https://github.com/swiftwasm/carton/issues/38))
- Demo cannot be run on Safari 14 ([#25](https://github.com/swiftwasm/carton/issues/25))
- Implement `carton bundle` command ([#16](https://github.com/swiftwasm/carton/issues/16))

**Merged pull requests:**

- Use raw stdout if `TerminalController` is unavailable ([#113](https://github.com/swiftwasm/carton/pull/113)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump JavaScriptKit to 0.7.2 ([#115](https://github.com/swiftwasm/carton/pull/115)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump dependencies and default toolchain snapshot ([#111](https://github.com/swiftwasm/carton/pull/111)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Implement resources copying in `carton bundle` ([#109](https://github.com/swiftwasm/carton/pull/109)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update node.js dependencies, including wasmer.js ([#108](https://github.com/swiftwasm/carton/pull/108)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump JavaScriptKit dependency to 0.6.0 ([#107](https://github.com/swiftwasm/carton/pull/107)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Implement support for static resources in `carton dev` ([#104](https://github.com/swiftwasm/carton/pull/104)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump default toolchain version, fix release builds ([#106](https://github.com/swiftwasm/carton/pull/106)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump bl from 4.0.2 to 4.0.3 ([#102](https://github.com/swiftwasm/carton/pull/102)) via [@dependabot[bot]](https://github.com/dependabot[bot])
- Implement `--custom-index-page` option ([#101](https://github.com/swiftwasm/carton/pull/101)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Implement `carton bundle` command ([#97](https://github.com/swiftwasm/carton/pull/97)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update `tokamak` template for the new TokamakUI org ([#98](https://github.com/swiftwasm/carton/pull/98)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add `carton package` cmd ([#96](https://github.com/swiftwasm/carton/pull/96)) via [@kateinoigakukun](https://github.com/kateinoigakukun)

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
