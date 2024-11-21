export class SwiftRuntime {
  constructor({ sharedMemory: booleam });
  setInstance(instance: WebAssembly.Instance): void;
  main?(): void;
  readonly wasmImports: ImportedFunctions;
}
export type SwiftRuntimeConstructor = typeof SwiftRuntime;
export interface ImportedFunctions { }
