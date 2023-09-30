// Copyright 2020 Carton contributors
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

// TODO: make this `public let defaultToolchainVersion = "wasm-5.9.0-RELEASE"`
// After a stable wasm-5.9 is released
public let defaultToolchainVersion: String = {
    // On macOS 14 (Sonoma) it's not possible to use Xcode older then 15.0
    // Therefore Swift 5.9 is required on Sonoma
    #if swift(>=5.9)
    return "wasm-5.9-SNAPSHOT-2023-08-01-a"
    #else
    return "wasm-5.8.0-RELEASE"
    #endif
}()
