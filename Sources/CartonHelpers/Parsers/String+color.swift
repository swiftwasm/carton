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

extension String.StringInterpolation {
  /// Display `value` with the specified ANSI-escaped `color` values, then apply the reset.
  mutating func appendInterpolation<T>(_ value: T, color: String...) {
    appendInterpolation("\(color.map { "\u{001B}\($0)" }.joined())\(value)\u{001B}[0m")
  }
}
