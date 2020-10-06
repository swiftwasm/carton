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
import TSCBasic
import Splash

private extension StringProtocol {
  func matches(regex: NSRegularExpression) -> String.SubSequence? {
    let str = String(self)
    guard let range = str.range(of: regex),
          range.upperBound < str.endIndex
          else { return nil }
    return str[range.upperBound..<str.endIndex]
  }

  func range(of regex: NSRegularExpression) -> Range<String.Index>? {
    let str = String(self)
    let range = NSRange(location: 0, length: utf16.count)
    guard let match = regex.firstMatch(in: str, options: [], range: range),
          let matchRange = Range(match.range, in: str) else {
      return nil
    }
    return matchRange
  }
}

private extension String.StringInterpolation {
  mutating func appendInterpolation<T>(_ value: T, color: String...) {
    appendInterpolation("\(color.map { "\u{001B}\($0)" }.joined())\(value)\u{001B}[0m")
  }
}

private extension TokenType {
  var color: String {
    // Reference on escape codes: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
    switch self {
    case .keyword: return "[35;1m" // magenta;bold
    case .comment: return "[90m" // bright black
    case .call, .dotAccess, .property, .type: return "[94m" // bright blue
    case .number, .preprocessing: return "[33m" // yellow
    case .string: return "[91;1m" // bright red;bold
    default: return "[0m" // reset
    }
  }
}

private struct TerminalOutputFormat: OutputFormat {
  func makeBuilder() -> TerminalOutputBuilder {
    .init()
  }

  struct TerminalOutputBuilder: OutputBuilder {
    var output: String = ""

    mutating func addToken(_ token: String, ofType type: TokenType) {
      output.append("\(token, color: type.color)")
    }

    mutating func addPlainText(_ text: String) {
      output.append(text)
    }

    mutating func addWhitespace(_ whitespace: String) {
      output.append(whitespace)
    }

    mutating func build() -> String {
      output
    }
  }
}

/// Parses and re-formats diagnostics output by the Swift compiler.
///
/// The compiler output often repeats iteself, and the diagnostics can sometimes be difficult to read.
/// This reformats them to a more readable output.
struct DiagnosticsParser {
  enum Regex {
    /// The output has moved to a new file
    static let enterFile = try! NSRegularExpression(pattern: #"\[\d+\/\d+\] Compiling \w+ "#)
    /// A message is beginning with the line # following the `:`
    static let line = try! NSRegularExpression(pattern: #"(\/\w+)+\.\w+:"#)
  }
  
  struct CustomDiagnostic {
    let kind: Kind
    let file: String
    let line: String.SubSequence
    let char: String.SubSequence
    let code: String
    let message: String.SubSequence

    enum Kind: String {
      case error, warning, note
      var color: String {
        switch self {
        case .error: return "[41;1m" // bright red background
        case .warning: return "[43;1m" // bright yellow background
        case .note: return "[7m" // reversed
        }
      }
    }
  }

  fileprivate static let highlighter = SyntaxHighlighter(format: TerminalOutputFormat())

  func parse(_ output: String, _ terminal: InteractiveWriter) {
    let lines = output.split(separator: "\n")
    var lineIdx = 0

    var diagnostics = [String.SubSequence:[CustomDiagnostic]]()

    var currFile: String.SubSequence?
    var fileMessages = [CustomDiagnostic]()

    while lineIdx < lines.count {
      let line = lines[lineIdx]
      if let file = line.matches(regex: Regex.enterFile) {
        if let currFile = currFile {
          diagnostics[currFile] = fileMessages
        }
        currFile = file
        fileMessages = []
      } else if let currFile = currFile {
        if let message = line.matches(regex: Regex.line) {
          let components = message.split(separator: ":")
          if components.count > 3 {
            lineIdx += 1
            let file = line.replacingOccurrences(of: message, with: "")
            guard file.split(separator: "/").last?.replacingOccurrences(of: ":", with: "") == String(currFile) else { continue }
            fileMessages.append(
              .init(
                kind: CustomDiagnostic.Kind(rawValue: String(components[2].trimmingCharacters(in: .whitespaces))) ?? .note,
                file: file,
                line: components[0],
                char: components[1],
                code: String(lines[lineIdx]),
                message: components[3]
              )
            )
          }
        }
      } else {
        terminal.write(String(line) + "\n", inColor: .cyan)
      }
      lineIdx += 1
    }
    if let currFile = currFile {
      diagnostics[currFile] = fileMessages
    }

    for (file, messages) in diagnostics.sorted(by: { $0.key < $1.key }) {
      guard messages.count > 0 else { continue }
      terminal.write("\(" \(file) ", color: "[1m", "[7m")") // bold, reversed
      terminal.write(" \(messages.first!.file)\(messages.first!.line)\n\n", inColor: .grey)
      // Group messages that occur on sequential lines to provie a more readable output
      var groupedMessages = [[CustomDiagnostic]]()
      for message in messages {
        if let lastLineStr = groupedMessages.last?.last?.line,
           let lastLine = Int(lastLineStr),
           let line = Int(message.line),
           lastLine == line - 1 || lastLine == line {
          groupedMessages[groupedMessages.count - 1].append(message)
        } else {
          groupedMessages.append([message])
        }
      }
      for messages in groupedMessages {
        // Output the diagnostic message
        for message in messages {
          terminal.write("  \(" \(message.kind.rawValue.uppercased()) ", color: message.kind.color, "[37;1m") \(message.message)\n") // 37;1: bright white
        }
        let maxLine = messages.map(\.line.count).max() ?? 0
        for (offset, message) in messages.enumerated() {
          if offset > 0 {
            // Make sure we don't log the same line twice
            if messages[offset - 1].line != message.line {
              flush(messages: messages, message: message, maxLine: maxLine, terminal)
            }
          } else {
            flush(messages: messages, message: message, maxLine: maxLine, terminal)
          }
        }
        terminal.write("\n")
      }
      terminal.write("\n")
    }
  }

  func flush(messages: [CustomDiagnostic], message: CustomDiagnostic, maxLine: Int, _ terminal: InteractiveWriter) {
    // Get all diagnostics for a particular line.
    let allChars = messages.filter { $0.line == message.line }.map(\.char)
    // Output the code for this line, syntax highlighted
    terminal.write("  \("\(message.line.padding(toLength: maxLine, withPad: " ", startingAt: 0)) | ", color: "[36m")\(Self.highlighter.highlight(message.code))\n") // 36: cyan
    terminal.write("  " + "".padding(toLength: maxLine, withPad: " ", startingAt: 0) + " | ", inColor: .cyan)

    // Aggregate the indicators (^ point to the error) onto a single line
    var charIndicators = String(repeating: " ", count: Int(message.char)!) + "^"
    if allChars.count > 0 {
      for char in allChars.dropFirst() {
        let idx = Int(char)!
        if idx >= charIndicators.count {
          charIndicators.append(String(repeating: " ", count: idx - charIndicators.count) + "^")
        } else {
          var arr = Array(charIndicators)
          arr[idx] = "^"
          charIndicators = String(arr)
        }
      }
    }
    terminal.write("\(charIndicators)\n", inColor: .red, bold: true)
  }
}
