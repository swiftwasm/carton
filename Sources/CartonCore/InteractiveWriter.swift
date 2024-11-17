/*
 This source file is part of the Swift.org open source project
 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Foundation

#if os(Android) || canImport(Musl)
  public typealias FILEPointer = OpaquePointer
#else
  public typealias FILEPointer = UnsafeMutablePointer<FILE>
#endif

/// Implements file output stream for local file system.
public final class _LocalFileOutputByteStream {

  /// The pointer to the file.
  let filePointer: FILEPointer

  public static let stdout = _LocalFileOutputByteStream(filePointer: Foundation.stdout)
  public static let stderr = _LocalFileOutputByteStream(filePointer: Foundation.stderr)

  /// Instantiate using the file pointer.
  public init(filePointer: FILEPointer) {
    self.filePointer = filePointer
  }

  @discardableResult
  public func send(_ value: CustomStringConvertible) -> _LocalFileOutputByteStream {
    var contents = [UInt8](value.description.utf8)
    while true {
      let n = fwrite(&contents, 1, contents.count, filePointer)
      if n < 0 {
        if errno == EINTR { continue }
      } else if n != contents.count {
        continue
      }
      break
    }
    return self
  }

  public func flush() {
    fflush(filePointer)
  }
}

/// This class is used to write on the underlying stream.
///
/// If underlying stream is a not tty, the string will be written in without any
/// formatting.
public final class InteractiveWriter {
  /// The standard error writer.
  public static let stderr = InteractiveWriter(stream: .stderr)

  /// The standard output writer.
  public static let stdout = InteractiveWriter(stream: .stdout)

  /// The terminal controller, if present.
  private let term: TerminalController?

  /// The output byte stream reference.
  private let stream: _LocalFileOutputByteStream

  /// Create an instance with the given stream.
  public init(stream: _LocalFileOutputByteStream) {
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
      stream.send(string)
      stream.flush()
    }
  }

  public func clearLine() {
    if let term = term {
      term.clearLine()
    } else {
      stream.send("\n")
      stream.flush()
    }
  }

  public func saveCursor() {
    term?.write("\u{001B}[s")
  }

  public func revertCursorAndClear() {
    term?.write("\u{001B}[u\u{001B}[2J\u{001B}H")
  }

  public func logLookup<T>(_ description: String, _ target: T, newline: Bool = false)
  where T: CustomStringConvertible {
    write(description)
    write("\(target)\n", inColor: .cyan, bold: true)
    if newline {
      write("\n")
    }
  }
}
