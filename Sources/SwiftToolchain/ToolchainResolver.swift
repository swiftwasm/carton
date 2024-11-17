import Foundation

protocol ToolchainResolver {
  func fetchVersions() throws -> [(version: String, path: URL)]
  func toolchain(for version: String) -> URL
}

final class XCToolchainResolver: ToolchainResolver {
  let toolchainsPath: URL
  let fileSystem: FileManager

  init?(libraryPath: URL, fileSystem: FileManager) {
    toolchainsPath = libraryPath
      .appendingPathComponent("Developer")
      .appendingPathComponent("Toolchains")
    self.fileSystem = fileSystem
    guard fileSystem.isDirectory(at: libraryPath) else {
      return nil
    }
  }

  func fetchVersions() throws -> [(version: String, path: URL)] {
    let xctoolchains = try fileSystem.contentsOfDirectory(atPath: toolchainsPath.path)
    return xctoolchains.compactMap {
      guard let name = Self.toolchainName(fromXCToolchain: $0) else { return nil }
      return (version: name, path: toolchainsPath.appendingPathComponent($0))
    }
  }

  func toolchain(for version: String) -> URL {
    toolchainsPath.appendingPathComponent(Self.xctoolchainName(fromVersion: version))
  }

  private static func toolchainName(fromXCToolchain xctoolchain: String) -> String? {
    let prefix = "swift-"
    let suffix = ".xctoolchain"
    guard xctoolchain.hasPrefix(prefix), xctoolchain.hasSuffix(suffix) else {
      return nil
    }
    return String(xctoolchain.dropFirst(prefix.count).dropLast(suffix.count))
  }

  private static func xctoolchainName(fromVersion version: String) -> String {
    "swift-\(version).xctoolchain"
  }
}

final class SwiftEnvToolchainResolver: ToolchainResolver {
  let versionsPath: URL
  let fileSystem: FileManager

  init(fileSystem: FileManager) throws {
    versionsPath = fileSystem.homeDirectoryForCurrentUser
      .appendingPathComponent(".swiftenv")
      .appendingPathComponent("versions")
    self.fileSystem = fileSystem
  }

  func fetchVersions() throws -> [(version: String, path: URL)] {
    let versions = try fileSystem.contentsOfDirectory(atPath: versionsPath.path)
    return versions.map {
      (version: $0, path: versionsPath.appendingPathComponent($0))
    }
  }

  func toolchain(for version: String) -> URL {
    versionsPath.appendingPathComponent(version)
  }
}

final class CartonToolchainResolver: ToolchainResolver {
  let cartonSDKPath: URL
  let fileSystem: FileManager

  init(fileSystem: FileManager) throws {
    cartonSDKPath = fileSystem.homeDirectoryForCurrentUser
      .appendingPathComponent(".carton")
      .appendingPathComponent("sdk")
    self.fileSystem = fileSystem
  }

  func fetchVersions() throws -> [(version: String, path: URL)] {
    let versions = try fileSystem.contentsOfDirectory(atPath: cartonSDKPath.path)
    return versions.map {
      (version: $0, path: cartonSDKPath.appendingPathComponent($0))
    }
  }

  func toolchain(for version: String) -> URL {
    cartonSDKPath.appendingPathComponent(version)
  }
}
