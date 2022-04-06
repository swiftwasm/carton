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
import { WASI, WASIExitError } from "@wasmer/wasi";
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

let testRunOutput = "";

// Output stdout and stderr to console
const originalWriteSync = wasmFs.fs.writeSync;
wasmFs.fs.writeSync = (fd, buffer, offset, length, position) => {
  const text = new TextDecoder("utf-8").decode(buffer);
  if (text !== "\n") {
    switch (fd) {
      case 1:
        console.log(text);
        testRunOutput += text + "\n";
        break;
      case 2:
        console.error(text);
        socket.send(
          JSON.stringify({
            kind: "stackTrace",
            stackTrace: new Error().stack,
          })
        );
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

const startWasiTask = async () => {
  // Fetch our Wasm File
  const response = await fetch("/main.wasm");
  const responseArrayBuffer = await response.arrayBuffer();

  // Instantiate the WebAssembly file
  const wasmBytes = new Uint8Array(responseArrayBuffer).buffer;
  const { instance } = await WebAssembly.instantiate(wasmBytes, {
    wasi_snapshot_preview1: wasi.wasiImport,
    javascript_kit: swift.importObjects(),
    __stack_sanitizer: {
      report_stack_overflow: () => {
        throw new Error("Detected stack-buffer-overflow.")
      }
    }
  });

  if (instance.exports.swjs_library_version) {
    swift.setInstance(instance);
  }
  // Start the WebAssembly WASI instance
  try {
    wasi.start(instance);
    // Initialize and start Reactor
    if (instance.exports._initialize) {
      instance.exports._initialize();
      instance.exports.main();
    }
  } catch (error) {
    if (!(error instanceof WASIExitError) || error.code != 0) {
      throw error; // not a successful test run, rethrow
    }
  } finally {
    // pass the output to the server in any case
    socket.send(
      JSON.stringify({
        kind: "testRunOutput",
        testRunOutput,
      })
    );

    const divElement = document.createElement("p");
    divElement.innerHTML =
      "Test run finished. Check the output of <code>carton test</code> for details.";
    document.body.appendChild(divElement);
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
