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
