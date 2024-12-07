import Foundation

extension Foundation.Process {
  // Monitor termination/interrruption signals to forward them to child process
  public func setSignalForwarding(_ signalNo: Int32) -> DispatchSourceSignal {
    signal(signalNo, SIG_IGN)
    let signalSource = DispatchSource.makeSignalSource(signal: signalNo)
    signalSource.setEventHandler { [self] in
      signalSource.cancel()
      kill(processIdentifier, signalNo)
    }
    signalSource.resume()
    return signalSource
  }

  public func forwardTerminationSignals() -> [DispatchSourceSignal] {
    return [
      setSignalForwarding(SIGINT),
      setSignalForwarding(SIGTERM),
    ]
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
    forwardExit: Bool = false
  ) throws {
    if printsLoadingMessage {
      print("Running \(try commandLine)")
    }

    let signalSources = forwardTerminationSignals()
    defer {
      for signalSource in signalSources {
        signalSource.cancel()
      }
    }

    try run()
    waitUntilExit()

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
    environment: [String: String]? = nil,
    printsLoadingMessage: Bool = true,
    forwardExit: Bool = false
  ) throws {
    let process = Foundation.Process()
    process.executableURL = executableURL
    process.arguments = arguments
    if let environment {
      process.environment = environment
    }
    try process.checkRun(
      printsLoadingMessage: printsLoadingMessage,
      forwardExit: forwardExit
    )
  }

  public static func which(_ executable: String) throws -> URL {
    let pathSeparator: Character
#if os(Windows)
    pathSeparator = ";"
#else
    pathSeparator = ":"
#endif
    let paths = ProcessInfo.processInfo.environment["PATH"]!.split(separator: pathSeparator)
    for path in paths {
      let url = URL(fileURLWithPath: String(path)).appendingPathComponent(executable)
      if FileManager.default.isExecutableFile(atPath: url.path) {
        return url
      }
    }
    throw CartonCoreError("Executable \(executable) not found in PATH")
  }
}
