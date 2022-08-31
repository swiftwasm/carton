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

import { WASI as WasmerWASI } from "@wasmer/wasi";
import { WasmFs } from "@wasmer/wasmfs";
import { useAll, WASI as MicroWASI } from "uwasi";

const getWASIExecModel = (instance) => {
  if (instance.exports._start) {
    return "command";
  } else if (instance.exports._initialize) {
    return "reactor";
  }
  return undefined;
}

const WASIs = {
  wasmer: (options) => {
    const createWasmFS = (onStdout, onStderr) => {
      // Instantiate a new WASI Instance
      const wasmFs = new WasmFs();
    
      // Output stdout and stderr to console
      const originalWriteSync = wasmFs.fs.writeSync;
      wasmFs.fs.writeSync = (fd, buffer, offset, length, position) => {
        const text = new TextDecoder("utf-8").decode(buffer);
        if (text !== "\n") {
          switch (fd) {
            case 1:
              onStdout(text);
              break;
            case 2:
              onStderr(text);
              break;
          }
        }
        return originalWriteSync(fd, buffer, offset, length, position);
      };
    
      return wasmFs;
    };
    
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
        return original_clock_res_get(clockId, resolution);
      };
      return wasiObject.wasiImport;
    };

    const wasmFs = createWasmFS(
      (stdout) => {
        console.log(stdout);
        options.onStdout(stdout);
      },
      (stderr) => {
        console.error(stderr);
        options.onStderr(stderr);
      }
    );

    const wasi = new WasmerWASI({
      args: options.args,
      env: {},
      bindings: {
        ...WasmerWASI.defaultBindings,
        fs: wasmFs.fs,
      },
    });

    return {
      wasiImport: wrapWASI(wasi),
      start(instance) {
        switch (getWASIExecModel(instance)) {
          case "command": {
            wasi.start(instance);
            break;
          }
          case "reactor": {
            wasi.setMemory(instance.exports.memory);
            instance.exports._initialize();
            instance.exports.main();
          }
        }
      }
    }
  },
  uwasi: (options) => {
    const wasi = new MicroWASI({
      args: options.args,
      env: {},
      features: [useAll({
        stdout: (line) => {
          console.log(line);
          options.onStdout(line);
        },
        stderr: (line) => {
          console.error(line);
          options.onStderr(line);
        }
      })],
    });

    return {
      wasiImport: wasi.wasiImport,
      start(instance) {
        switch (getWASIExecModel(instance)) {
          case "command": {
            wasi.start(instance);
            break;
          }
          case "reactor": {
            wasi.initialize(instance);
            instance.exports.main();
          }
        }
      }
    }
  },
}

export const WasmRunner = (rawOptions, SwiftRuntime) => {
  const options = defaultRunnerOptions(rawOptions);

  let swift;
  if (SwiftRuntime) {
    swift = new SwiftRuntime();
  }

  const wasi = WASIs[options.wasi](options);

  const createWasmImportObject = (extraWasmImports) => {
    const importObject = {
      wasi_snapshot_preview1: wasi.wasiImport,
    };

    if (swift) {
      importObject.javascript_kit = swift.wasmImports;
    }

    if (extraWasmImports) {
      // Shallow clone
      for (const key in extraWasmImports) {
        importObject[key] = extraWasmImports[key];
      }
    }

    return importObject;
  };

  return {
    async run(wasmBytes, extraWasmImports) {
      if (!extraWasmImports) {
        extraWasmImports = {};
      }
      extraWasmImports.__stack_sanitizer = {
        report_stack_overflow: () => {
          throw new Error("Detected stack buffer overflow.");
        },
      };
      const importObject = createWasmImportObject(extraWasmImports);
      const { instance } = await WebAssembly.instantiate(wasmBytes, importObject);

      if (swift && instance.exports.swjs_library_version) {
        swift.setInstance(instance);
      }

      wasi.start(instance);
    },
  };
};

const defaultRunnerOptions = (options) => {
  if (!options) return defaultRunnerOptions({});
  if (!options.onStdout) {
    options.onStdout = () => {};
  }
  if (!options.onStderr) {
    options.onStderr = () => {};
  }
  if (!options.args) {
    options.args = [];
  }
  if (!options.wasi) {
    options.wasi = "wasmer";
  }
  return options;
};

