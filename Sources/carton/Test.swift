import ArgumentParser

struct Test: ParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Run the tests in a WASI environment.")
}
