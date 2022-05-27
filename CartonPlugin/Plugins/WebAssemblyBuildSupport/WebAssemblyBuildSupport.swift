
import PackagePlugin
import Foundation

enum Error: LocalizedError {
    case noTarget
}

@main struct WebAssemblyBuildSupport: CommandPlugin {

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        var argumentExtractor = ArgumentExtractor(arguments)
        guard let product = argumentExtractor.extractOption(named: "product").first else {
            throw Error.noTarget
        }
        var buildParameters = PackageManager.BuildParameters()
        buildParameters.logging = .verbose
        buildParameters.otherSwiftcFlags.append(contentsOf: [
            "-Xclang-linker", "-mexec-model=reactor"
        ])
        buildParameters.otherLinkerFlags.append(contentsOf: ["--export=main"])
        
        let result = try packageManager.build(.product(product), parameters: buildParameters)
        print(result.logText)
        if result.succeeded {
            print("Build Succeed: \(result.builtArtifacts)")
        }
    }
}
