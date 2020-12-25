import TokamakDOM

struct TokamakApp: App {
  var body: some Scene {
    WindowGroup("Tokamak App") {
      ContentView()
    }
  }
}

struct ContentView: View {
  var body: some View {
    Text("Hello, world!")
  }
}

// @main attribute is not supported in SwiftPM apps.
// See https://bugs.swift.org/browse/SR-12683 for more details.
TokamakApp.main()
