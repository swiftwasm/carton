import ArgumentParser

struct Prod: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Produce a production app bundle ready for deployment."
  )
}
