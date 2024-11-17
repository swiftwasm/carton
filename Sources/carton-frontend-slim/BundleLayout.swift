// Copyright 2024 Carton contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import CartonCore
import CartonHelpers
import Foundation

struct BundleLayout {

  var mainModuleBaseName: String
  var wasmSourcePath: AbsolutePath
  var buildDirectory: AbsolutePath
  var bundleDirectory: AbsolutePath
  var topLevelResourcePaths: [String]

  func copyAppEntrypoint(customIndexPage: String?, contentHash: Bool, terminal: InteractiveWriter)
    throws
  {
    let wasmDestinationPath = try computeWasmDestinationPath(contentHash: contentHash)
    if wasmSourcePath != wasmDestinationPath {
      try localFileSystem.move(from: wasmSourcePath, to: wasmDestinationPath)
    }
    try copyResources(wasmDestinationPath: wasmDestinationPath, terminal: terminal)
    // Copy the bundle entrypoint, point to the binary, and give it a cachebuster name.
    let entrypoint = ByteString(
      encodingAsUTF8: String(decoding: StaticResource.bundle, as: UTF8.self)
        .replacingOccurrences(
          of: "REPLACE_THIS_WITH_THE_MAIN_WEBASSEMBLY_MODULE",
          with: wasmDestinationPath.basename
        )
    )
    let entrypointName = contentHash ? "app.\(entrypoint.hexChecksum).js" : "app.js"
    try localFileSystem.writeFileContents(
      AbsolutePath(validating: entrypointName, relativeTo: bundleDirectory),
      bytes: entrypoint
    )

    try localFileSystem.writeFileContents(
      AbsolutePath(validating: "index.html", relativeTo: bundleDirectory),
      bytes: ByteString(
        encodingAsUTF8: HTML.indexPage(
          customContent: HTML.readCustomIndexPage(at: customIndexPage, on: localFileSystem),
          entrypointName: entrypointName
        ))
    )
  }

  func copyTestEntrypoint(contentHash: Bool, terminal: InteractiveWriter) throws {
    let wasmDestinationPath = try computeWasmDestinationPath(contentHash: contentHash)
    if wasmSourcePath != wasmDestinationPath {
      try localFileSystem.copy(from: wasmSourcePath, to: wasmDestinationPath)
    }
    try copyResources(wasmDestinationPath: wasmDestinationPath, terminal: terminal)

    let contents: [String: String] = [
      "test.browser.js": """
      import { testBrowser } from "./index.js";
      testBrowser(process.argv.slice(2));

      """,
      "test.node.js": """
      import { testNode } from "./index.js";
      testNode(process.argv.slice(2))

      """,
      "test.browser.html": """
      <!DOCTYPE html>
      <html>

      <body>
          <script type="module">
              import { testBrowser } from "./index.js";
              testBrowser([], true);
          </script>
      </body>

      </html>

      """,
    ]
    for (filename, content) in contents {
      try localFileSystem.writeFileContents(
        AbsolutePath(validating: filename, relativeTo: bundleDirectory),
        bytes: ByteString(encodingAsUTF8: content)
      )
    }
  }

  func computeWasmDestinationPath(contentHash: Bool) throws -> AbsolutePath {
    let wasmFileHash = try localFileSystem.readFileContents(wasmSourcePath).hexChecksum
    // Rename the final binary to use a part of its hash to bust browsers and CDN caches.
    let mainModuleName = contentHash ? "\(mainModuleBaseName).\(wasmFileHash).wasm" : "\(mainModuleBaseName).wasm"
    return try AbsolutePath(validating: mainModuleName, relativeTo: bundleDirectory)
  }

