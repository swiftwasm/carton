# carton 📦

## Watcher, bundler, and test runner for your [SwiftWasm](https://swiftwasm.org/) apps

The main goal of `carton` is to provide a smooth zero-config experience when developing for WebAssembly.
It currently supports these features with separate commands:

- Creating basic package boilerplate for apps built with SwiftWasm with `carton init`.
- Watching the app for source code changes and reloading it in your browser with `carton dev`.
- Running your XCTest suite in the full JavaScript/DOM environment with `carton test`.
- Optimizing and packaging the app for distribution with `carton bundle`.
- Managing SwiftWasm toolchain and SDK installations with `carton sdk`.

## Motivation

The main motivation for `carton` came after having enough struggles with
[webpack.js](https://webpack.js.org), trying to make its config file work, looking for appropriate
plugins. At some point the maintainers became convinced that the required use of `webpack` in
SwiftWasm projects could limit the wider adoption of SwiftWasm itself. Hopefully, with `carton` you
can avoid using `webpack` altogether. `carton` also simplifies a few other things in your SwiftWasm
development workflow such as toolchain and SDK installations.

## Getting started

### Requirements

- macOS 10.15 and Xcode 12.0 or later.
- [Swift 5.3 or later](https://swift.org/download/) and Ubuntu 18.04 or 20.04 for Linux users.

### Installation

On macOS `carton` can be installed with [Homebrew](https://brew.sh/). Make sure you have Homebrew
installed and then run:

```sh
brew install swiftwasm/tap/carton
```

`carton` is also available as a Docker image for Linux. You can pull it with this command:

```
docker pull ghcr.io/swiftwasm/carton:latest
```

If Docker images are not suitable for you, you'll have to build `carton` from sources on Ubuntu, and
unfortunately other Linux distributions are currently not supported. Clone the repository and run
`swift build -c release`, the `carton` binary will be located in the `.build/release` directory
after that.

### Usage

The `carton init` command initializes a new SwiftWasm project for you (similarly to `swift package init`) with multiple templates available at your choice. `carton init --template tokamak` creates a
new [Tokamak](https://tokamak.dev/) project, while `carton init --template basic` (equivalent to
`carton init`) creates an empty SwiftWasm project with no dependencies. Also, `carton init list-templates` provides a complete list of templates (with only `basic` and `tokamak` available
currently).

The `carton dev` command builds your project with the SwiftWasm toolchain and starts an HTTP server
that hosts your WebAssembly executable and a corresponding JavaScript entrypoint that loads it. The
app, reachable at [http://127.0.0.1:8080/](http://127.0.0.1:8080/), will automatically open in your
default web browser. The port that the development server uses can also be controlled with the
`--port` option (or `-p` for short). You can edit the app source code in your favorite editor and
save it, `carton` will immediately rebuild the app and reload all browser tabs that have the app
open. You can also pass a `--verbose` flag to keep the build process output available, otherwise
stale output is cleaned up from your terminal screen by default. If you have a custom `index.html`
page you'd like to use when serving, pass a path to it with a `--custom-index-page` option.

The `carton test` command runs your test suite in the [`wasmer`](https://wasmer.io/) environment,
or in the browser environment. You can switch between these with the `--environment` option, passing
either `wasmer` or `defaultBrowser` values to it respectively.

The `carton sdk` command and its subcommands allow you to manage installed SwiftWasm toolchains, but
is rarely needed, as `carton dev` installs the recommended version of SwiftWasm automatically.
`carton sdk versions` lists all installed versions, and `carton sdk local` prints the version
specified for the current project in the `.swift-version` file. You can however install SwiftWasm
separately if needed, either by passing an archive URL to `carton sdk install` directly, or just
specifying the snapshot version, like `carton sdk install wasm-5.3-SNAPSHOT-2020-09-25-a`.

`carton dev` can also detect existing installations of `swiftenv`, so if you already have SwiftWasm
installed via `swiftenv`, you don't have to do anything on top of that to start using `carton`.

The `carton bundle` command builds your project using the `release` configuration (although you can
pass the `--debug` flag to it to change that), and copies all required assets to the `Bundle`
directory. You can then use a static file hosting (e.g. [GitHub Pages](https://pages.github.com/))
or any other server with support for static files to deploy your application. All resulting bundle
files except `index.html` are named by their content hashes to enable [cache
busting](https://www.keycdn.com/support/what-is-cache-busting). As with `carton dev`, a custom
`index.html` page can be provided through the `--custom-index-page` option.

The `carton package` command proxies its subcommands to `swift package` invocations on the
currently-installed toolchain. This may be useful in situations where you'd like to generate an
Xcode project file for your app with something like `carton package generate-xcodeproj`. It would be
equivalent to `swift package generate-xcodeproj`, but invoked with the SwiftWasm toolchain instead
of the toolchain supplied by Xcode.

All of these commands and subcommands can be passed a `--help` flag that prints usage info and
information about all available options.

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

As cross-compiling to WebAssembly and running apps and tests remotely is not too dissimilar to Android
development, or even development on macOS for Linux through Docker, `carton` could potentially become
a generic tool for cross-platform Swift developers. I'm not developing any Android apps currently, but
if there are interested Swift for Android developers, I'd be very happy to review and merge their
contributions enabling that.

## Contributing

### Sponsorship

If this tool saved you any amount of time or money, please consider sponsoring
the work of its maintainers on their sponsorship pages:
[@carson-katri](https://github.com/sponsors/carson-katri),
[@kateinoigakukun](https://github.com/sponsors/kateinoigakukun), and
[@MaxDesiatov](https://github.com/sponsors/MaxDesiatov). While some of the
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
fail with inconsistent formatting or style. We require CI builds to pass for all
PRs before merging.

### Code of Conduct

This project adheres to the [Contributor Covenant Code of
Conduct](https://github.com/swiftwasm/carton/blob/main/CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report
unacceptable behavior to conduct@carton.dev.
