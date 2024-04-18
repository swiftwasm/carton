// Copyright 2022 Carton contributors
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

import fs from "fs/promises";
import path from "path";
import { WasmRunner } from "./common.js";
import type { SwiftRuntimeConstructor } from "./JavaScriptKit_JavaScriptKit.resources/Runtime";

const args = [...process.argv];
args.shift();
args.shift();
const [wasmFile, ...testArgs] = args;
testArgs.unshift(path.basename(wasmFile));

if (!wasmFile) {
  throw Error("No WASM test file specified, can not run tests");
}

const startWasiTask = async () => {
  const wasmBytes = await fs.readFile(wasmFile);

  let runtimeConstructor: SwiftRuntimeConstructor | undefined = undefined;
  try {
    const { SwiftRuntime } = await import(
      // @ts-ignore
      "./JavaScriptKit_JavaScriptKit.resources/Runtime/index.mjs"
    );

    runtimeConstructor = SwiftRuntime;

    // Make `require` function available in the Swift environment. By default it's only available in the local scope,
    // but not on the `global` object.
    global.require = require;
  } catch {
    // No JavaScriptKit module found, run the Wasm module without JSKit
  }

  const wasmRunner = WasmRunner({ args: testArgs }, runtimeConstructor);

  await wasmRunner.run(wasmBytes, {
    "wasi_snapshot_preview1": {
      // @bjorn3/browser_wasi_shim raises an exception when
      // the process exits, but we just want to exit the process itself.
      proc_exit: (code: number) => {
        process.exit(code);
      },
    }
  });
};

startWasiTask().catch((e) => {
  throw e;
});
