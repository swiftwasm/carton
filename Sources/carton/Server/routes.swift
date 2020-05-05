import HypertextLiteral
import Vapor

func routes(_ app: Application) throws {
  app.get { _ -> HTML in
    #"""
    <html>
      <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <script src="index.js"></script>
      </head>
      <body>
          <h1>Hello!</h1>
      </body>
    </html>
    """#
  }
}
