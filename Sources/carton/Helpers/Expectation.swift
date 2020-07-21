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

import Foundation

public struct ExpectationError: Error, CustomStringConvertible {
  public let description: String
}

/** Implements throwing equality assertions, as compared to standard assertions that trap
 in debug mode.
 */
struct Equality<T: Equatable, C> {
  let description: (_ x: T, _ y: T, _ context: C) -> String

  func callAsFunction(_ x: T, _ y: T, context: C) throws {
    guard x == y else { throw ExpectationError(description: description(x, y, context)) }
  }
}
