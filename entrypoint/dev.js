import { SwiftRuntime } from "javascript-kit-swift";
import { WASI } from "@wasmer/wasi";
import { WasmFs } from "@wasmer/wasmfs";
import ReconnectingWebSocket from "reconnecting-websocket";

const swift = new SwiftRuntime();
// Instantiate a new WASI Instance
const wasmFs = new WasmFs();
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

  swift.setInsance(instance);
  // Start the WebAssembly WASI instance
  wasi.start(instance);

  // Output what's inside of /dev/stdout
  const stdout = await wasmFs.getStdOut();
  console.log(stdout);
};
startWasiTask();
