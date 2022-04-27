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

import { SwiftRuntime } from "javascript-kit-swift";
import { WASI } from "@wasmer/wasi";
import { WasmFs } from "@wasmer/wasmfs";
import ReconnectingWebSocket from "reconnecting-websocket";

const swift = new SwiftRuntime();
// Instantiate a new WASI Instance
const wasmFs = new WasmFs();

const socket = new ReconnectingWebSocket(`ws://${location.host}/watcher`);

socket.addEventListener("message", (message) => {
  if (message.data === "reload") {
    location.reload();
  }
});

// Output stdout and stderr to console
const originalWriteSync = wasmFs.fs.writeSync;
wasmFs.fs.writeSync = (fd, buffer, offset, length, position) => {
  const text = new TextDecoder("utf-8").decode(buffer);
  if (text !== "\n") {
    switch (fd) {
      case 1:
        console.log(text);
        break;
      case 2:
        console.error(text);
        const prevLimit = Error.stackTraceLimit;
        Error.stackTraceLimit = 1000
        socket.send(
          JSON.stringify({
            kind: "stackTrace",
            stackTrace: new Error().stack,
          })
        );
        Error.stackTraceLimit = prevLimit;
        break;
    }
  }
  return originalWriteSync(fd, buffer, offset, length, position);
};

const wasi = new WASI({
  args: [],
  env: {},
  bindings: {
    ...WASI.defaultBindings,
    fs: wasmFs.fs,
  },
});

const wrapWASI = (wasiObject) => {
  // PATCH: @wasmer-js/wasi@0.x forgets to call `refreshMemory` in `clock_res_get`,
  // which writes its result to memory view. Without the refresh the memory view,
  // it accesses a detached array buffer if the memory is grown by malloc.
  // But they wasmer team discarded the 0.x codebase at all and replaced it with
  // a new implementation written in Rust. The new version 1.x is really unstable
  // and not production-ready as far as katei investigated in Apr 2022.
  // So override the broken implementation of `clock_res_get` here instead of
  // fixing the wasi polyfill.
  // Reference: https://github.com/wasmerio/wasmer-js/blob/55fa8c17c56348c312a8bd23c69054b1aa633891/packages/wasi/src/index.ts#L557
  const original_clock_res_get = wasiObject.wasiImport["clock_res_get"];
  wasiObject.wasiImport["clock_res_get"] = (clockId, resolution) => {
    wasiObject.refreshMemory();
    return original_clock_res_get(clockId, resolution)
  };
  return wasiObject.wasiImport;
}

const startWasiTask = async () => {
  // Fetch our Wasm File
  const response = await fetch("/main.wasm");
  const responseArrayBuffer = await response.arrayBuffer();

  // Instantiate the WebAssembly file
  const wasmBytes = new Uint8Array(responseArrayBuffer).buffer;
  const { instance } = await WebAssembly.instantiate(wasmBytes, {
    wasi_snapshot_preview1: wrapWASI(wasi),
    javascript_kit: swift.importObjects(),
    __stack_sanitizer: {
      report_stack_overflow: () => {
        throw new Error("Detected stack-buffer-overflow.")
      }
    }
  });

  swift.setInstance(instance);
  // Start the WebAssembly WASI instance
  wasi.start(instance);
  // Initialize and start Reactor
  if (instance.exports._initialize) {
    instance.exports._initialize();
    instance.exports.main();
  }
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
