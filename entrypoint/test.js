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

import ReconnectingWebSocket from "reconnecting-websocket";
import { WASIExitError } from "@wasmer/wasi";
import { WasmRunner } from "./common.js";

const socket = new ReconnectingWebSocket(`ws://${location.host}/watcher`);
socket.addEventListener("message", (message) => {
  if (message.data === "reload") {
    location.reload();
  }
});

let testRunOutput = "";
const wasmRunner = WasmRunner({
  onStdout: (text) => {
    testRunOutput += text + "\n";
  },
  onStderr: () => {
    socket.send(
      JSON.stringify({
        kind: "stackTrace",
        stackTrace: new Error().stack,
      })
    );
  },
});

const startWasiTask = async () => {
  // Fetch our Wasm File
  const response = await fetch("/main.wasm");
  const responseArrayBuffer = await response.arrayBuffer();

  // Instantiate the WebAssembly file
  const wasmBytes = new Uint8Array(responseArrayBuffer).buffer;
  // Start the WebAssembly WASI instance
  try {
    await wasmRunner.run(wasmBytes, {
      __stack_sanitizer: {
        report_stack_overflow: () => {
          throw new Error("Detected stack-buffer-overflow.");
        },
      },
    });
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
