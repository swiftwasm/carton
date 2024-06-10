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

import { WASI, File, OpenFile, ConsoleStdout, PreopenDirectory } from "@bjorn3/browser_wasi_shim";
import type { SwiftRuntime, SwiftRuntimeConstructor } from "./JavaScriptKit_JavaScriptKit.resources/Runtime";

export class LineDecoder {
  constructor(onLine: (line: string) => void) {
    this.decoder = new TextDecoder("utf-8", { fatal: false });
    this.buffer = "";
    this.onLine = onLine;
  }

  private decoder: TextDecoder;
  private buffer: string;
  private onLine: (line: string) => void;

  send(chunk: Uint8Array) {
    this.buffer += this.decoder.decode(chunk, { stream: true });

    const lines = this.buffer.split("\n");
    for (let i = 0; i < lines.length - 1; i++) {
      this.onLine(lines[i]);
    }

    this.buffer = lines[lines.length - 1];
  }
}

export type Options = {
  args?: string[];
  onStdout?: (chunk: Uint8Array) => void;
  onStdoutLine?: (line: string) => void;
  onStderr?: (chunk: Uint8Array) => void;
  onStderrLine?: (line: string) => void;
};

export type WasmRunner = {
  run(wasmBytes: ArrayBufferLike, extraWasmImports?: WebAssembly.Imports): Promise<void>
};

export const WasmRunner = (rawOptions: Options, SwiftRuntime: SwiftRuntimeConstructor | undefined): WasmRunner => {
  const options: Options = defaultRunnerOptions(rawOptions);

  let swift: SwiftRuntime;
  if (SwiftRuntime) {
    swift = new SwiftRuntime();
  }

  let stdoutLine: LineDecoder | undefined = undefined;
  if (options.onStdoutLine != null) {
    stdoutLine = new LineDecoder(options.onStdoutLine);
  }
  const stdout = new ConsoleStdout((chunk) => {
    options.onStdout?.call(undefined, chunk);
    stdoutLine?.send(chunk);
  });

  let stderrLine: LineDecoder | undefined = undefined;
  if (options.onStderrLine != null) {
    stderrLine = new LineDecoder(options.onStderrLine);
  }
  const stderr = new ConsoleStdout((chunk) => {
    options.onStderr?.call(undefined, chunk);
    stderrLine?.send(chunk);
  });

  const args = options.args || [];
  const fds = [
    new OpenFile(new File([])), // stdin
    stdout,
    stderr,
    new PreopenDirectory("/", new Map()),
  ];

  const wasi = new WASI(args, [], fds, {
    debug: false
  });

  const createWasmImportObject = (
    extraWasmImports: WebAssembly.Imports,
    module: WebAssembly.Module,
  ): WebAssembly.Imports => {
    const importObject: WebAssembly.Imports = {
      wasi_snapshot_preview1: wasi.wasiImport,
    };

    if (swift) {
      importObject.javascript_kit = swift.wasmImports as unknown as WebAssembly.ModuleImports;
    }

    if (extraWasmImports) {
      for (const moduleName in extraWasmImports) {
        if (!importObject[moduleName]) {
          importObject[moduleName] = {};
        }
        for (const entry in extraWasmImports[moduleName]) {
          importObject[moduleName][entry] = extraWasmImports[moduleName][entry];
        }
      }
    }

    for (const importEntry of WebAssembly.Module.imports(module)) {
      if (!importObject[importEntry.module]) {
        importObject[importEntry.module] = {};
      }
      if (importEntry.kind == "function" && !importObject[importEntry.module][importEntry.name]) {
        importObject[importEntry.module][importEntry.name] = () => {
          throw new Error(`Imported function ${importEntry.module}.${importEntry.name} not implemented`);
        }
      }
    }

    return importObject;
  };

  return {
    async run(wasmBytes: ArrayBufferLike, extraWasmImports?: WebAssembly.Imports) {
      if (!extraWasmImports) {
        extraWasmImports = {};
      }
      extraWasmImports.__stack_sanitizer = {
        report_stack_overflow: () => {
          throw new Error("Detected stack buffer overflow.");
        },
      };
      const module = await WebAssembly.compile(wasmBytes);
      const importObject = createWasmImportObject(extraWasmImports, module);
      const instance = await WebAssembly.instantiate(module, importObject);

      if (swift && instance.exports.swjs_library_version) {
        swift.setInstance(instance);
      }

      if (typeof instance.exports._start === "function") {
        // Start the WebAssembly WASI instance
        wasi.start(instance as any);
      } else if (typeof instance.exports._initialize == "function") {
        // Initialize and start Reactor
        wasi.initialize(instance as any);
        if (swift && swift.main) {
          // Use JavaScriptKit's entry point if it's available
          swift.main();
        } else {
          // For older versions of JavaScriptKit, we need to handle it manually
          if (typeof instance.exports.main === "function") {
            instance.exports.main();
          } else if (typeof instance.exports.__main_argc_argv === "function") {
            // Swift 6.0 and later use `__main_argc_argv` instead of `main`.
            instance.exports.__main_argc_argv(0, 0);
          }
        }
      }
    },
  };
};

const defaultRunnerOptions = (options: Options): Options => {
  if (options.args == null) {
    options.args = ["main.wasm"];
  }
  return options;
};
