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

extension String.StringInterpolation {
  fileprivate mutating func appendInterpolation(_ regexLabel: TestsParser.Regex.Label) {
    appendInterpolation("<\(regexLabel.rawValue)>")
  }
}

extension StringProtocol {
  fileprivate func range(
    of regex: NSRegularExpression,
    labelled label: TestsParser.Regex.Label
  ) -> Range<String.Index>? {
    range(of: regex, named: label.rawValue)
  }

  fileprivate func match(of regex: NSRegularExpression, labelled label: TestsParser.Regex.Label)
    -> String
    .SubSequence?
  {
    match(of: regex, named: label.rawValue)
  }

  fileprivate func match(
    of regex: NSRegularExpression,
    labelled labelA: TestsParser.Regex.Label,
    _ labelB: TestsParser.Regex.Label
  ) -> (String.SubSequence, String.SubSequence)? {
    guard let a = match(of: regex, named: labelA.rawValue),
      let b = match(of: regex, named: labelB.rawValue)
    else {
      return nil
    }
    return (a, b)
  }
}

public struct TestsParser: ProcessOutputParser {
  public init() {}

  public let parsingConditions: ParsingCondition = [.success, .failure]

  // swiftlint:disable force_try
  // swiftlint:disable line_length
  enum Regex {
    enum Label: String {
      case suite
      case testCase
      case status
      case timestamp

      case testCount
      case failCount
      case unexpectedCount
      case duration

      case path
      case line

      case received
      case expected
    }

    static let suiteStarted = try! NSRegularExpression(
      pattern:
        #"Test Suite '(?\#(.suite)[^']*)' started at (?\#(.timestamp)\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})"#
    )
    static let suiteFinished = try! NSRegularExpression(
      pattern:
        #"Test Suite '(?\#(.suite)[^']*)' (?\#(.status)(failed|passed)) at (?\#(.timestamp)\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})"#
    )
    static let suiteSummary = try! NSRegularExpression(
      pattern:
        #"Executed (?\#(.testCount)\d+) (test|tests), with (?\#(.failCount)\d+) (failure|failures) \((?\#(.unexpectedCount)\d+) unexpected\) in (?\#(.duration)\d+\.\d+) \(\d+\.\d+\) seconds"#
    )
    static let caseFinished = try! NSRegularExpression(
      pattern:
        #"Test Case '(?\#(.suite)[^']+)\.(?\#(.testCase)[^']+)' (?\#(.status)(failed|passed)) \((?\#(.duration)(\d+)\.(\d+)) seconds\)"#
    )
    static let problem = try! NSRegularExpression(
      pattern:
        #"(?\#(.path)(.+)(\/|)([^/]+)):(?\#(.line)\d+): (?\#(.status)\w+): (?\#(.suite)\w+)\.(?\#(.testCase)\w+) : "#
    )

    enum Assertion: String, CaseIterable {
      case equal = "Equal",
        greaterThan = "GreaterThan",
        lessThan = "LessThan",
        greaterThanOrEqual = "GreaterThanOrEqual",
        lessThanOrEqual = "LessThanOrEqual"

      var funcName: String {
        "XCTAssert\(rawValue)"
      }

      var innerMessage: String {
        switch self {
        case .equal: return "is not equal to"
        case .greaterThan: return "is not greater than"
        case .lessThan: return "is not less than"
        case .greaterThanOrEqual: return "is less than"
        case .lessThanOrEqual: return "is greater than"
        }
      }

      var symbol: String {
        switch self {
        case .equal: return ""
        case .greaterThan: return ">"
        case .lessThan: return "<"
        case .greaterThanOrEqual: return ">="
        case .lessThanOrEqual: return "<="
        }
      }
    }

