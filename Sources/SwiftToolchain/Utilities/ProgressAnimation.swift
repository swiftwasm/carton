/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import CartonCore

/// A protocol to operate on terminal based progress animations.
public protocol ProgressAnimationProtocol {
  /// Update the animation with a new step.
  /// - Parameters:
  ///   - step: The index of the operation's current step.
  ///   - total: The total number of steps before the operation is complete.
  ///   - text: The description of the current step.
  func update(step: Int, total: Int, text: String)

  /// Complete the animation.
  /// - Parameters:
  ///   - success: Defines if the operation the animation represents was successful.
  func complete(success: Bool)

  /// Clear the animation.
  func clear()
}

/// A single line percent-based progress animation.
public final class SingleLinePercentProgressAnimation: ProgressAnimationProtocol {
  private let stream: _LocalFileOutputByteStream
  private let header: String?
  private var displayedPercentages: Set<Int> = []
  private var hasDisplayedHeader = false

  init(stream: _LocalFileOutputByteStream, header: String?) {
    self.stream = stream
    self.header = header
  }

  public func update(step: Int, total: Int, text: String) {
    if let header = header, !hasDisplayedHeader {
      stream.send(header)
      stream.send("\n")
      stream.flush()
      hasDisplayedHeader = true
    }

    let percentage = step * 100 / total
    let roundedPercentage = Int(Double(percentage / 10).rounded(.down)) * 10
    if percentage != 100, !displayedPercentages.contains(roundedPercentage) {
      stream.send(String(roundedPercentage)).send(".. ")
      displayedPercentages.insert(roundedPercentage)
    }

    stream.flush()
  }

  public func complete(success: Bool) {
    if success {
      stream.send("OK")
      stream.flush()
    }
  }

  public func clear() {
  }
}

/// A multi-line percent-based progress animation.
public final class MultiLinePercentProgressAnimation: ProgressAnimationProtocol {
  private struct Info: Equatable {
    let percentage: Int
    let text: String
  }

  private let stream: _LocalFileOutputByteStream
  private let header: String
  private var hasDisplayedHeader = false
  private var lastDisplayedText: String? = nil

  public init(stream: _LocalFileOutputByteStream, header: String) {
    self.stream = stream
    self.header = header
  }

  public func update(step: Int, total: Int, text: String) {
    assert(step <= total)

    if !hasDisplayedHeader, !header.isEmpty {
      stream.send(header)
      stream.send("\n")
      stream.flush()
      hasDisplayedHeader = true
    }

    let percentage = step * 100 / total
    stream.send("\(percentage)%: ").send(text)
    stream.send("\n")
    stream.flush()
    lastDisplayedText = text
  }

  public func complete(success: Bool) {
  }

  public func clear() {
  }
}

/// A redrawing lit-like progress animation.
public final class RedrawingLitProgressAnimation: ProgressAnimationProtocol {
  private let terminal: TerminalController
  private let header: String
  private var hasDisplayedHeader = false

  init(terminal: TerminalController, header: String) {
    self.terminal = terminal
    self.header = header
  }

  /// Creates repeating string for count times.
  /// If count is negative, returns empty string.
  private func repeating(string: String, count: Int) -> String {
    return String(repeating: string, count: max(count, 0))
  }

  public func update(step: Int, total: Int, text: String) {
    assert(step <= total)

    let width = terminal.width
    if !hasDisplayedHeader {
      let spaceCount = width / 2 - header.utf8.count / 2
      terminal.write(repeating(string: " ", count: spaceCount))
      terminal.write(header, inColor: .cyan, bold: true)
      terminal.endLine()
      hasDisplayedHeader = true
    } else {
      terminal.moveCursor(up: 1)
    }

    terminal.clearLine()
    let percentage = step * 100 / total
    let paddedPercentage = percentage < 10 ? " \(percentage)" : "\(percentage)"
    let prefix = "\(paddedPercentage)% " + terminal.wrap("[", inColor: .green, bold: true)
    terminal.write(prefix)

    let barWidth = width - prefix.utf8.count
    let n = Int(Double(barWidth) * Double(percentage) / 100.0)

    terminal.write(
      repeating(string: "=", count: n) + repeating(string: "-", count: barWidth - n),
      inColor: .green)
    terminal.write("]", inColor: .green, bold: true)
    terminal.endLine()

    terminal.clearLine()
    if text.utf8.count > width {
      let prefix = "…"
      terminal.write(prefix)
      terminal.write(String(text.suffix(width - prefix.utf8.count)))
    } else {
      terminal.write(text)
    }
  }

  public func complete(success: Bool) {
    terminal.endLine()
    terminal.endLine()
  }

  public func clear() {
    terminal.clearLine()
    terminal.moveCursor(up: 1)
    terminal.clearLine()
  }
}

/// A percent-based progress animation that adapts to the provided output stream.
public final class PercentProgressAnimation: DynamicProgressAnimation {
  public init(stream: _LocalFileOutputByteStream, header: String) {
    super.init(
      stream: stream,
      ttyTerminalAnimationFactory: { RedrawingLitProgressAnimation(terminal: $0, header: header) },
      dumbTerminalAnimationFactory: {
        SingleLinePercentProgressAnimation(stream: stream, header: header)
      },
      defaultAnimationFactory: { MultiLinePercentProgressAnimation(stream: stream, header: header) }
    )
  }
}

/// A progress animation that adapts to the provided output stream.
public class DynamicProgressAnimation: ProgressAnimationProtocol {
  private let animation: ProgressAnimationProtocol

  public init(
    stream: _LocalFileOutputByteStream,
    ttyTerminalAnimationFactory: (TerminalController) -> ProgressAnimationProtocol,
    dumbTerminalAnimationFactory: () -> ProgressAnimationProtocol,
    defaultAnimationFactory: () -> ProgressAnimationProtocol
  ) {
    if let terminal = TerminalController(stream: stream) {
      animation = ttyTerminalAnimationFactory(terminal)
    } else if TerminalController.terminalType(stream) == .dumb
    {
      animation = dumbTerminalAnimationFactory()
    } else {
      animation = defaultAnimationFactory()
    }
  }

  public func update(step: Int, total: Int, text: String) {
    animation.update(step: step, total: total, text: text)
  }

  public func complete(success: Bool) {
    animation.complete(success: success)
  }

  public func clear() {
    animation.clear()
  }
}
