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

import TSCBasic

private extension String {
  static var home = "\u{001B}[H"
  static var clearScreen = "\u{001B}[2J\u{001B}[H\u{001B}[3J"
  static var clear = "\u{001B}[J"
}

public extension InteractiveWriter {
  func logLookup<T>(_ description: String, _ target: T, newline: Bool = false)
    where T: CustomStringConvertible
  {
    write(description)
    write("\(target)\n", inColor: .cyan, bold: true)
    if newline {
      write("\n")
    }
  }

  func clearWindow() {
    write(.clearScreen)
  }

  func homeAndClear() {
    write(.home)
    write(.clear)
  }
}
