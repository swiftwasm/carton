// Copyright 2024 Carton contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// The target environment to build for.
/// `Environment` doesn't specify the concrete environment, but the type of environments enough for build planning.
internal enum Environment: String, CaseIterable {
  case command
  case node
  case browser

  static func parse(_ string: String) -> (Environment?, diagnostics: String?) {
    // Find from canonical names
    if let found = allCases.first(where: { $0.rawValue == string }) {
      return (found, nil)
    }

    // Find from deprecated names
    switch string {
    case "wasmer":
      return (.command, "The 'wasmer' environment is renamed to 'command'")
    case "defaultBrowser":
      return (.browser, "The 'defaultBrowser' environment is renamed to 'browser'")
    default:
      return (nil, nil)
    }
  }

  struct Parameters {
    var otherSwiftcFlags: [String] = []
    var otherLinkerFlags: [String] = []
  }

  func applyBuildParameters(_ parameters: inout Parameters) {
    // NOTE: We only support static linking for now, and the new SwiftDriver
    // does not infer `-static-stdlib` for WebAssembly targets intentionally
    // for future dynamic linking support.
    parameters.otherSwiftcFlags += ["-static-stdlib"]

    switch self {
    case .command: break
    case .node, .browser:
      parameters.otherSwiftcFlags += ["-Xclang-linker", "-mexec-model=reactor"]
      #if compiler(>=6.0) || compiler(>=5.11)
      parameters.otherLinkerFlags += ["--export-if-defined=__main_argc_argv"]
      #else
      // Before Swift 6.0, the main function is defined as "main" instead of mangled "__main_argc_argv"
      parameters.otherLinkerFlags += ["--export-if-defined=main"]
      #endif
    }
  }
}
