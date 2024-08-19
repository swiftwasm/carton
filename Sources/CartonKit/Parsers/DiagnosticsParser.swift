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

/// Parses and re-formats diagnostics output by the Swift compiler.
///
/// The compiler output often repeats itself, and the diagnostics can sometimes be
/// difficult to read.
/// This reformats them to a more readable output.
struct DiagnosticsParser {
  struct CustomDiagnostic {
    let kind: Kind
    let file: String
    let line: String.SubSequence
    let char: String.SubSequence
    let code: String
    let message: String

    enum Kind: String {
      case error, warning, note
      var color: String {
        switch self {
        case .error: return "[41;1m"  // bright red background
        case .warning: return "[43;1m"  // bright yellow background
        case .note: return "[7m"  // reversed
        }
      }
    }
  }
}
