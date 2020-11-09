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
import Splash
import TSCBasic

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

struct TerminalOutputFormat: OutputFormat {
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
/// The compiler output often repeats iteself, and the diagnostics can sometimes be
/// difficult to read.
/// This reformats them to a more readable output.
public struct DiagnosticsParser: ProcessOutputParser {
  public let parsingConditions: ParsingCondition = [.failure]
  // swiftlint:disable force_try
  enum Regex {
    /// The output has moved to a new file
    static let enterFile = try! NSRegularExpression(pattern: #"\[\d+\/\d+\] Compiling \w+ "#)
    /// A message is beginning with the line # following the `:`
    static let line = try! NSRegularExpression(pattern: #"(\/\w+)+\.\w+:"#)
  }

  // swiftlint:enable force_try

  struct CustomDiagnostic {
    let kind: Kind
    let file: String
    /// The number of the row in the source file that the diagnosis is for.
    let lineNumber: Int
    let char: String.SubSequence
    let code: String
    let message: String

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

  public init() {}

  public func parse(_ output: String, _ terminal: InteractiveWriter) {
    let lines = output.split(separator: "\n")
    var lineIdx = 0

    var diagnostics = [String.SubSequence: [CustomDiagnostic]]()

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
            guard file.split(separator: "/").last?
              .replacingOccurrences(of: ":", with: "") == String(currFile)
            else { continue }
            fileMessages.append(
              .init(
                kind: CustomDiagnostic
                  .Kind(rawValue: String(components[2]
                      .trimmingCharacters(in: .whitespaces))) ??
                  .note,
                file: file,
                lineNumber: Int(components[0]),
                char: components[1],
                code: String(lines[lineIdx]),
                message: components.dropFirst(3).joined(separator: ":")
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

    outputDiagnostics(diagnostics, terminal)
  }

  func outputDiagnostics(
    _ diagnostics: [String.SubSequence: [CustomDiagnostic]],
    _ terminal: InteractiveWriter
  ) {
    for (file, messages) in diagnostics.sorted(by: { $0.key < $1.key }) {
      guard messages.count > 0 else { continue }
      terminal.write("\(" \(file) ", color: "[1m", "[7m")") // bold, reversed
      terminal.write(" \(messages.first!.file)\(messages.first!.lineNumber)\n\n", inColor: .grey)
      // Group messages that occur on sequential lines to provide a more readable output
      var groupedMessages = [[CustomDiagnostic]]()
      for message in messages {
        if let finalLineNumber = groupedMessages.last?.last?.lineNumber,
           let currentLineNumber = message.lineNumber,
           finalLineNumber == currentLineNumber - 1 || finalLineNumber == currentLineNumber
        {
          groupedMessages[groupedMessages.count - 1].append(message)
        } else {
          groupedMessages.append([message])
        }
      }
      for messages in groupedMessages {
        // Output the diagnostic message
        for message in messages {
          let kind = message.kind.rawValue.uppercased()
          terminal
            .write(
              "  \(" \(kind) ", color: message.kind.color, "[37;1m") \(message.message)\n"
            ) // 37;1: bright white
        }
        let greatestLineNumber = messages.map(\.lineNumber).max() ?? 0
        let numberOfDigitsInGreatestLineNumber = {
            let (quotient, remainder) = greatestLineNumber.quotientAndRemainder(dividingBy: 10)
            return quotient + (remainder == 0 ? 0 : 1)
        }
        for (offset, message) in messages.enumerated() {
          if offset > 0 {
            // Make sure we don't log the same line twice
            if messages[offset - 1].lineNumber != message.lineNumber {
              flush(
                messages: messages,
                message: message,
                minimumSizeForLineNumbering: numberOfDigitsInGreatestLineNumber,
                terminal: terminal
              )
            }
          } else {
            flush(
              messages: messages,
              message: message,
              minimumSizeForLineNumbering: numberOfDigitsInGreatestLineNumber,
              terminal: terminal
            )
          }
        }
        terminal.write("\n")
      }
      terminal.write("\n")
    }
  }
    
  /// <#Description#>
  /// - Parameters:
  ///   - messages: <#messages description#>
  ///   - message: <#message description#>
  ///   - minimumSizeForLineNumbering: The minimum space that must be reserved for line numbers, so that they are well-aligned in the output.
  ///   - terminal: <#terminal description#>
  func flush(
    messages: [CustomDiagnostic],
    message: CustomDiagnostic,
    minimumSizeForLineNumbering: Int,
    terminal: InteractiveWriter
  ) {
    // Get all diagnostics for a particular line.
    let allChars = messages.filter { $0.lineNumber == message.lineNumber }.map(\.char)
    // Output the code for this line, syntax highlighted
    let highlightedCode = Self.highlighter.highlight(message.code)
    terminal.write("  \("\(paddedLine) | ", color: "[36m")\(highlightedCode)\n") // 36: cyan
    terminal.write("  " + "".padding(toLength: maxLine, withPad: " ", startingAt: 0) + " | ", inColor: .cyan)
    /// A base-10 representation of the number of the row that the diagnosis is for, aligned vertically with all other rows.
    let verticallyAlignedLineNumber = String(message.lineNumber, radix: 10).padding(toLength: minimumSizeForLineNumbering, withPad: " ", startingAt: 0)
    terminal.write("  \("\(verticallyAlignedLineNumber) | ", color: "[36m")\(highlightedCode)\n") // 36: cyan

    // Aggregate the indicators (^ point to the error) onto a single line
    var charIndicators = String(repeating: " ", count: Int(message.char)!) + "^"
    if allChars.count > 0 {
      for char in allChars.dropFirst() {
        let idx = Int(char)!
        if idx >= charIndicators.count {
          charIndicators
            .append(String(repeating: " ", count: idx - charIndicators.count) + "^")
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
