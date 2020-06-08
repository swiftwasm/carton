import { SwiftRuntime } from "javascript-kit-swift";
import { WASI } from "@wasmer/wasi";
import { WasmFs } from "@wasmer/wasmfs";

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

const socket = new WebSocket("ws://127.0.0.1:8080/watcher");

socket.onmessage = (message) => {
  if (message.data === "reload") {
    location.reload();
  }
};

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
