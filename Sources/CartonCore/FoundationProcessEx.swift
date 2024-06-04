import Foundation

extension Foundation.Process {
  // Monitor termination/interrruption signals to forward them to child process
  public func setSignalForwarding(_ signalNo: Int32) {
    signal(signalNo, SIG_IGN)
    let signalSource = DispatchSource.makeSignalSource(signal: signalNo)
    signalSource.setEventHandler { [self] in
      signalSource.cancel()
      kill(processIdentifier, signalNo)
    }
    signalSource.resume()
  }

  public func forwardTerminationSignals() {
    setSignalForwarding(SIGINT)
    setSignalForwarding(SIGTERM)
  }

  public var commandLine: String {
    get throws {
      guard let executableURL else {
        throw CartonCoreError("executableURL is none")
      }

      let commandLineArgs: [String] = [
        executableURL.path
      ] + (arguments ?? [])

      let q = "\""
      let commandLine: String = commandLineArgs
        .map { "\(q)\($0)\(q)" }
        .joined(separator: " ")

      return commandLine
    }
  }

  public func checkRun(
    printsLoadingMessage: Bool,
    didExit: (() -> Void)? = nil,
    forwardExit: Bool = false
  ) throws {
    if printsLoadingMessage {
      fputs("Running \(try commandLine)\n", stderr)
      fflush(stderr)
    }

    try run()
    forwardTerminationSignals()
    waitUntilExit()

    didExit?()

    if forwardExit {
      self.forwardExit()
    }

    try checkNonZeroExit()
  }

  public func forwardExit() {
    exit(terminationStatus)
  }

  public func checkNonZeroExit() throws {
    if terminationStatus != 0 {
      throw CartonCoreError(
        "Process failed with status \(terminationStatus).\n" +
        "Command line: \(try commandLine)"
      )
    }
  }

  public static func checkRun(
    _ executableURL: URL,
    arguments: [String],
    printsLoadingMessage: Bool = true,
    didExit: (() -> Void)? = nil,
    forwardExit: Bool = false
  ) throws {
    let process = Foundation.Process()
    process.executableURL = executableURL
    process.arguments = arguments
    try process.checkRun(
      printsLoadingMessage: printsLoadingMessage,
      didExit: didExit,
      forwardExit: forwardExit
    )
  }
}
