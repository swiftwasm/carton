// Copyright 2020 Carton contributors
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
//
//  Created by Max Desiatov on 08/11/2020.
//

private let webpackRegex = #/(.+)@webpack:///(.+)/#
private let wasmRegex = #/(.+)@http://127.0.0.1.+WebAssembly.instantiate:(.+)/#

extension StringProtocol {
  var firefoxStackTrace: [StackTraceItem] {
    split(separator: "\n").compactMap {
        if let webpackMatch = try? webpackRegex.firstMatch(in: String($0)) {
          let symbol = String(webpackMatch.output.1)
          let location = String(webpackMatch.output.2)
        return StackTraceItem(symbol: symbol, location: location, kind: .javaScript)
      } else if let wasmMatch = try? wasmRegex.firstMatch(in: String($0)) {
        let symbol = String(wasmMatch.output.1)
        let location = String(wasmMatch.output.2)
        return StackTraceItem(
          symbol: demangle(symbol),
          location: location,
          kind: .webAssembly
        )
      }

      return nil
    }
  }
}
