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

import TSCBasic

// swiftlint:disable force_try
private let jsRegex = try! RegEx(pattern: "(.+?)(?:@(?:\\[(?:native|wasm) code\\]|(.+)))?$")
private let wasmRegex = try! RegEx(pattern: "<\\?>\\.wasm-function\\[(.+)\\]@\\[wasm code\\]")
// swiftlint:enable force_try

public extension StringProtocol {
  var safariStackTrace: [StackTraceItem] {
    split(separator: "\n").compactMap {
      if let wasmMatch = wasmRegex.matchGroups(in: String($0)).first,
         let symbol = wasmMatch.first
      {
        return StackTraceItem(
          symbol: demangle(symbol),
          location: nil,
          kind: .webAssembly
        )
      } else if
        let jsMatch = jsRegex.matchGroups(in: String($0)).first,
        let symbol = jsMatch.first
      {
        let loc: String?
        if jsMatch.count == 2 && !jsMatch[1].isEmpty {
          loc = jsMatch[1]
        } else {
          loc = nil
        }
        return StackTraceItem(symbol: symbol, location: loc, kind: .javaScript)
      }
      return nil
    }
  }
}
