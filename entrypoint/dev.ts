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
import { instantiate } from "./intrinsics";
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

  // Instantiate the WebAssembly file
  await instantiate(
    {
      module: await WebAssembly.compileStreaming(response),
      onStdout(chunk) {
        const kindBuffer = new ArrayBuffer(2);
        new DataView(kindBuffer).setUint16(0, 1001, true);

        const buffer = new Uint8Array(2 + chunk.length);
        buffer.set(new Uint8Array(kindBuffer), 0);
        buffer.set(chunk, 2);

        socket.send(buffer);
      },
      onStdoutLine(line) {
        console.log(line);
      },
      onStderr(chunk) {
        const kindBuffer = new ArrayBuffer(2);
        new DataView(kindBuffer).setUint16(0, 1002, true);

        const buffer = new Uint8Array(2 + chunk.length);
        buffer.set(new Uint8Array(kindBuffer), 0);
        buffer.set(chunk, 2);

        socket.send(buffer);
      },
      onStderrLine(line) {
        console.error(line);
      },
      SwiftRuntime: runtimeConstructor,
    }
  );
};

function handleError(e: any) {
  if (e instanceof Error) {
    const stack = e.stack;
    if (stack != null) {
      socket.send(
        JSON.stringify({
          kind: "stackTrace",
          stackTrace: stack,
        })
      );
    }
  }
}

async function main(): Promise<void> {
  try {
    window.addEventListener("error", (event) => {
      handleError(event.error);
    });
    window.addEventListener("unhandledrejection", (event) => {
      handleError(event.reason);
    });
    await startWasiTask();
  } catch (e) {
    handleError(e);
    throw e;
  }
}

main();
