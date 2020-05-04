import ArgumentParser

struct Carton: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "📦 Watcher, bundler, and test runner for your SwiftWasm apps.",
    subcommands: [Dev.self, Test.self, Prod.self],
    defaultSubcommand: Dev.self
  )
}
