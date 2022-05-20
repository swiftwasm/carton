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

import { WasmRunner } from "./common.js";

const startWasiTask = async () => {
  // Fetch our Wasm File
  const response = await fetch("REPLACE_THIS_WITH_THE_MAIN_WEBASSEMBLY_MODULE");
  const responseArrayBuffer = await response.arrayBuffer();

  let runtimeConstructor;
  try {
    const { SwiftRuntime } = await import(
      "./JavaScriptKit_JavaScriptKit.resources/Runtime/index.mjs"
    );
    runtimeConstructor = SwiftRuntime;
  } catch {
    // JavaScriptKit module not available, running without JavaScriptKit runtime.
  }

  const wasmRunner = WasmRunner(false, runtimeConstructor);

  // Instantiate the WebAssembly file
  const wasmBytes = new Uint8Array(responseArrayBuffer).buffer;
  await wasmRunner.run(wasmBytes);
};

function handleError(e) {
  console.error(e);
  if (e instanceof WebAssembly.RuntimeError) {
    console.log(e.stack);
  }
}

try {
  startWasiTask().catch(handleError);
} catch (e) {
  handleError(e);
}
