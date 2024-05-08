export class SwiftRuntime {
  setInstance(instance: WebAssembly.Instance): void;
  main?(): void;
  readonly wasmImports: ImportedFunctions;
}
export type SwiftRuntimeConstructor = typeof SwiftRuntime;
export interface ImportedFunctions { }
