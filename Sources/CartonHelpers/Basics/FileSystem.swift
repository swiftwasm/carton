/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Dispatch
import Foundation

public struct FileSystemError: Error, Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    /// Access to the path is denied.
    ///
    /// This is used when an operation cannot be completed because a component of
    /// the path cannot be accessed.
    ///
    /// Used in situations that correspond to the POSIX EACCES error code.
    case invalidAccess

    /// IO Error encoding
    ///
    /// This is used when an operation cannot be completed due to an otherwise
    /// unspecified IO error.
    case ioError(code: Int32)

    /// Is a directory
    ///
    /// This is used when an operation cannot be completed because a component
    /// of the path which was expected to be a file was not.
    ///
    /// Used in situations that correspond to the POSIX EISDIR error code.
    case isDirectory

    /// No such path exists.
    ///
    /// This is used when a path specified does not exist, but it was expected
    /// to.
    ///
    /// Used in situations that correspond to the POSIX ENOENT error code.
    case noEntry

    /// Not a directory
    ///
    /// This is used when an operation cannot be completed because a component
    /// of the path which was expected to be a directory was not.
    ///
    /// Used in situations that correspond to the POSIX ENOTDIR error code.
    case notDirectory

    /// Unsupported operation
    ///
    /// This is used when an operation is not supported by the concrete file
    /// system implementation.
    case unsupported

    /// An unspecific operating system error at a given path.
    case unknownOSError

    /// File or folder already exists at destination.
    ///
    /// This is thrown when copying or moving a file or directory but the destination
    /// path already contains a file or folder.
    case alreadyExistsAtDestination

    /// If an unspecified error occurs when trying to change directories.
    case couldNotChangeDirectory

    /// If a mismatch is detected in byte count when writing to a file.
    case mismatchedByteCount(expected: Int, actual: Int)
  }

  /// The kind of the error being raised.
  public let kind: Kind

  /// The absolute path to the file associated with the error, if available.
  public let path: AbsolutePath?

  public init(_ kind: Kind, _ path: AbsolutePath? = nil) {
    self.kind = kind
    self.path = path
  }
}

extension FileSystemError: CustomNSError {
  public var errorUserInfo: [String: Any] {
    return [NSLocalizedDescriptionKey: "\(self)"]
  }
}

extension FileSystemError {
  public init(errno: Int32, _ path: AbsolutePath) {
    switch errno {
    case EACCES:
      self.init(.invalidAccess, path)
    case EISDIR:
      self.init(.isDirectory, path)
    case ENOENT:
      self.init(.noEntry, path)
    case ENOTDIR:
      self.init(.notDirectory, path)
    case EEXIST:
      self.init(.alreadyExistsAtDestination, path)
    default:
      self.init(.ioError(code: errno), path)
    }
  }
}

/// Defines the file modes.
public enum FileMode: Sendable {

  public enum Option: Int, Sendable {
    case recursive
    case onlyFiles
  }

  case userUnWritable
  case userWritable
  case executable

  public func setMode(_ originalMode: Int16) -> Int16 {
    switch self {
    case .userUnWritable:
      // r-x rwx rwx
      return originalMode & 0o577
    case .userWritable:
      // -w- --- ---
      return originalMode | 0o200
    case .executable:
      // --x --x --x
      return originalMode | 0o111
    }
  }
}

/// Extended file system attributes that can applied to a given file path. See also ``FileSystem/hasAttribute(_:_:)``.
public enum FileSystemAttribute: RawRepresentable {
  #if canImport(Darwin)
    case quarantine
  #endif

  public init?(rawValue: String) {
    switch rawValue {
    #if canImport(Darwin)
      case "com.apple.quarantine":
        self = .quarantine
    #endif
    default:
      return nil
    }
  }

  public var rawValue: String {
    switch self {
    #if canImport(Darwin)
      case .quarantine:
        return "com.apple.quarantine"
    #endif
    }
  }
}

// FIXME: Design an asynchronous story?
//
/// Abstracted access to file system operations.
///
/// This protocol is used to allow most of the codebase to interact with a
/// natural filesystem interface, while still allowing clients to transparently
/// substitute a virtual file system or redirect file system operations.
///
/// - Note: All of these APIs are synchronous and can block.
public protocol FileSystem: Sendable {
  /// Check whether the given path exists and is accessible.
  @_disfavoredOverload
  func exists(_ path: AbsolutePath, followSymlink: Bool) -> Bool

