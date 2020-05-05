import Vapor

struct Server {
  static func run() throws {
    var env = Environment.development
    try LoggingSystem.bootstrap(from: &env)
    let app = Application(env)
    defer { app.shutdown() }
    try configure(app)
    try app.run()
  }
}
