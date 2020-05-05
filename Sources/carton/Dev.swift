import ArgumentParser

struct Dev: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Watch the current directory, host the app, rebuild on change."
  )

  func run() throws {
    try Server.run()
  }
}
