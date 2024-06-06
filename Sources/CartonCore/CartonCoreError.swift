public struct CartonCoreError: Error & CustomStringConvertible {
  public init(_ description: String) {
    self.description = description
  }
  public  var description: String
}
