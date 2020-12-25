import TSCBasic
import WAMR

public func wasiRuntimeExecute(wasmPath: AbsolutePath, cmdLineArgs: [String]) throws {
  WasmRuntime.initialize()
  let binary = try localFileSystem.readFileContents(wasmPath)
  let module = try WasmModule(binary: binary.contents)
  module.setWasiOptions(dirs: [], mapDirs: [], envs: [], args: cmdLineArgs)
  let instance = try module.instantiate(stackSize: 256 * 1024)
  try instance.executeMain(args: [])
}
