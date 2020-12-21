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

import TSCBasic
import Vapor

enum HTMLError: String, Error {
  case customIndexPageWithoutHead = """
  The custom `index.html` page does not have a `<head></head>` element to allow entrypoint injection
  """
}

public struct HTML {
  let value: String
}

extension HTML: ResponseEncodable {
  public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
    var headers = HTTPHeaders()
    headers.add(name: .contentType, value: "text/html")
    return request.eventLoop.makeSucceededFuture(.init(
      status: .ok, headers: headers, body: .init(string: value)
    ))
  }

  public static func readCustomIndexPage(at path: String?,
                                         on fileSystem: FileSystem) throws -> String?
  {
    if let customIndexPage = path {
      let content = try localFileSystem.readFileContents(customIndexPage.isAbsolutePath ?
        AbsolutePath(customIndexPage) :
        AbsolutePath(localFileSystem.currentWorkingDirectory!, customIndexPage)).description

      guard content.contains("</head>") else {
        throw HTMLError.customIndexPageWithoutHead
      }

      return content
    } else {
      return nil
    }
  }

  public static func indexPage(customContent: String?, entrypointName: String) -> String {
    let scriptTag = #"<script type="text/javascript" src="\#(entrypointName)"></script>"#
    if let customContent = customContent {
      return customContent.replacingOccurrences(
        of: "</head>",
        with: "\(scriptTag)</head>"
      )
    }

    return #"""
    <html>
      <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          \#(scriptTag)
      </head>
      <body>
      </body>
    </html>
    """#
  }
}