    static let xctAssertEqual = try! NSRegularExpression(
      pattern: #"XCTAssertEqual failed: (?\#(.received).*) is not equal to (?\#(.expected).*) - "#
    )
    static let xctAssertGreaterThan = try! NSRegularExpression(
      pattern:
        #"XCTAssertGreaterThan failed: (?\#(.received).*) is not greater than (?\#(.expected).*) - "#
    )
    static let xctAssertLessThan = try! NSRegularExpression(
      pattern:
        #"XCTAssertLessThan failed: (?\#(.received).*) is not less than (?\#(.expected).*) - "#
    )

    static func xctAssert(_ assertion: Assertion) -> NSRegularExpression {
      try! NSRegularExpression(
        pattern:
          #"\#(assertion.funcName) failed: \("(?\#(.received).*)"\) \#(assertion.innerMessage) \("(?\#(.expected).*)"\) - "#
      )
    }
  }

  // swiftlint:enable line_length
  // swiftlint:enable force_try

  struct Suite {
    let name: String.SubSequence
    var passed: Bool {
      fails == 0
    }

    var cases: [Case]
    var fails: Int {
      cases.filter { !$0.passed }.count
    }

    struct Case {
      let name: String.SubSequence
      let passed: Bool
      let duration: String.SubSequence
      var problems: [DiagnosticsParser.CustomDiagnostic]
    }
  }

  fileprivate static let highlighter = SyntaxHighlighter(format: TerminalOutputFormat())

  public func parse(_ output: String, _ terminal: InteractiveWriter) {
    let lines = output.split(separator: "\n")

    var suites = [Suite]()
    var unmappedProblems = [
      (
        suite: String.SubSequence,
        testCase: String.SubSequence,
        problem: DiagnosticsParser.CustomDiagnostic
      )
    ]()

    for line in lines {
      if let suite = line.match(of: Regex.suiteStarted, labelled: .suite) {
        suites.append(.init(name: suite, cases: []))
      } else if let testCase = line.match(of: Regex.caseFinished, labelled: .testCase),
        let suite = line.match(of: Regex.caseFinished, labelled: .suite),
        let suiteIdx = suites.firstIndex(where: { $0.name == suite }),
        let status = line.match(of: Regex.caseFinished, labelled: .status),
        let duration = line.match(of: Regex.caseFinished, labelled: .duration)
      {
        suites[suiteIdx].cases.append(
          .init(name: testCase, passed: status == "passed", duration: duration, problems: [])
        )
      } else if let problem = line.matches(regex: Regex.problem),
        let path = line.match(of: Regex.problem, labelled: .path),
        let lineNum = line.match(of: Regex.problem, labelled: .line),
        let status = line.match(of: Regex.problem, labelled: .status),
        let suite = line.match(of: Regex.problem, labelled: .suite),
        let testCase = line.match(of: Regex.problem, labelled: .testCase)
      {
        let diag = DiagnosticsParser.CustomDiagnostic(
          kind: DiagnosticsParser.CustomDiagnostic.Kind(rawValue: String(status)) ?? .note,
          file: String(path),
          line: lineNum,
          char: "0",
          code: "",
          message: String(problem)
        )
        if let suiteIdx = suites.firstIndex(where: { $0.name == suite }),
          let caseIdx = suites[suiteIdx].cases.firstIndex(where: { $0.name == testCase })
        {
          suites[suiteIdx].cases[caseIdx].problems.append(diag)
        } else {
          unmappedProblems.append((suite, testCase, diag))
        }
      }
    }
    for problem in unmappedProblems {
      if let suiteIdx = suites.firstIndex(where: { $0.name == problem.suite }),
        let caseIdx = suites[suiteIdx].cases.firstIndex(where: { $0.name == problem.testCase })
      {
        suites[suiteIdx].cases[caseIdx].problems.append(problem.problem)
      }
    }

    flushSuites(suites, terminal)
    terminal.write("\n")
    flushSummary(of: suites, terminal)
  }

