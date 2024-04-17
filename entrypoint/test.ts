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
import { WASIProcExit } from "@bjorn3/browser_wasi_shim";
import { WasmRunner } from "./common.js";
import type { SwiftRuntimeConstructor } from "./JavaScriptKit_JavaScriptKit.resources/Runtime";

const socket = new ReconnectingWebSocket(`ws://${location.host}/watcher`);
socket.addEventListener("message", (message) => {
  if (message.data === "reload") {
    location.reload();
  }
});

const startWasiTask = async () => {
  // Fetch our Wasm File
  const response = await fetch("/main.wasm");
  const responseArrayBuffer = await response.arrayBuffer();

  let runtimeConstructor: SwiftRuntimeConstructor | undefined = undefined;
  try {
    const { SwiftRuntime } = await import(
      // @ts-ignore
      "./JavaScriptKit_JavaScriptKit.resources/Runtime/index.mjs"
    );
    runtimeConstructor = SwiftRuntime;
  } catch {
    console.log(
      "JavaScriptKit module not available, running without JavaScriptKit runtime."
    );
  }

  let testRunOutput = "";
  const wasmRunner = WasmRunner(
    {
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
    },
    runtimeConstructor
  );

  // Instantiate the WebAssembly file
  const wasmBytes = new Uint8Array(responseArrayBuffer).buffer;

  // There are 6 cases to exit test
  // 1. Successfully finished XCTest with `exit(0)` synchronously
  // 2. Unsuccessfully finished XCTest with `exit(non-zero)` synchronously
  // 3. Successfully finished XCTest with `exit(0)` asynchronously
  // 4. Unsuccessfully finished XCTest with `exit(non-zero)` asynchronously
  // 5. Crash by throwing JS exception synchronously
  // 6. Crash by throwing JS exception asynchronously

  const handleExitOrError = (error: any) => {
    // XCTest always calls `exit` at the end when no crash
    if (error instanceof WASIProcExit) {
      // pass the output to the server in any case
      socket.send(JSON.stringify({ kind: "testRunOutput", testRunOutput }));
      if (error.code === 0) {
        socket.send(JSON.stringify({ kind: "testPassed" }));
      } else {
        handleError(error) // test failed
      }
    } else {
      handleError(error) // something wrong happens during test
    }
    const divElement = document.createElement("p");
    divElement.innerHTML =
      "Test run finished. Check the output of <code>carton test</code> for details.";
    document.body.appendChild(divElement);
  }
  // Handle asynchronous exits (case 3, 4, 6)
  window.addEventListener("unhandledrejection", event => {
    event.preventDefault();
    const error = event.reason;
    handleExitOrError(error);
  });
  // Start the WebAssembly WASI instance
  try {
    await wasmRunner.run(wasmBytes);
  } catch (error) {
    // Handle synchronous exits (case 1, 2, 5)
    handleExitOrError(error)
    return
  }
  // When JavaScriptEventLoop executor is still running,
  // reachable here without catch (case 3, 4, 6)
};

function handleError(e: any) {
  console.error(e);
  if (e instanceof WebAssembly.RuntimeError) {
    console.log(e.stack);
  }
  socket.send(JSON.stringify({ kind: "errorReport", errorReport: e.toString() }));
}

try {
  startWasiTask().catch(handleError);
} catch (e) {
  handleError(e);
}
