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
//  Created by Jed Fox on 12/6/20.
//

private let jsRegex = #/(.+?)(?:@(?:\[(?:native|wasm) code\]|(.+)))?$/#
private let wasmRegex = #/<\?>\.wasm-function\[(.+)\]@\[wasm code\]/#

extension StringProtocol {
  var safariStackTrace: [StackTraceItem] {
    split(separator: "\n").compactMap {
      if let wasmMatch = try? wasmRegex.firstMatch(in: String($0)) {
        let symbol = String(wasmMatch.output.1)
        return StackTraceItem(
          symbol: demangle(symbol),
          location: nil,
          kind: .webAssembly
        )
      } else if let jsMatch = try? jsRegex.firstMatch(in: String($0)) {
        let symbol = String(jsMatch.output.1)
        let loc: String?
        if let foundLoc = jsMatch.output.2, !foundLoc.isEmpty {
          loc = String(foundLoc)
        } else {
          loc = nil
        }
        return StackTraceItem(symbol: symbol, location: loc, kind: .javaScript)
      }
      return nil
    }
  }
}