  /// Check whether the given path is accessible and a directory.
  func isDirectory(_ path: AbsolutePath) -> Bool

  /// Check whether the given path is accessible and a file.
  func isFile(_ path: AbsolutePath) -> Bool

  /// Check whether the given path is an accessible and executable file.
  func isExecutableFile(_ path: AbsolutePath) -> Bool

  /// Check whether the given path is accessible and is a symbolic link.
  func isSymlink(_ path: AbsolutePath) -> Bool

  /// Check whether the given path is accessible and readable.
  func isReadable(_ path: AbsolutePath) -> Bool

  /// Check whether the given path is accessible and writable.
  func isWritable(_ path: AbsolutePath) -> Bool

  /// Returns any known item replacement directories for a given path. These may be used by platform-specific
  /// libraries to handle atomic file system operations, such as deletion.
  func itemReplacementDirectories(for path: AbsolutePath) throws -> [AbsolutePath]

  @available(*, deprecated, message: "use `hasAttribute(_:_:)` instead")
  func hasQuarantineAttribute(_ path: AbsolutePath) -> Bool

  /// Returns `true` if a given path has an attribute with a given name applied when file system supports this
  /// attribute. Returns `false` if such attribute is not applied or it isn't supported.
  func hasAttribute(_ name: FileSystemAttribute, _ path: AbsolutePath) -> Bool

  // FIXME: Actual file system interfaces will allow more efficient access to
  // more data than just the name here.
  //
  /// Get the contents of the given directory, in an undefined order.
  func getDirectoryContents(_ path: AbsolutePath) throws -> [String]

  /// Get the current working directory (similar to `getcwd(3)`), which can be
  /// different for different (virtualized) implementations of a FileSystem.
  /// The current working directory can be empty if e.g. the directory became
  /// unavailable while the current process was still working in it.
  /// This follows the POSIX `getcwd(3)` semantics.
  @_disfavoredOverload
  var currentWorkingDirectory: AbsolutePath? { get }

  /// Change the current working directory.
  /// - Parameters:
  ///   - path: The path to the directory to change the current working directory to.
  func changeCurrentWorkingDirectory(to path: AbsolutePath) throws

  /// Get the home directory of current user
  @_disfavoredOverload
  var homeDirectory: AbsolutePath { get throws }

  /// Get the caches directory of current user
  @_disfavoredOverload
  var cachesDirectory: AbsolutePath? { get }

  /// Get the temp directory
  @_disfavoredOverload
  var tempDirectory: AbsolutePath { get throws }

  /// Create the given directory.
  func createDirectory(_ path: AbsolutePath) throws

  /// Create the given directory.
  ///
  /// - recursive: If true, create missing parent directories if possible.
  func createDirectory(_ path: AbsolutePath, recursive: Bool) throws

  /// Creates a symbolic link of the source path at the target path
  /// - Parameters:
  ///   - path: The path at which to create the link.
  ///   - destination: The path to which the link points to.
  ///   - relative: If `relative` is true, the symlink contents will be a relative path, otherwise it will be absolute.
  func createSymbolicLink(
    _ path: AbsolutePath, pointingAt destination: AbsolutePath, relative: Bool) throws

  // FIXME: This is obviously not a very efficient or flexible API.
  //
  /// Get the contents of a file.
  ///
  /// - Returns: The file contents as bytes, or nil if missing.
  func readFileContents(_ path: AbsolutePath) throws -> ByteString

  // FIXME: This is obviously not a very efficient or flexible API.
  //
  /// Write the contents of a file.
  func writeFileContents(_ path: AbsolutePath, bytes: ByteString) throws

  // FIXME: This is obviously not a very efficient or flexible API.
  //
  /// Write the contents of a file.
  func writeFileContents(_ path: AbsolutePath, bytes: ByteString, atomically: Bool) throws

  /// Recursively deletes the file system entity at `path`.
  ///
  /// If there is no file system entity at `path`, this function does nothing (in particular, this is not considered
  /// to be an error).
  func removeFileTree(_ path: AbsolutePath) throws

  /// Change file mode.
  func chmod(_ mode: FileMode, path: AbsolutePath, options: Set<FileMode.Option>) throws

  /// Returns the file info of the given path.
  ///
  /// The method throws if the underlying stat call fails.
  func getFileInfo(_ path: AbsolutePath) throws -> FileInfo