  func copyResources(wasmDestinationPath: AbsolutePath, terminal: InteractiveWriter) throws {
    try localFileSystem.writeFileContents(
      AbsolutePath(validating: "intrinsics.js", relativeTo: bundleDirectory),
      bytes: ByteString(StaticResource.intrinsics)
    )

    let resourcesDirectoryNames = try FileManager.default.resourcesDirectoryNames(
      relativeTo: buildDirectory.asURL)
    let hasJavaScriptKitResources = resourcesDirectoryNames.contains(
      "JavaScriptKit_JavaScriptKit.resources")

    try localFileSystem.writeFileContents(
      AbsolutePath(validating: "index.js", relativeTo: bundleDirectory),
      bytes: ByteString(
        encodingAsUTF8: indexJsContent(
          mainModuleName: wasmDestinationPath.basename, hasJavaScriptKitResources: hasJavaScriptKitResources)
      )
    )

    try localFileSystem.writeFileContents(
      AbsolutePath(validating: "package.json", relativeTo: bundleDirectory),
      bytes: ByteString(
        encodingAsUTF8: """
          {
            "type": "module",
            "main": "./index.js"
          }
          """
      )
    )

    for directoryName in resourcesDirectoryNames {
      let resourcesPath = buildDirectory.appending(component: directoryName)
      let targetDirectory = bundleDirectory.appending(component: directoryName)

      guard localFileSystem.exists(resourcesPath, followSymlink: true) else { continue }
      terminal.logLookup("Copying resources to ", targetDirectory)
      try localFileSystem.copy(from: resourcesPath, to: targetDirectory)
    }

    for resourcesPath in topLevelResourcePaths {
      let resourcesPath = try AbsolutePath(
        validating: resourcesPath, relativeTo: localFileSystem.currentWorkingDirectory!)
      for file in try FileManager.default.traverseRecursively(resourcesPath.asURL) {
        let targetPath = bundleDirectory.appending(component: file.lastPathComponent)
        let sourcePath = bundleDirectory.appending(component: resourcesPath.basename).appending(
          component: file.lastPathComponent)

        guard localFileSystem.exists(sourcePath, followSymlink: true),
          !localFileSystem.exists(targetPath, followSymlink: true)
        else { continue }

        terminal.logLookup("Creating symlink ", targetPath)
        try localFileSystem.createSymbolicLink(targetPath, pointingAt: sourcePath, relative: true)
      }
    }
  }

  private func indexJsContent(mainModuleName: String, hasJavaScriptKitResources: Bool) -> String {
    var content = """
      import { WebAssembly, instantiate as internalInstantiate, testBrowser as internalTestBrowser, testNode as internalTestNode } from './intrinsics.js';

      """
    if hasJavaScriptKitResources {
      content += """
        import { SwiftRuntime } from './JavaScriptKit_JavaScriptKit.resources/Runtime/index.mjs';

        """
    }
    content += """
      export const wasmFileName = '\(mainModuleName)';

      export async function instantiate(options, imports) {
        if (!options) {
          options = {};
        }
        const isNodeJs = (typeof process !== 'undefined') && (process.release.name === 'node');
        const isWebBrowser = (typeof window !== 'undefined');

        if (!options.module) {
          if (isNodeJs) {
            const module = await import(/* webpackIgnore: true */'node:module');
            const importMeta = import.meta;
            const fs = await import('fs/promises');
            const url = await import('url');
            const filePath = import.meta.resolve('./' + wasmFileName);
            options.module = await WebAssembly.compile(await fs.readFile(url.fileURLToPath(filePath)));
          } else if (isWebBrowser) {
            options.module = await WebAssembly.compileStreaming(fetch(wasmFileName));
          } else {
            throw new Error('Unsupported environment to automatically load the WebAssembly module. Please provide the \"module\" option with the compiled WebAssembly module manually.');
          }
        }

      """
    if hasJavaScriptKitResources {
      content += """
          options.SwiftRuntime = SwiftRuntime;

        """
    }
    content += """
        return internalInstantiate(options, imports);
      }

      export async function testBrowser(args, inPage = false) {
        await internalTestBrowser(instantiate, wasmFileName, args, import.meta.url, inPage);
      }

      export async function testNode(args) {
        await internalTestNode(instantiate, wasmFileName, args);
      }

      """

    return content
  }
}

extension ByteString {
  fileprivate var hexChecksum: String {
    String(SHA256().hash(self).hexadecimalRepresentation.prefix(16))
  }
}
