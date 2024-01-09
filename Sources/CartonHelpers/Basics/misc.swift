/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

#if os(Windows)
  import WinSDK
#endif

#if os(Windows)
  public let executableFileSuffix = ".exe"
#else
  public let executableFileSuffix = ""
#endif

#if os(Windows)
  private func quote(_ arguments: [String]) -> String {
    func quote(argument: String) -> String {
      if !argument.contains(where: { " \t\n\"".contains($0) }) {
        return argument
      }

      // To escape the command line, we surround the argument with quotes.
      // However, the complication comes due to how the Windows command line
      // parser treats backslashes (\) and quotes (").
      //
      // - \ is normally treated as a literal backslash
      //      e.g. alpha\beta\gamma => alpha\beta\gamma
      // - The sequence \" is treated as a literal "
      //      e.g. alpha\"beta => alpha"beta
      //
      // But then what if we are given a path that ends with a \?
      //
      // Surrounding alpha\beta\ with " would be "alpha\beta\" which would be
      // an unterminated string since it ends on a literal quote. To allow
      // this case the parser treats:
      //
      //  - \\" as \ followed by the " metacharacter
      //  - \\\" as \ followed by a literal "
      //
      // In general:
      //  - 2n \ followed by " => n \ followed by the " metacharacter
      //  - 2n + 1 \ followed by " => n \ followed by a literal "

      var quoted = "\""
      var unquoted = argument.unicodeScalars

      while !unquoted.isEmpty {
        guard let firstNonBS = unquoted.firstIndex(where: { $0 != "\\" }) else {
          // String ends with a backslash (e.g. first\second\), escape all
          // the backslashes then add the metacharacter ".
          let count = unquoted.count
          quoted.append(String(repeating: "\\", count: 2 * count))
          break
        }

        let count = unquoted.distance(from: unquoted.startIndex, to: firstNonBS)
        if unquoted[firstNonBS] == "\"" {
          // This is a string of \ followed by a " (e.g. first\"second).
          // Escape the backslashes and the quote.
          quoted.append(String(repeating: "\\", count: 2 * count + 1))
        } else {
          // These are just literal backslashes
          quoted.append(String(repeating: "\\", count: count))
        }

        quoted.append(String(unquoted[firstNonBS]))

        // Drop the backslashes and the following character
        unquoted.removeFirst(count + 1)
      }
      quoted.append("\"")

      return quoted
    }
    return arguments.map(quote(argument:)).joined(separator: " ")
  }
#endif

/// Replace the current process image with a new process image.
///
/// - Parameters:
///   - path: Absolute path to the executable.
///   - args: The executable arguments.
public func exec(path: String, args: [String]) throws -> Never {
  let cArgs = CStringArray(args)
  #if os(Windows)
    var hJob: HANDLE

    hJob = CreateJobObjectA(nil, nil)
    if hJob == HANDLE(bitPattern: 0) {
      throw SystemError.exec(Int32(GetLastError()), path: path, args: args)
    }
    defer { CloseHandle(hJob) }

    let hPort = CreateIoCompletionPort(INVALID_HANDLE_VALUE, nil, 0, 1)
    if hPort == HANDLE(bitPattern: 0) {
      throw SystemError.exec(Int32(GetLastError()), path: path, args: args)
    }

    var acpAssociation: JOBOBJECT_ASSOCIATE_COMPLETION_PORT = JOBOBJECT_ASSOCIATE_COMPLETION_PORT()
    acpAssociation.CompletionKey = hJob
    acpAssociation.CompletionPort = hPort
    if !SetInformationJobObject(
      hJob, JobObjectAssociateCompletionPortInformation,
      &acpAssociation, DWORD(MemoryLayout<JOBOBJECT_ASSOCIATE_COMPLETION_PORT>.size))
    {
      throw SystemError.exec(Int32(GetLastError()), path: path, args: args)
    }

    var eliLimits: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
    eliLimits.BasicLimitInformation.LimitFlags =
      DWORD(JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE) | DWORD(JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK)
    if !SetInformationJobObject(
      hJob, JobObjectExtendedLimitInformation, &eliLimits,
      DWORD(MemoryLayout<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>.size))
    {
      throw SystemError.exec(Int32(GetLastError()), path: path, args: args)
    }

    var siInfo: STARTUPINFOW = STARTUPINFOW()
    siInfo.cb = DWORD(MemoryLayout<STARTUPINFOW>.size)

    var piInfo: PROCESS_INFORMATION = PROCESS_INFORMATION()

    try quote(args).withCString(encodedAs: UTF16.self) { pwszCommandLine in
      if !CreateProcessW(
        nil,
        UnsafeMutablePointer<WCHAR>(mutating: pwszCommandLine),
        nil, nil, false,
        DWORD(CREATE_SUSPENDED) | DWORD(CREATE_NEW_PROCESS_GROUP),
        nil, nil, &siInfo, &piInfo)
      {
        throw SystemError.exec(Int32(GetLastError()), path: path, args: args)
      }
    }

    defer { CloseHandle(piInfo.hThread) }
    defer { CloseHandle(piInfo.hProcess) }

    if !AssignProcessToJobObject(hJob, piInfo.hProcess) {
      throw SystemError.exec(Int32(GetLastError()), path: path, args: args)
    }

    _ = ResumeThread(piInfo.hThread)

    var dwCompletionCode: DWORD = 0
    var ulCompletionKey: ULONG_PTR = 0
    var lpOverlapped: LPOVERLAPPED?
    repeat {
    } while GetQueuedCompletionStatus(
      hPort, &dwCompletionCode, &ulCompletionKey,
      &lpOverlapped, INFINITE)
      && !(ulCompletionKey == ULONG_PTR(UInt(bitPattern: hJob))
        && dwCompletionCode == JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO)

    var dwExitCode: DWORD = DWORD(bitPattern: -1)
    _ = GetExitCodeProcess(piInfo.hProcess, &dwExitCode)
    _exit(Int32(bitPattern: dwExitCode))
  #elseif (!canImport(Darwin) || os(macOS))
    guard execv(path, cArgs.cArray) != -1 else {
      throw SystemError.exec(errno, path: path, args: args)
    }
    fatalError("unreachable")
  #else
    fatalError("not implemented")
  #endif
}

