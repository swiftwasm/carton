# carton 📦

## Watcher, bundler, and test runner for your [SwiftWasm](https://swiftwasm.org/) apps

The main goal of `carton` is to provide a smooth zero-config experience when developing for WebAssembly.
It is still in development, but it aims to support these features (🐥 means "ready to use"):

- 🥚 Creating basic package boilerplate for apps built with SwiftWasm with `carton init`.
- 🐥 Watching the app for source code changes and reloading it in your browser with `carton dev`.
- 🐣 Running your XCTest suite in the full JavaScript/DOM environment with `carton test`.
- 🥚 Optimizing and packaging the app for distribution with `carton bundle`.
- 🐥 Managing SwiftWasm toolchain and SDK installations with `carton sdk`.

It is currently work in progress, so watch the repository for imminent updates!

## Motivation

The main motivation for `carton` came after I had enough struggles with [webpack.js](https://webpack.js.org),
trying to make its config file work, looking for appropriate plugins. I'm convinced that the required use of
`webpack` in SwiftWasm projects could limit the wider adoption of SwiftWasm itself. Hopefully, with `carton`
you can avoid using `webpack` altogether. `carton` also simplifies a few other things in your SwiftWasm
development workflow such as toolchain and SDK installations.

## Requirements

- macOS 10.15 and Xcode 11.4/11.5/11.6 for macOS. Xcode betas are currently not supported. You can have
those installed, but please make sure you use 
[`xcode-select`](https://developer.apple.com/library/archive/technotes/tn2339/_index.html#//apple_ref/doc/uid/DTS40014588-CH1-HOW_DO_I_SELECT_THE_DEFAULT_VERSION_OF_XCODE_TO_USE_FOR_MY_COMMAND_LINE_TOOLS_) 
to point it to a release version of Xcode.
- [Swift 5.2 or later](https://swift.org/download/) for Linux users.

## Installation

On macOS `carton` can be installed with [Homebrew](https://brew.sh/). Make sure you have Homebrew
installed and then run:

```sh
brew install swiftwasm/tap/carton
```

You'll have to build `carton` from sources on Linux. Clone the repository and run
`swift build -c release`, the `carton` binary will be located in the `.build/release/carton`
directory after that.

`carton` automatically installs the required SwiftWasm toolchain and SDK when you build
your project with `carton dev`. You can however install SwiftWasm separately if needed,
either by passing an archive URL to `carton sdk install` directly, or just specifying the snapshot
version, like `carton sdk install wasm-DEVELOPMENT-SNAPSHOT-2020-06-07-a`. `carton dev` can
also detect existing installations of `swiftenv`, so if you already have SwiftWasm installed
via `swiftenv`, you don't have to do anything on top of that to start using `carton`.

## How does it work?

`carton` bundles a [WASI](https://wasi.dev) polyfill, which is currently required to run any SwiftWasm code,
and the [JavaScriptKit](https://github.com/kateinoigakukun/JavaScriptKit/) runtime for convenience.
`carton` also embeds an HTTP server for previewing your SwiftWasm app directly in a browser.
The development version of the polyfill establishes a helper WebSocket connection to the server, so that
it can reload development browser tabs when rebuilt binary is available. This brings the development
experience closer to Xcode live previews, which you may have previously used when developing SwiftUI apps.

`carton` does not require any config files for these basic development scenarios, while some configuration
may be supported in the future, for example for complex asset pipelines if needed. The only requirement
is that your `Package.swift` contains at least a single executable product, which then will be compiled
for WebAssembly and served when you start `carton dev` in the directory where `Package.swift` is located.

`carton` is built with [Vapor](https://vapor.codes/), [SwiftNIO](https://github.com/apple/swift-nio),
[swift-tools-support-core](https://github.com/apple/swift-tools-support-core), and
[OpenCombine](https://github.com/broadwaylamb/OpenCombine), and supports both macOS and Linux. (Many
thanks to everyone supporting and maintaining those projects!)

### Running `carton dev` with the `release` configuration
By default `carton dev` will compile in the `debug` configuration. Add the `--release` flag to compile in the `release` configuration.

## Roadmap

Since a subset of Foundation and XCTest already work and are supplied in the latest snapshots of
SwiftWasm SDK, the next top priority for `carton` is to allow running your XCTest suites directly in
browsers and receiving test results back to the HTTP server, so that test results can be reported in CLI.
This was blocked by [`XCTest` not allowing customized test report formats](https://bugs.swift.org/browse/SR-8436),
which is now partially resolved with [a new argument available on
`XCTMain`](https://github.com/apple/swift-corelibs-xctest/pull/306) and a custom [JSON test
reporter](https://github.com/MaxDesiatov/XCTestJSONObserver/).

There are a few more commands on the roadmap to be implemented, such as `carton bundle` to produce an
optimized production deployment bundle, SwiftPM resources support for bundled assets, and much more.

As cross-compiling to WebAssembly and running apps and tests remotely is not too dissimilar to Android
development, or even development on macOS for Linux through Docker, `carton` could potentially become
a generic tool for cross-platform Swift developers. I'm not developing any Android apps currently, but
if there are interested Swift for Android developers, I'd be very happy to review and merge their
contributions enabling that.

## Contributing

### Sponsorship

If this tool saved you any amount of time or money, please consider [sponsoring
the work of its maintainer](https://github.com/sponsors/MaxDesiatov). While some of the
sponsorship tiers give you priority support or even consulting time, any amount is
appreciated and helps in maintaining the project.

### Coding Style

This project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
and [SwiftLint](https://github.com/realm/SwiftLint) to
enforce formatting and coding style. We encourage you to run SwiftFormat within
a local clone of the repository in whatever way works best for you either
manually or automatically via an [Xcode
extension](https://github.com/nicklockwood/SwiftFormat#xcode-source-editor-extension),
[build phase](https://github.com/nicklockwood/SwiftFormat#xcode-build-phase) or
[git pre-commit
hook](https://github.com/nicklockwood/SwiftFormat#git-pre-commit-hook) etc.

To guarantee that these tools run before you commit your changes on macOS, you're encouraged
to run this once to set up the [pre-commit](https://pre-commit.com/) hook:

```
brew bundle # installs SwiftLint, SwiftFormat and pre-commit
pre-commit install # installs pre-commit hook to run checks before you commit
```

Refer to [the pre-commit documentation page](https://pre-commit.com/) for more details
and installation instructions for other platforms.

SwiftFormat and SwiftLint also run on CI for every PR and thus a CI build can
fail with incosistent formatting or style. We require CI builds to pass for all
PRs before merging.

### Code of Conduct

This project adheres to the [Contributor Covenant Code of
Conduct](https://github.com/swiftwasm/carton/blob/main/CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report
unacceptable behavior to conduct@carton.dev.
