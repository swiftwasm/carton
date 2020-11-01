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

extension StringProtocol {
  /// Remove the first match of the `NSRegularExpression` from the string.
  func matches(regex: NSRegularExpression) -> String.SubSequence? {
    let str = String(self)
    guard let range = str.range(of: regex),
          range.upperBound < str.endIndex
    else { return nil }
    return str[range.upperBound..<str.endIndex]
  }

  /// Find the range of the first match of the `NSRegularExpression`.
  func range(of regex: NSRegularExpression) -> Range<String.Index>? {
    let str = String(self)
    let range = NSRange(location: 0, length: utf16.count)
    guard let match = regex.firstMatch(in: str, options: [], range: range),
          let matchRange = Range(match.range, in: str)
    else {
      return nil
    }
    return matchRange
  }

  func range(of regex: NSRegularExpression, named name: String) -> Range<String.Index>? {
    let str = String(self)
    let range = NSRange(location: 0, length: utf16.count)
    guard let matches = regex.matches(in: str, options: [], range: range).first,
          let matchRange = Range(matches.range(withName: name), in: str)
    else {
      return nil
    }
    return matchRange
  }

  func match(of regex: NSRegularExpression, named name: String) -> String.SubSequence? {
    let str = String(self)
    guard let range = str.range(of: regex, named: name),
          range.upperBound < str.endIndex && range.lowerBound >= str.startIndex
    else { return nil }
    return str[range]
  }
}