  func flushSuites(_ suites: [Suite], _ terminal: InteractiveWriter) {
    let suitesWithCases = suites.filter { $0.cases.count > 0 }

    // Keep track of files we already opened and store their contents
    struct FileBuf: Hashable {
      let path: String
      let contents: String
    }
    var fileBufs = Set<FileBuf>()

    for suite in suitesWithCases {
      // bold, white fg, green/red bg
      terminal
        .write(
          """
          \n\(" \(suite.passed ? "PASSED" : "FAILED") ",
              color: "[1m", "[97m", suite.passed ? "[42m" : "[101m"
          )
          """
        )
      terminal.write(" \(suite.name)\n")
      for testCase in suite.cases {
        if testCase.passed {
          terminal.write("  \("✓", color: "[92m") ")  // green
        } else {
          terminal.write("  \("✕", color: "[91m") ")  // red
        }
        terminal
          .write(
            "\(testCase.name) \("(\(Int(Double(testCase.duration)! * 1000))ms)", color: "[90m")\n"
          )  // gray
        for problem in testCase.problems {
          terminal.write("\n    \(problem.file, color: "[90m"):\(problem.line)\n")
          terminal.write("    \(problem.message)\n\n")
          // Format XCTAssert functions
          for assertion in Regex.Assertion.allCases {
            if let (expected, received) = problem.message.match(
              of: Regex.xctAssert(assertion),
              labelled: .expected, .received
            ) {
              terminal.write("    Expected: \("\(assertion.symbol)\(expected)", color: "[92m")\n")
              terminal.write("    Received: \(received, color: "[91m")\n")
            }
          }
          // Get the line of code from the file and output it for context.
          if let lineNum = Int(problem.line),
            lineNum > 0
          {
            var fileContents: String?
            if let fileBuf = fileBufs.first(where: { $0.path == problem.file })?.contents {
              fileContents = fileBuf
            } else if let fileBuf = try? String(
              contentsOf: URL(fileURLWithPath: problem.file),
              encoding: .utf8
            ) {
              fileContents = fileBuf
              fileBufs.insert(.init(path: problem.file, contents: fileBuf))
            }
            if let fileContents = fileContents {
              let fileLines = fileContents.components(separatedBy: .newlines)
              guard fileLines.count >= lineNum else { break }
              let highlightedCode = Self.highlighter.highlight(String(fileLines[lineNum - 1]))
              terminal.write("    \("\(problem.line) | ", color: "[36m")\(highlightedCode)\n")
            }
          }
        }
      }
    }
  }

  func flushSummary(of suites: [Suite], _ terminal: InteractiveWriter) {
    let suitesWithCases = suites.filter { $0.cases.count > 0 }

    terminal.write("Test Suites: ")
    let suitesPassed = suitesWithCases.filter(\.passed).count
    if suitesPassed > 0 {
      terminal.write("\("\(suitesPassed) passed", color: "[32m"), ")
    }
    if suitesWithCases.count - suitesPassed > 0 {
      terminal.write("\("\(suitesWithCases.count - suitesPassed) failed", color: "[31m"), ")
    }
    terminal.write("\(suitesWithCases.count) total\n")

    terminal.write("Tests:       ")
    let allTests = suitesWithCases.map(\.cases).reduce([], +)
    let testsPassed = allTests.filter(\.passed).count
    if testsPassed > 0 {
      terminal.write("\("\(testsPassed) passed", color: "[32m"), ")
    }
    if allTests.count - testsPassed > 0 {
      terminal.write("\("\(allTests.count - testsPassed) failed", color: "[31m"), ")
    }
    terminal.write("\(allTests.count) total\n")

    let totalDuration = allTests.compactMap { Double($0.duration) }.reduce(0, +)
    terminal.write("Time:        ")
    terminal.write("\(String(format: "%.2f", totalDuration))s\n")

    if suites.contains(where: { $0.name == "All tests" }) {
      terminal.write("\("Ran all test suites.", color: "[90m")\n")  // gray
    }
  }
}
