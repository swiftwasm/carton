/*
 This source file is part of the Swift.org open source project
 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import TSCBasic

/// This class is used to write on the underlying stream.
///
/// If underlying stream is a not tty, the string will be written in without any
/// formatting.
public final class InteractiveWriter {
  /// The standard error writer.
  public static let stderr = InteractiveWriter(stream: stderrStream)

  /// The standard output writer.
  public static let stdout = InteractiveWriter(stream: stdoutStream)

  /// The terminal controller, if present.
  private let term: TerminalController?

  /// The output byte stream reference.
  private let stream: OutputByteStream

  /// Create an instance with the given stream.
  public init(stream: OutputByteStream) {
    term = TerminalController(stream: stream)
    self.stream = stream
  }

  /// Write the string to the contained terminal or stream.
  public func write(
    _ string: String,
    inColor color: TerminalController.Color = .noColor,
    bold: Bool = false
  ) {
    if let term = term {
      term.write(string, inColor: color, bold: bold)
    } else {
      stream <<< string
      stream.flush()
    }
  }

  public func clearLine() {
    if let term = term {
      term.clearLine()
    } else {
      stream <<< "\n"
      stream.flush()
    }
  }
  
  public func saveCursor() {
    term?.write("\u{001B}[s")
  }
  
  public func revertCursorAndClear() {
    term?.write("\u{001B}[u\u{001B}[2J\u{001B}H")
  }
}