@_disfavoredOverload
@available(*, deprecated, message: "Use the overload which returns Never")
public func exec(path: String, args: [String]) throws {
  try exec(path: path, args: args)
}

// MARK: TSCUtility function for searching for executables

/// Create a list of AbsolutePath search paths from a string, such as the PATH environment variable.
///
/// - Parameters:
///   - pathString: The path string to parse.
///   - currentWorkingDirectory: The current working directory, the relative paths will be converted to absolute paths
///     based on this path.
/// - Returns: List of search paths.
public func getEnvSearchPaths(
  pathString: String?,
  currentWorkingDirectory: AbsolutePath?
) -> [AbsolutePath] {
  // Compute search paths from PATH variable.
  #if os(Windows)
    let pathSeparator: Character = ";"
  #else
    let pathSeparator: Character = ":"
  #endif
  return (pathString ?? "").split(separator: pathSeparator).map(String.init).compactMap({
    pathString in
    if let cwd = currentWorkingDirectory {
      return try? AbsolutePath(validating: pathString, relativeTo: cwd)
    }
    return try? AbsolutePath(validating: pathString)
  })
}

/// Lookup an executable path from an environment variable value, current working
/// directory or search paths. Only return a value that is both found and executable.
///
/// This method searches in the following order:
/// * If env value is a valid absolute path, return it.
/// * If env value is relative path, first try to locate it in current working directory.
/// * Otherwise, in provided search paths.
///
/// - Parameters:
///   - filename: The name of the file to find.
///   - currentWorkingDirectory: The current working directory to look in.
///   - searchPaths: The additional search paths to look in if not found in cwd.
/// - Returns: Valid path to executable if present, otherwise nil.
public func lookupExecutablePath(
  filename value: String?,
  currentWorkingDirectory: AbsolutePath? = localFileSystem.currentWorkingDirectory,
  searchPaths: [AbsolutePath] = []
) -> AbsolutePath? {

  // We should have a value to continue.
  guard let value = value, !value.isEmpty else {
    return nil
  }

  var paths: [AbsolutePath] = []

  if let cwd = currentWorkingDirectory,
    let path = try? AbsolutePath(validating: value, relativeTo: cwd)
  {
    // We have a value, but it could be an absolute or a relative path.
    paths.append(path)
  } else if let absPath = try? AbsolutePath(validating: value) {
    // Current directory not being available is not a problem
    // for the absolute-specified paths.
    paths.append(absPath)
  }

  // Ensure the value is not a path.
  if !value.contains("/") {
    // Try to locate in search paths.
    paths.append(contentsOf: searchPaths.map({ $0.appending(component: value) }))
  }

  return paths.first(where: { localFileSystem.isExecutableFile($0) })
}

/// A wrapper for Range to make it Codable.
///
/// Technically, we can use conditional conformance and make
/// stdlib's Range Codable but since extensions leak out, it
/// is not a good idea to extend types that you don't own.
///
/// Range conformance will be added soon to stdlib so we can remove
/// this type in the future.
public struct CodableRange<Bound> where Bound: Comparable & Codable {

  /// The underlying range.
  public let range: Range<Bound>

  /// Create a CodableRange instance.
  public init(_ range: Range<Bound>) {
    self.range = range
  }
}

extension CodableRange: Sendable where Bound: Sendable {}

extension CodableRange: Codable {
  private enum CodingKeys: String, CodingKey {
    case lowerBound, upperBound
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(range.lowerBound, forKey: .lowerBound)
    try container.encode(range.upperBound, forKey: .upperBound)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let lowerBound = try container.decode(Bound.self, forKey: .lowerBound)
    let upperBound = try container.decode(Bound.self, forKey: .upperBound)
    self.init(Range(uncheckedBounds: (lowerBound, upperBound)))
  }
}

extension AbsolutePath {
  /// File URL created from the normalized string representation of the path.
  public var asURL: Foundation.URL {
    return URL(fileURLWithPath: pathString)
  }
}

// FIXME: Eliminate or find a proper place for this.
public enum SystemError: Error {
  case chdir(Int32, String)
  case close(Int32)
  case exec(Int32, path: String, args: [String])
  case pipe(Int32)
  case posix_spawn(Int32, [String])
  case read(Int32)
  case setenv(Int32, String)
  case stat(Int32, String)
  case symlink(Int32, String, dest: String)
  case unsetenv(Int32, String)
  case waitpid(Int32)
}

/// Memoizes a costly computation to a cache variable.
public func memoize<T>(to cache: inout T?, build: () throws -> T) rethrows -> T {
  if let value = cache {
    return value
  } else {
    let value = try build()
    cache = value
    return value
  }
}
