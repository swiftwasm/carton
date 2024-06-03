import Dispatch

extension ProcessResult {
  public mutating func setOutput(_ value: Result<[UInt8], any Swift.Error>) {
    self = ProcessResult(
      arguments: arguments,
      environmentBlock: environmentBlock,
      exitStatus: exitStatus,
      output: value,
      stderrOutput: stderrOutput
    )
  }

  @discardableResult
  public func checkNonZeroExit() throws -> String {
    guard exitStatus == .terminated(code: 0) else {
        throw ProcessResult.Error.nonZeroExit(self)
    }
    return try utf8Output()
  }
}

@discardableResult
private func osSignal(
  _ sig: Int32,
  _ fn: (@convention(c) (Int32) -> Void)?
) -> (@convention(c) (Int32) -> Void)? {
  signal(sig, fn)
}

extension Process {
  public func setSignalForwarding(_ signalNo: Int32) {
    osSignal(signalNo, SIG_IGN)
    let signalSource = DispatchSource.makeSignalSource(signal: signalNo)
    signalSource.setEventHandler {
      signalSource.cancel()
      self.signal(signalNo)
    }
    signalSource.resume()
  }

  public func forwardTerminationSignals() {
    setSignalForwarding(SIGINT)
    setSignalForwarding(SIGTERM)
  }
}
