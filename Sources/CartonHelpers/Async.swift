// Copyright 2021 Carton contributors
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

import ArgumentParser

extension Sequence {
  public func asyncMap<T>(
    _ transform: (Element) async throws -> T
  ) async rethrows -> [T] {
    var values = [T]()

    for element in self {
      try await values.append(transform(element))
    }

    return values
  }
}

/// A type that can be executed as part of a nested tree of commands.
#if swift(<5.9)
public protocol AsyncParsableCommand: ParsableCommand {
  mutating func run() async throws
}
#else
extension AsyncParsableCommand {
  public mutating func run() throws {
    throw CleanExit.helpRequest(self)
  }
}
#endif

public protocol AsyncMain {
  associatedtype Command: ParsableCommand
}

extension AsyncMain {
  public static func main() async {
    do {
      var command = try Command.parseAsRoot()
      if var command = command as? AsyncParsableCommand {
        try await command.run()
      } else {
        try command.run()
      }
    } catch {
      Command.exit(withError: error)
    }
  }
}
