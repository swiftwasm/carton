import TSCBasic

protocol ToolchainResolver {
  func fetchVersions() throws -> [(version: String, path: AbsolutePath)]
  func toolchain(for version: String) -> AbsolutePath
}

final class XCToolchainResolver: ToolchainResolver {
  let toolchainsPath: AbsolutePath
  let fileSystem: FileSystem

  init?(libraryPath: AbsolutePath, fileSystem: FileSystem) {
    toolchainsPath = libraryPath.appending(components: "Developer", "Toolchains")
    self.fileSystem = fileSystem
    guard fileSystem.isDirectory(libraryPath) else {
      return nil
    }
  }

  func fetchVersions() throws -> [(version: String, path: AbsolutePath)] {
    let xctoolchains = try fileSystem.getDirectoryContents(toolchainsPath)
    return xctoolchains.compactMap {
      guard let name = Self.toolchainName(fromXCToolchain: $0) else { return nil }
      return (version: name, path: toolchainsPath.appending(component: $0))
    }
  }

  func toolchain(for version: String) -> AbsolutePath {
    toolchainsPath.appending(component: Self.xctoolchainName(fromVersion: version))
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
  let versionsPath: AbsolutePath
  let fileSystem: FileSystem

  init(fileSystem: FileSystem) throws {
    versionsPath = try fileSystem.homeDirectory.appending(components: ".swiftenv", "versions")
    self.fileSystem = fileSystem
  }

  func fetchVersions() throws -> [(version: String, path: AbsolutePath)] {
    let versions = try fileSystem.getDirectoryContents(versionsPath)
    return versions.map {
      (version: $0, path: versionsPath.appending(component: $0))
    }
  }

  func toolchain(for version: String) -> AbsolutePath {
    versionsPath.appending(component: version)
  }
}

final class CartonToolchainResolver: ToolchainResolver {
  let cartonSDKPath: AbsolutePath
  let fileSystem: FileSystem

  init(fileSystem: FileSystem) throws {
    cartonSDKPath = try fileSystem.homeDirectory.appending(components: ".carton", "sdk")
    self.fileSystem = fileSystem
  }

  func fetchVersions() throws -> [(version: String, path: AbsolutePath)] {
    let versions = try fileSystem.getDirectoryContents(cartonSDKPath)
    return versions.map {
      (version: $0, path: cartonSDKPath.appending(component: $0))
    }
  }

  func toolchain(for version: String) -> AbsolutePath {
    cartonSDKPath.appending(component: version)
  }
}
