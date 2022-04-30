# 0.14.2 (30 April 2022)

This is a bugfix release resolving an issue with JavaScript entrypoint code.

Many thanks to [@fjtrujy](https://github.com/fjtrujy) for the contribution!

**Closed issues:**

* Apply `clock_res_get` patch in all entrypoints ([#321](https://github.com/swiftwasm/carton/issues/321))

**Merged pull requests:** 

- Update SwiftPM dependencies ([#319](https://github.com/swiftwasm/carton/pull/319)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update SwiftPM dependencies ([#320](https://github.com/swiftwasm/carton/pull/320)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Override `clock_res_get` function from `wasmer/wasi-js` to fix memory issue ([#323](https://github.com/swiftwasm/carton/pull/323)) via [@fjtrujy](https://github.com/fjtrujy)

# 0.14.1 (11 April 2022)

This is a bugfix release that resolves an issue with `carton test` introduced in 0.14.0. Many thanks to
[@SDGGiesbrecht](https://github.com/SDGGiesbrecht) for reporting, and to [@kateinoigakukun](https://github.com/kateinoigakukun)
for fixing it!

**Closed issues:**

- “carton test” fails to run as of 0.14.0 ([#313](https://github.com/swiftwasm/carton/issues/313))

**Merged pull requests:**

- Fix "No export `_start` found in the module" error in `carton test` ([#314](https://github.com/swiftwasm/carton/pull/314)) via [@kateinoigakukun](https://github.com/kateinoigakukun)

# 0.14.0 (9 April 2022)

This release uses SwiftWasm 5.6.0 as the default toolchain. Additionally, issue with rebuilding projects when watching
for file changes with `carton dev` has been fixed. Also refer to [release details for `carton` 0.13.0](https://github.com/swiftwasm/carton/releases/tag/0.13.0) for more information on new recently introduced flags.

Many thanks to [@kateinoigakukun](https://github.com/kateinoigakukun)
for contributions!

**Closed issues:**

- Watcher doesn't see my changes ([#295](https://github.com/swiftwasm/carton/issues/295))

**Merged pull requests:**

- Several fixes for 5.6 toolchain ([#310](https://github.com/swiftwasm/carton/pull/310)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Update SwiftPM dependencies ([#309](https://github.com/swiftwasm/carton/pull/309)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Describe `--debug-info` and `-Xswiftc` in `README.md` ([#308](https://github.com/swiftwasm/carton/pull/308)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix watcher blocked by Vapor `run()` ([#307](https://github.com/swiftwasm/carton/pull/307)) via [@kateinoigakukun](https://github.com/kateinoigakukun)

# 0.13.0 (31 March 2022)

This is a small feature release with a few bugfixes. Namely, new `-Xswiftc` option was added for forwarding flags to
underlying `swiftc` invocations. Also, new `--debug-info` flag allows keeping debug information even for release builds.
Additionally, we've fixed a crash with `executableTarget` declarations in `Package.swift` manifests, and switched to
SwiftPM 5.6 API in preparation for the imminent SwiftWasm 5.6 release.

This version of `carton` now ships with JavaScriptKit 0.13.0 runtime.

**WARNING**: this release of `carton` is not compatible with latest Tokamak or SwiftWasm 5.6 snapshots or releases yet. You should stay with `carton` 0.12.2 for now if you're building apps and libraries with Tokamak. A future release of `carton` will resolve this incompatibility.

Thanks to [@kateinoigakukun](https://github.com/kateinoigakukun) and [@yonihemi](https://github.com/yonihemi) for
contributions, and to [@pedrovgs](https://github.com/pedrovgs) for additional testing and bug reports.

**Closed issues:**

- Detecting completion of Wasm module instantiation ([#290](https://github.com/swiftwasm/carton/issues/290))
- Add support for Swift 5.6 package description format ([#285](https://github.com/swiftwasm/carton/issues/285))
- Add support for `-Xswiftc` arguments ([#277](https://github.com/swiftwasm/carton/issues/277))

**Merged pull requests:**

- Bump JavaScriptKit dependency to 0.13.0 ([#306](https://github.com/swiftwasm/carton/pull/306)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Don't strip custom sections when using `--debug-info` ([#304](https://github.com/swiftwasm/carton/pull/304)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Update dependencies ([#298](https://github.com/swiftwasm/carton/pull/298)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add macOS 12 and Xcode 13.3 to CI matrix ([#303](https://github.com/swiftwasm/carton/pull/303)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add `--debug-info` flag to carton bundle ([#301](https://github.com/swiftwasm/carton/pull/301)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Use libSwiftPM 5.6 to parse manifests ([#302](https://github.com/swiftwasm/carton/pull/302)) via [@yonihemi](https://github.com/yonihemi)
- Add `-Xswiftc` option for each build commands ([#300](https://github.com/swiftwasm/carton/pull/300)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Update dependencies ([#297](https://github.com/swiftwasm/carton/pull/297)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix crash for packages with `executableTarget` ([#296](https://github.com/swiftwasm/carton/pull/296)) via [@yonihemi](https://github.com/yonihemi)

# 0.12.2 (16 February 2022)

This release features a massive refactor by [@MaxDesiatov](https://github.com/MaxDesiatov) to use Swift 5.5's `async/await` and actors, reducing its size, improving readability and removing Combine/OpenCombine dependency, as well as CI and Linux installation improvements.
JavaScriptKit and Tokamak versions in templates were bumped to 0.12.0 and 0.9.1 respectively.

**Merged pull requests:**

- Update dependencies ([#293](https://github.com/swiftwasm/carton/pull/293)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#289](https://github.com/swiftwasm/carton/pull/289)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add libsqlite3-dev dependency ([#288](https://github.com/swiftwasm/carton/pull/288)) via [@SwiftCoderJoe](https://github.com/SwiftCoderJoe)
- Upgrade binaryen version to 105 ([#286](https://github.com/swiftwasm/carton/pull/286)) via [@fjtrujy](https://github.com/fjtrujy)
- Use `async/await` and actors instead of Combine ([#283](https://github.com/swiftwasm/carton/pull/283)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#284](https://github.com/swiftwasm/carton/pull/284)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Statically link with `SwiftPMDataModel` library ([#275](https://github.com/swiftwasm/carton/pull/275)) via [@yonihemi](https://github.com/yonihemi)
- Build `main` Docker images on every push to `main` branch ([#272](https://github.com/swiftwasm/carton/pull/272)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#282](https://github.com/swiftwasm/carton/pull/282)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#279](https://github.com/swiftwasm/carton/pull/279)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#273](https://github.com/swiftwasm/carton/pull/273)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix Wasmer installation issues in `Dockerfile` ([#276](https://github.com/swiftwasm/carton/pull/276)) via [@MaxDesiatov](https://github.com/MaxDesiatov)

# 0.12.1 (1 December 2021)

This is a bugfix release that fixes linking issues with ICU that some users could've experienced
with `carton dev` and `carton bundle`. Many thanks to [@Sefford](https://github.com/Sefford) for
reporting this and providing detailed issue description!

**Closed issues:**

- Carton 0.12.0 with SwiftWasm 5.5.0 fails with linker command ([#268](https://github.com/swiftwasm/carton/issues/268))

**Merged pull requests:**

- Bump SwiftWasm to 5.5 in `Dockerfile`, bump AHC ([#269](https://github.com/swiftwasm/carton/pull/269)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add ICU linker flags to all build invocation ([#270](https://github.com/swiftwasm/carton/pull/270)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#261](https://github.com/swiftwasm/carton/pull/261)) via [@MaxDesiatov](https://github.com/MaxDesiatov)

# 0.12.0 (27 November 2021)

This release bumps the default version of SwiftWasm distribution to 5.5.0. For projects that don't
specify their preferred version of SwiftWasm in `.swift-version`, `carton` will now download SwiftWasm
5.5.0.

Since SwiftWasm 5.5.0 now provides distributions for Apple Silicon, `carton` will
download such distributions by default on compatible hardware. Run `carton` under Rosetta if you
prefer to use x86_64 builds of SwiftWasm on macOS.

JavaScriptKit and Tokamak versions in templates were bumped to 0.11.1 and 0.9.0 respectively.

Additionally, a bug with demangling of stack traces was fixed. Thanks to [@Feuermurmel](https://github.com/Feuermurmel)
for the contribution!

**Closed issues:**

- Download Apple Silicon builds for releases that have them available ([#262](https://github.com/swiftwasm/carton/issues/262))
- Stack trace demangling ([#248](https://github.com/swiftwasm/carton/issues/248))
- Docker tag for 0.10.0? ([#246](https://github.com/swiftwasm/carton/issues/246))

**Merged pull requests:**

- Use SwiftWasm 5.5.0, bump version to 0.12.0 ([#266](https://github.com/swiftwasm/carton/pull/266)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update JavaScriptKit to v0.11.1 ([#265](https://github.com/swiftwasm/carton/pull/265)) via [@yonihemi](https://github.com/yonihemi)
- Update dependencies, add support for SwiftWasm 5.5 ([#263](https://github.com/swiftwasm/carton/pull/263)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix environment detection from User-Agent header ([#249](https://github.com/swiftwasm/carton/pull/249)) via [@Feuermurmel](https://github.com/Feuermurmel)
- Update dependencies ([#260](https://github.com/swiftwasm/carton/pull/260)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Disable `--enable-test-discovery` for old versions ([#257](https://github.com/swiftwasm/carton/pull/257)) via [@MaxDesiatov](https://github.com/MaxDesiatov)

# 0.11.1 (2 September 2021)

This is a bugfix release that fixes an issue with dynamic linking to `libSwiftPMDataModel.so` in Ubuntu images for Docker.

# 0.11.0 (2 September 2021)

This release bumps the default version of SwiftWasm distribution to 5.4.0. For projects that don't
specify their preferred version of SwiftWasm in `.swift-version`, starting with this version
`carton` will download SwiftWasm 5.4.0.

No other major changes are included in this release.

**Merged pull requests:**

- Bump version to 0.11.0, update dependencies ([#251](https://github.com/swiftwasm/carton/pull/251)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update link in `README.md` ([#252](https://github.com/swiftwasm/carton/pull/252)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#247](https://github.com/swiftwasm/carton/pull/247)) via [@MaxDesiatov](https://github.com/MaxDesiatov)

# 0.10.0 (30 May 2021)

This is a bugfix release that resolves issues with incorrect or missing diagnostic output, improves
our end-to-end test coverage, and updates dependencies and `carton init` templates.

Additionally, we improved support for demangling stack traces in different browsers, and added
a stack overflow sanitizer that's enabled by default for debug builds.

Many thanks (in alphabetical order) to [@j-f1](https://github.com/j-f1),
[@kateinoigakukun](https://github.com/kateinoigakukun), [@literalpie](https://github.com/literalpie),
[@thecb4](https://github.com/thecb4), and [@yonihemi](https://github.com/yonihemi) for their
contributions to this release!

**Closed issues:**

- `carton test` command unable to find gtk+3 using `--template tokamak` ([#241](https://github.com/swiftwasm/carton/issues/241))
- `carton` also requires zlib.h to compile from source ([#237](https://github.com/swiftwasm/carton/issues/237))
- `carton test --environment defaultBrowser` broken on GitHub Actions ([#200](https://github.com/swiftwasm/carton/issues/200))
- Add `--host` option to `carton dev` and `carton test` ([#193](https://github.com/swiftwasm/carton/issues/193))
- Replace hard-coded path delimiters ([#183](https://github.com/swiftwasm/carton/issues/183))
- Use libSwiftPM instead of custom model types ([#120](https://github.com/swiftwasm/carton/issues/120))

**Merged pull requests:**

- Update JSKit and Tokamak versions in templates ([#243](https://github.com/swiftwasm/carton/pull/243)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix Ubuntu deps, clarify Linux support in `README.md` ([#242](https://github.com/swiftwasm/carton/pull/242)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add more browsers to `DestinationEnvironment` ([#228](https://github.com/swiftwasm/carton/pull/228)) via [@j-f1](https://github.com/j-f1)
- Fix `carton dev` crashing with SO sanitizer ([#239](https://github.com/swiftwasm/carton/pull/239)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Avoid building in `release` mode when testing ([#240](https://github.com/swiftwasm/carton/pull/240)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update JS dependencies in `package-lock.json` ([#231](https://github.com/swiftwasm/carton/pull/231)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Integrate stack sanitizer ([#230](https://github.com/swiftwasm/carton/pull/230)) via [@kateinoigakukun](https://github.com/kateinoigakukun)
- Add `carton init` with template test. Supports #99 ([#221](https://github.com/swiftwasm/carton/pull/221)) via [@thecb4](https://github.com/thecb4)
- Add host argument to `dev` and `test` commands ([#213](https://github.com/swiftwasm/carton/pull/213)) via [@literalpie](https://github.com/literalpie)
- Add tests for `sdk versions` and `sdk local` commands ([#218](https://github.com/swiftwasm/carton/pull/218)) via [@thecb4](https://github.com/thecb4)
- Add test for `carton sdk install` ([#217](https://github.com/swiftwasm/carton/pull/217)) via [@thecb4](https://github.com/thecb4)
- Use libSwiftPM instead of custom model types ([#194](https://github.com/swiftwasm/carton/pull/194)) via [@yonihemi](https://github.com/yonihemi)
- Add end-to-end tests for `carton test ` command ([#209](https://github.com/swiftwasm/carton/pull/209)) via [@thecb4](https://github.com/thecb4)
- Link to the org sponsorship page from `README.md` ([#210](https://github.com/swiftwasm/carton/pull/210)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update the "Roadmap" section in `README.md` ([#207](https://github.com/swiftwasm/carton/pull/207)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Avoid running tests while building the Docker image ([#204](https://github.com/swiftwasm/carton/pull/204)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix browser testing for Safari, update `tasks.json` ([#202](https://github.com/swiftwasm/carton/pull/202)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Add `test` command test with no arguments ([#198](https://github.com/swiftwasm/carton/pull/198)) via [@thecb4](https://github.com/thecb4)

# 0.9.1 (19 December 2020)

This is a bugfix release that fixes parsing of `Package.swift` manifests that contain dependencies on system targets. It also adds support for Chrome and Safari stack traces. Many thanks to [@j-f1](https://github.com/j-f1) for the contribution!

**Merged pull requests:**

- Update dependencies ([#188](https://github.com/swiftwasm/carton/pull/188)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix parsing system targets in `Package.swift` ([#189](https://github.com/swiftwasm/carton/pull/189)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump ini from 1.3.5 to 1.3.8 ([#187](https://github.com/swiftwasm/carton/pull/187)) via [@dependabot[bot]](https://github.com/dependabot[bot])
- Add support for Chrome and Safari stack traces ([#186](https://github.com/swiftwasm/carton/pull/186)) via [@j-f1](https://github.com/j-f1)
- Update dependencies ([#184](https://github.com/swiftwasm/carton/pull/184)) via [@MaxDesiatov](https://github.com/MaxDesiatov)

# 0.9.0 (4 December 2020)

This release adds multiple changes and new features:

- New `--environment` option on `carton test`, which when passed `--environment defaultBrowser` runs
  test suites of a given package in your default browser, allowing you to use JavaScriptKit and
  other browser-specific dependencies in your tests. Another available option is `--environment wasmer`, which is the old and still the default behavior, which runs the test suite in `wasmer`.

- Now when your SwiftWasm app crashes in Firefox, the strack trace will printed by `carton dev` and
  `carton test` in terminal with function symbols demangled, which makes crashes much easier to
  debug. Since different browsers format their stack traces differently, support for browsers other
  than Firefox will be added separately in a future version of `carton`.

- `carton dev` and `carton bundle` now serve SwiftPM resources declared on targets of executable
  products from the root `/` path, in addition to a subpath automatically generated for
  `Bundle.module`. This was a necessary change [to allow the `Image`
  view](https://github.com/TokamakUI/Tokamak/pull/155#issuecomment-723677472) to work properly in
  [Tokamak](https://github.com/TokamakUI/Tokamak).

- Support for [JavaScriptKit](https://github.com/swiftwasm/javascriptkit) 0.9.0, which allows
  catching JavaScript exceptions in Swift code.

- The default SwiftWasm toolchain is now 5.3.1, which is a recommended bugfix update for all of our
  users.

**Merged pull requests:**

- Mark all commands as implemented in `README.md` ([#180](https://github.com/swiftwasm/carton/pull/180)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump versions of libraries in `Template.swift` ([#182](https://github.com/swiftwasm/carton/pull/182)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Serve main bundle resources from root directory ([#176](https://github.com/swiftwasm/carton/pull/176)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Use `FileDownloadDelegate` from the AHC package ([#171](https://github.com/swiftwasm/carton/pull/171)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump JSKit, add support for testing in browsers ([#173](https://github.com/swiftwasm/carton/pull/173)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#179](https://github.com/swiftwasm/carton/pull/179)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Bump `defaultToolchainVersion` to 5.3.1 ([#178](https://github.com/swiftwasm/carton/pull/178)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Demangle and print Firefox stack traces in terminal ([#162](https://github.com/swiftwasm/carton/pull/162)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#172](https://github.com/swiftwasm/carton/pull/172)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Update dependencies ([#170](https://github.com/swiftwasm/carton/pull/170)) via [@MaxDesiatov](https://github.com/MaxDesiatov)

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
