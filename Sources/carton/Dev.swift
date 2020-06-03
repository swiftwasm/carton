import ArgumentParser
import Foundation
import ShellOut

struct ProductType: Codable {
  let executable: String?
  let library: [String]
}

/**
 Simple Product structure from package dump
 */
struct Product: Codable {
  let name: String
  let type: ProductType
}

/**
 Simple Package structure from package dump
 */
struct Package: Codable {
  let name: String
  let products: [Product]
  let targets: [Target]
}

enum TargetType: String, Codable {
  case regular
  case test
}

struct Target: Codable {
  let name: String
  let type: TargetType
}

struct Dev: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  func run() throws {
    let output = try shellOut(to: "swift", arguments: ["package", "dump-package"])
    guard let data = output.data(using: .utf8)
    else { fatalError("failed to decode `swift package dump-package` output") }
    try print(JSONDecoder().decode(Package.self, from: data))
    try Server.run()
  }
}
