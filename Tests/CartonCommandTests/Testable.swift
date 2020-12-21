//
//  File.swift
//
//
//  Created by Cavelle Benjamin on Dec/21/20.
//

import Foundation
import Path

public protocol Testable {
  var productsDirectory: Path { get }
  var testFixturesDirectory: Path { get }
  var packageDirectory: Path { get }
}

public extension Testable {
  /// Returns path to the built products directory.
  var productsDirectory: Path {
    #if os(macOS)
    for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
      return Path(url: bundle.bundleURL.deletingLastPathComponent())!
    }
    fatalError("couldn't find the products directory")
    #else
    return Path(url: Bundle.main.bundleURL)!
    #endif
  }

  var testFixturesDirectory: Path {
    packageDirectory / "Tests/Fixtures"
  }

  var packageDirectory: Path {
    // necessary if you are using xcode
    if let _ = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] {
      return productsDirectory
        .parent
        .parent
        .parent
        .parent
        .parent
    }

    return productsDirectory
      .parent
      .parent
      .parent
  }
}
