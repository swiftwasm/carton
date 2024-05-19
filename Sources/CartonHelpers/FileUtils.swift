import Foundation

public enum FileUtils {
  static var errnoString: String {
    String(cString: strerror(errno))
  }

  public static var temporaryDirectory: URL {
    URL(fileURLWithPath: NSTemporaryDirectory())
  }

  public static func makeTemporaryFile(prefix: String, in directory: URL? = nil) throws -> URL {
    let directory = directory ?? temporaryDirectory
    var template = directory.appendingPathComponent("\(prefix)XXXXXX").path
    let result = try template.withUTF8 { template in
      let copy = UnsafeMutableBufferPointer<CChar>.allocate(capacity: template.count + 1)
      defer { copy.deallocate() }
      template.copyBytes(to: copy)
      copy[template.count] = 0
      guard mkstemp(copy.baseAddress!) != -1 else {
        let error = errnoString
        throw CartonHelpersError("Failed to make a temporary file at \(template): \(error)")
      }
      return String(cString: copy.baseAddress!)
    }
    return URL(fileURLWithPath: result)
  }
}
