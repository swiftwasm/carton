import { SwiftRuntime } from "javascript-kit-swift";
import { WASI } from "@wasmer/wasi";
import { WasmFs } from "@wasmer/wasmfs";
import ReconnectingWebSocket from "reconnecting-websocket";

const swift = new SwiftRuntime();
// Instantiate a new WASI Instance
const wasmFs = new WasmFs();

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

const socket = new ReconnectingWebSocket("ws://127.0.0.1:8080/watcher");

socket.addEventListener("message", (message) => {
  if (message.data === "reload") {
    location.reload();
  }
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
  });

  swift.setInstance(instance);
  // Start the WebAssembly WASI instance
  wasi.start(instance);
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
