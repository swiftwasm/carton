import Vapor

// configures your application
public func configure(_ app: Application) throws {
  let directory = app.directory.publicDirectory
  app.middleware.use(FileMiddleware(publicDirectory: directory))

  // register routes
  try routes(app)
}
