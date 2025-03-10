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

import { instantiate, WebAssembly } from "./intrinsics.js";
import type { SwiftRuntimeConstructor } from "./JavaScriptKit_JavaScriptKit.resources/Runtime";

const startWasiTask = async () => {
  // Fetch our Wasm File
  const response = await fetch("REPLACE_THIS_WITH_THE_MAIN_WEBASSEMBLY_MODULE");

  let runtimeConstructor: SwiftRuntimeConstructor | undefined = undefined;
  try {
    // NOTE: We need to provide the path via a variable to make Vite happy as it
    // doesn't understand @vite-ignore comments with dynamic imports with string literals.
    const modulePath = "./JavaScriptKit_JavaScriptKit.resources/Runtime/index.mjs";
    const { SwiftRuntime } = await import(
      // @ts-ignore
      /* @vite-ignore */ modulePath
    );
    runtimeConstructor = SwiftRuntime;
  } catch {
    // JavaScriptKit module not available, running without JavaScriptKit runtime.
  }

  // Instantiate the WebAssembly file
  await instantiate({
    module: await WebAssembly.compileStreaming(response),
    onStdoutLine(line) {
      console.log(line);
    },
    onStderrLine(line) {
      console.error(line);
    },
    SwiftRuntime: runtimeConstructor,
  });
};

async function main(): Promise<void> {
  await startWasiTask();
}

main();
