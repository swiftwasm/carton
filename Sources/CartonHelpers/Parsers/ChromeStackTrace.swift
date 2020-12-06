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
fileprivate let webpackRegex = try! RegEx(pattern: "at (.+) \\(webpack:///(.+?)\\)")
fileprivate let wasmRegex = try! RegEx(pattern: "at (.+) \\(<anonymous>:(.+?)\\)")
// swiftlint:enable force_try

public extension StringProtocol {
  var chromeStackTrace: [StackTraceItem] {
    split(separator: "\n").dropFirst().compactMap {
      if let webpackMatch = webpackRegex.matchGroups(in: String($0)).first,
         let symbol = webpackMatch.first,
         let location = webpackMatch.last
      {
        return StackTraceItem(symbol: symbol, location: location, kind: .javaScript)
      } else if
        let wasmMatch = wasmRegex.matchGroups(in: String($0)).first,
        let symbol = wasmMatch.first,
        let location = wasmMatch.last
      {
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

