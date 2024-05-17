/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2019 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public struct ProcessEnvironmentKey: CustomStringConvertible {
  public let value: String
  public init(_ value: String) {
    self.value = value
  }

  public var description: String { value }
}

extension ProcessEnvironmentKey: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.value)
  }
}

extension ProcessEnvironmentKey: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.value = try container.decode(String.self)
  }
}

extension ProcessEnvironmentKey: Equatable {
  public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
    #if os(Windows)
      // TODO: is this any faster than just doing a lowercased conversion and compare?
      return lhs.value.caseInsensitiveCompare(rhs.value) == .orderedSame
    #else
      return lhs.value == rhs.value
    #endif
  }
}

extension ProcessEnvironmentKey: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(value)
  }
}

extension ProcessEnvironmentKey: Hashable {
  public func hash(into hasher: inout Hasher) {
    #if os(Windows)
      self.value.lowercased().hash(into: &hasher)
    #else
      self.value.hash(into: &hasher)
    #endif
  }
}

extension ProcessEnvironmentKey: Sendable {}

public typealias ProcessEnvironmentBlock = [ProcessEnvironmentKey: String]
extension ProcessEnvironmentBlock {
  public init(_ dictionary: [String: String]) {
    self.init(uniqueKeysWithValues: dictionary.map { (ProcessEnvironmentKey($0.key), $0.value) })
  }
}

extension ProcessEnvironmentBlock: Sendable {}

/// Provides functionality related a process's environment.
public enum ProcessEnv {

  @available(*, deprecated, message: "Use `block` instead")
  public static var vars: [String: String] {
    [String: String](uniqueKeysWithValues: _vars.map { ($0.key.value, $0.value) })
  }

  /// Returns a dictionary containing the current environment.
  public static var block: ProcessEnvironmentBlock { _vars }

  private static var _vars = ProcessEnvironmentBlock(
    uniqueKeysWithValues: ProcessInfo.processInfo.environment.map {
      (ProcessEnvironmentBlock.Key($0.key), $0.value)
    }
  )

  /// Invalidate the cached env.
  public static func invalidateEnv() {
    _vars = ProcessEnvironmentBlock(
      uniqueKeysWithValues: ProcessInfo.processInfo.environment.map {
        (ProcessEnvironmentKey($0.key), $0.value)
      }
    )
  }

  /// `PATH` variable in the process's environment (`Path` under Windows).
  public static var path: String? {
    return block["PATH"]
  }

  /// The current working directory of the process.
  public static var cwd: AbsolutePath? {
    return localFileSystem.currentWorkingDirectory
  }
}
