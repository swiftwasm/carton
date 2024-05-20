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

// This executable is a thin wrapper around the Swift Package Manager and the Carton's SwiftPM Plugins.
// The responsibilities of this executable are:
// - to install appropriate SwiftWasm toolchain if it's not installed and to use it for the later invocations
//   * This step will be eventually removed once SwiftPM provides a good way to manage Swift SDKs declaratively
//     and Xcode toolchain provides WebAssembly target. (OSS toolchain already provides it)
// - to grant the SwiftPM Plugin process appropriate permissions to write to the file system
//   * "dev" and "test" subcommands require listening TCP sockets but SwiftPM doesn't provide a way to
//     express this requirement in the package manifest
//   * "bundle" subcommand requires writing to the file system to "./Bundle" directory. This is to keep
//     soft compatibility with the default behavior of the previous version of Carton
// - to give the SwiftPM build system the target triple by default
//   * SwiftPM doesn't provide a way to control the target triple from plugin process
// - to pre-build "{package-name}PackageTests" product before running plugin process
//   * SwiftPM doesn't support building only "all tests" product from plugin process, so we have to
//     build it before running the CartonTest plugin process
//
// This executable should be eventually removed once SwiftPM provides a way to express those requirements.

import CartonDriver

try await main(arguments: CommandLine.arguments)
