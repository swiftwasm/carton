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

import CartonCore

public protocol ProcessOutputParser {
  /// Parse the output of a `Process`, format it, then output in the `InteractiveWriter`.
  func parse(_ output: String, _ terminal: InteractiveWriter)
  /// Under what conditions should the output be parsed?
  var parsingConditions: ParsingCondition { get }
  init()
}

public struct ParsingCondition: OptionSet {
  public let rawValue: Int
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let success: Self = .init(rawValue: 1 << 0)
  public static let failure: Self = .init(rawValue: 1 << 1)
}
