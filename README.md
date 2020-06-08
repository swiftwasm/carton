# carton 📦

`carton` is a watcher, bundler, and test runner for your SwiftWasm apps. The main goal of `carton`
is to provide a smooth zero-config experience when developing for WebAssembly.
It is still in development, but it aims to support these features:

- 🥚 Creating basic package boilerplate for apps built with SwiftWasm with `carton init`.
- 🐣 Watching the app for source code changes and reloading it in your browser with `carton dev`.
- 🐣 Running your XCTest suite in the full JavaScript/DOM environment with `carton test`.
- 🥚 Optimizing and packaging the app for distribution with `carton bundle`.

When using `carton` you don't have to install Node.js or to write your own webpack configs. `carton`
itself uses webpack as a dev dependency to precompile and minify the required WASI polyfill and the
reload-on-rebuild code, but you won't need webpack or Node.js when using carton as an end user.
The polyfill is distributed to you precompiled.

It is currently work in progress, so watch the repository for imminent updates!

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
Conduct](https://github.com/swiftwasm/carton/blob/master/CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report
unacceptable behavior to conduct@carton.dev.