  /// Copy a file or directory.
  func copy(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws

  /// Move a file or directory.
  func move(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws
}

/// Convenience implementations (default arguments aren't permitted in protocol
/// methods).
extension FileSystem {
  /// exists override with default value.
  @_disfavoredOverload
  public func exists(_ path: AbsolutePath) -> Bool {
    return exists(path, followSymlink: true)
  }

  /// Default implementation of createDirectory(_:)
  public func createDirectory(_ path: AbsolutePath) throws {
    try createDirectory(path, recursive: false)
  }

  // Change file mode.
  public func chmod(_ mode: FileMode, path: AbsolutePath) throws {
    try chmod(mode, path: path, options: [])
  }

  // Unless the file system type provides an override for this method, throw
  // if `atomically` is `true`, otherwise fall back to whatever implementation already exists.
  @_disfavoredOverload
  public func writeFileContents(_ path: AbsolutePath, bytes: ByteString, atomically: Bool) throws {
    guard !atomically else {
      throw FileSystemError(.unsupported, path)
    }
    try writeFileContents(path, bytes: bytes)
  }

  /// Write to a file from a stream producer.
  @_disfavoredOverload
  public func writeFileContents(_ path: AbsolutePath, body: (WritableByteStream) -> Void) throws {
    let contents = BufferedOutputByteStream()
    body(contents)
    try createDirectory(path.parentDirectory, recursive: true)
    try writeFileContents(path, bytes: contents.bytes)
  }

  public func getFileInfo(_ path: AbsolutePath) throws -> FileInfo {
    throw FileSystemError(.unsupported, path)
  }

  public func hasQuarantineAttribute(_ path: AbsolutePath) -> Bool { false }

  public func hasAttribute(_ name: FileSystemAttribute, _ path: AbsolutePath) -> Bool { false }

  public func itemReplacementDirectories(for path: AbsolutePath) throws -> [AbsolutePath] { [] }
}

/// Concrete FileSystem implementation which communicates with the local file system.
private struct LocalFileSystem: FileSystem {
  func isExecutableFile(_ path: AbsolutePath) -> Bool {
    // Our semantics doesn't consider directories.
    return (self.isFile(path) || self.isSymlink(path))
      && FileManager.default.isExecutableFile(atPath: path.pathString)
  }

  func exists(_ path: AbsolutePath, followSymlink: Bool) -> Bool {
    if followSymlink {
      return FileManager.default.fileExists(atPath: path.pathString)
    }
    return (try? FileManager.default.attributesOfItem(atPath: path.pathString)) != nil
  }

  func isDirectory(_ path: AbsolutePath) -> Bool {
    var isDirectory: ObjCBool = false
    let exists: Bool = FileManager.default.fileExists(
      atPath: path.pathString, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
  }

  func isFile(_ path: AbsolutePath) -> Bool {
    guard let path = try? resolveSymlinks(path) else {
      return false
    }
    let attrs = try? FileManager.default.attributesOfItem(atPath: path.pathString)
    return attrs?[.type] as? FileAttributeType == .typeRegular
  }

  func isSymlink(_ path: AbsolutePath) -> Bool {
    let url = NSURL(fileURLWithPath: path.pathString)
    // We are intentionally using `NSURL.resourceValues(forKeys:)` here since it improves performance on Darwin platforms.
    let result = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
    return (result?[.isSymbolicLinkKey] as? Bool) == true
  }

  func isReadable(_ path: AbsolutePath) -> Bool {
    FileManager.default.isReadableFile(atPath: path.pathString)
  }

  func isWritable(_ path: AbsolutePath) -> Bool {
    FileManager.default.isWritableFile(atPath: path.pathString)
  }

  func getFileInfo(_ path: AbsolutePath) throws -> FileInfo {
    let attrs = try FileManager.default.attributesOfItem(atPath: path.pathString)
    return FileInfo(attrs)
  }

  func hasAttribute(_ name: FileSystemAttribute, _ path: AbsolutePath) -> Bool {
    #if canImport(Darwin)
      let bufLength = getxattr(path.pathString, name.rawValue, nil, 0, 0, 0)

      return bufLength > 0
    #else
      return false
    #endif
  }

  var currentWorkingDirectory: AbsolutePath? {
    let cwdStr = FileManager.default.currentDirectoryPath

    #if _runtime(_ObjC)
      // The ObjC runtime indicates that the underlying Foundation has ObjC
      // interoperability in which case the return type of
      // `fileSystemRepresentation` is different from the Swift implementation
      // of Foundation.
      return try? AbsolutePath(validating: cwdStr)
    #else
      let fsr: UnsafePointer<Int8> = cwdStr.fileSystemRepresentation
      defer { fsr.deallocate() }

      return try? AbsolutePath(String(cString: fsr))
    #endif
  }

  func changeCurrentWorkingDirectory(to path: AbsolutePath) throws {
    guard isDirectory(path) else {
      throw FileSystemError(.notDirectory, path)
    }

    guard FileManager.default.changeCurrentDirectoryPath(path.pathString) else {
      throw FileSystemError(.couldNotChangeDirectory, path)
    }
  }

  var homeDirectory: AbsolutePath {
    get throws {
      return try AbsolutePath(validating: NSHomeDirectory())
    }
  }

  var cachesDirectory: AbsolutePath? {
    return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first.flatMap {
      try? AbsolutePath(validating: $0.path)
    }
  }

  var tempDirectory: AbsolutePath {
    get throws {
      let override =
        ProcessEnv.block["TMPDIR"] ?? ProcessEnv.block["TEMP"] ?? ProcessEnv.block["TMP"]
      if let path = override.flatMap({ try? AbsolutePath(validating: $0) }) {
        return path
      }
      return try AbsolutePath(validating: NSTemporaryDirectory())
    }
  }

  func getDirectoryContents(_ path: AbsolutePath) throws -> [String] {
    #if canImport(Darwin)
      return try FileManager.default.contentsOfDirectory(atPath: path.pathString)
    #else
      do {
        return try FileManager.default.contentsOfDirectory(atPath: path.pathString)
      } catch let error as NSError {
        // Fixup error from corelibs-foundation.
        if error.code == CocoaError.fileReadNoSuchFile.rawValue,
          !error.userInfo.keys.contains(NSLocalizedDescriptionKey)
        {
          var userInfo = error.userInfo
          userInfo[NSLocalizedDescriptionKey] = "The folder “\(path.basename)” doesn’t exist."
          throw NSError(domain: error.domain, code: error.code, userInfo: userInfo)
        }
        throw error
      }
    #endif
  }

  func createDirectory(_ path: AbsolutePath, recursive: Bool) throws {
    // Don't fail if path is already a directory.
    if isDirectory(path) { return }

    try FileManager.default.createDirectory(
      atPath: path.pathString, withIntermediateDirectories: recursive, attributes: [:])
  }

  func createSymbolicLink(
    _ path: AbsolutePath, pointingAt destination: AbsolutePath, relative: Bool
  ) throws {
    let destString =
      relative ? destination.relative(to: path.parentDirectory).pathString : destination.pathString
    try FileManager.default.createSymbolicLink(
      atPath: path.pathString, withDestinationPath: destString)
  }

  func readFileContents(_ path: AbsolutePath) throws -> ByteString {
    // Open the file.
    guard let fp = fopen(path.pathString, "rb") else {
      throw FileSystemError(errno: errno, path)
    }
    defer { fclose(fp) }

    // Read the data one block at a time.
    let data = BufferedOutputByteStream()
    var tmpBuffer = [UInt8](repeating: 0, count: 1 << 12)
    while true {
      let n = fread(&tmpBuffer, 1, tmpBuffer.count, fp)
      if n < 0 {
        if errno == EINTR { continue }
        throw FileSystemError(.ioError(code: errno), path)
      }
      if n == 0 {
        let errno = ferror(fp)
        if errno != 0 {
          throw FileSystemError(.ioError(code: errno), path)
        }
        break
      }
      data.send(tmpBuffer[0..<n])
    }

    return data.bytes
  }

  func writeFileContents(_ path: AbsolutePath, bytes: ByteString) throws {
    // Open the file.
    guard let fp = fopen(path.pathString, "wb") else {
      throw FileSystemError(errno: errno, path)
    }
    defer { fclose(fp) }

    // Write the data in one chunk.
    var contents = bytes.contents
    while true {
      let n = fwrite(&contents, 1, contents.count, fp)
      if n < 0 {
        if errno == EINTR { continue }
        throw FileSystemError(.ioError(code: errno), path)
      }
      if n != contents.count {
        throw FileSystemError(.mismatchedByteCount(expected: contents.count, actual: n), path)
      }
      break
    }
  }

  func writeFileContents(_ path: AbsolutePath, bytes: ByteString, atomically: Bool) throws {
    // Perform non-atomic writes using the fast path.
    if !atomically {
      return try writeFileContents(path, bytes: bytes)
    }

    try bytes.withData {
      try $0.write(to: URL(fileURLWithPath: path.pathString), options: .atomic)
    }
  }

  func removeFileTree(_ path: AbsolutePath) throws {
    do {
      try FileManager.default.removeItem(atPath: path.pathString)
    } catch let error as NSError {
      // If we failed because the directory doesn't actually exist anymore, ignore the error.
      if !(error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError) {
        throw error
      }
    }
  }

  func chmod(_ mode: FileMode, path: AbsolutePath, options: Set<FileMode.Option>) throws {
    guard exists(path) else { return }
    func setMode(path: String) throws {
      let attrs = try FileManager.default.attributesOfItem(atPath: path)
      // Skip if only files should be changed.
      if options.contains(.onlyFiles) && attrs[.type] as? FileAttributeType != .typeRegular {
        return
      }

      // Compute the new mode for this file.
      let currentMode = attrs[.posixPermissions] as! Int16
      let newMode = mode.setMode(currentMode)
      guard newMode != currentMode else { return }
      try FileManager.default.setAttributes(
        [.posixPermissions: newMode],
        ofItemAtPath: path)
    }

    try setMode(path: path.pathString)
    guard isDirectory(path) else { return }

    guard
      let traverse = FileManager.default.enumerator(
        at: URL(fileURLWithPath: path.pathString),
        includingPropertiesForKeys: nil)
    else {
      throw FileSystemError(.noEntry, path)
    }

    if !options.contains(.recursive) {
      traverse.skipDescendants()
    }

    while let path = traverse.nextObject() {
      try setMode(path: (path as! URL).path)
    }
  }

  func copy(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws {
    guard exists(sourcePath) else { throw FileSystemError(.noEntry, sourcePath) }
    guard !exists(destinationPath)
    else { throw FileSystemError(.alreadyExistsAtDestination, destinationPath) }
    try FileManager.default.copyItem(at: sourcePath.asURL, to: destinationPath.asURL)
  }

  func move(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws {
    guard exists(sourcePath) else { throw FileSystemError(.noEntry, sourcePath) }
    guard !exists(destinationPath)
    else { throw FileSystemError(.alreadyExistsAtDestination, destinationPath) }
    try FileManager.default.moveItem(at: sourcePath.asURL, to: destinationPath.asURL)
  }

  func itemReplacementDirectories(for path: AbsolutePath) throws -> [AbsolutePath] {
    let result = try FileManager.default.url(
      for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: path.asURL, create: false
    )
    let path = try AbsolutePath(validating: result.path)
    // Foundation returns a path that is unique every time, so we return both that path, as well as its parent.
    return [path, path.parentDirectory]
  }
}

private var _localFileSystem: FileSystem = LocalFileSystem()

/// Public access to the local FS proxy.
public var localFileSystem: FileSystem {
  get {
    return _localFileSystem
  }

  @available(
    *, deprecated,
    message:
      "This global should never be mutable and is supposed to be read-only. Deprecated in Apr 2023."
  )
  set {
    _localFileSystem = newValue
  }
}

extension FileSystem {
  /// Print the filesystem tree of the given path.
  ///
  /// For debugging only.
  public func dumpTree(at path: AbsolutePath = .root) {
    print(".")
    do {
      try recurse(fs: self, path: path)
    } catch {
      print("\(error)")
    }
  }

  /// Write bytes to the path if the given contents are different.
  public func writeIfChanged(path: AbsolutePath, bytes: ByteString) throws {
    try createDirectory(path.parentDirectory, recursive: true)

    // Return if the contents are same.
    if isFile(path), try readFileContents(path) == bytes {
      return
    }

    try writeFileContents(path, bytes: bytes)
  }

  /// Helper method to recurse and print the tree.
  private func recurse(fs: FileSystem, path: AbsolutePath, prefix: String = "") throws {
    let contents = try fs.getDirectoryContents(path)

    for (idx, entry) in contents.enumerated() {
      let isLast = idx == contents.count - 1
      let line = prefix + (isLast ? "└── " : "├── ") + entry
      print(line)

      let entryPath = path.appending(component: entry)
      if fs.isDirectory(entryPath) {
        let childPrefix = prefix + (isLast ? "    " : "│   ")
        try recurse(fs: fs, path: entryPath, prefix: String(childPrefix))
      }
    }
  }
}

#if !os(Windows)
  extension dirent {
    /// Get the directory name.
    ///
    /// This returns nil if the name is not valid UTF8.
    public var name: String? {
      var d_name = self.d_name
      return withUnsafePointer(to: &d_name) {
        String(validatingUTF8: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
      }
    }
  }
#endif
