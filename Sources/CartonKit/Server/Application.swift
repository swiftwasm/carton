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

import CartonHelpers
import Foundation
import Logging
import NIO
import NIOHTTP1
import NIOWebSocket

extension Server {
  final class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    struct Configuration {
      let logger: Logger
      let mainWasmPath: AbsolutePath
      let customIndexPath: AbsolutePath?
      let resourcesPaths: [String]
      let entrypoint: Entrypoint
    }

    let configuration: Configuration
    private var responseBody: ByteBuffer!

    init(configuration: Configuration) {
      self.configuration = configuration
    }

    func handlerAdded(context: ChannelHandlerContext) {
    }

    func handlerRemoved(context: ChannelHandlerContext) {
      self.responseBody = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      let reqPart = self.unwrapInboundIn(data)

      // We're not interested in request bodies here
      guard case .head(let head) = reqPart else {
        return
      }

      // GETs only.
      guard case .GET = head.method else {
        self.respond405(context: context)
        return
      }
      configuration.logger.info("\(head.method) \(head.uri)")

      let response: StaticResponse
      do {
        switch head.uri {
        case "/":
          response = try respondIndexPage(context: context)
        case "/main.wasm":
          response = StaticResponse(
            contentType: "application/wasm",
            body: try context.channel.allocator.buffer(
              bytes: localFileSystem.readFileContents(configuration.mainWasmPath).contents
            )
          )
        default:
          guard let staticResponse = try self.respond(context: context, head: head) else {
            self.respond404(context: context)
            return
          }
          response = staticResponse
        }
      } catch {
        configuration.logger.error("Failed to respond to \(head.uri): \(error)")
        response = StaticResponse(
          contentType: "text/plain",
          body: context.channel.allocator.buffer(string: "Internal server error")
        )
      }
      self.responseBody = response.body

      var headers = HTTPHeaders()
      headers.add(name: "Content-Type", value: response.contentType)
      headers.add(name: "Content-Length", value: String(response.body.readableBytes))
      headers.add(name: "Connection", value: "close")
      let responseHead = HTTPResponseHead(
        version: .init(major: 1, minor: 1),
        status: .ok,
        headers: headers)
      context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
      context.write(self.wrapOutboundOut(.body(.byteBuffer(response.body))), promise: nil)
      context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
        context.close(promise: nil)
      }
      context.flush()
    }

    struct StaticResponse {
      let contentType: String
      let body: ByteBuffer
    }

    private func respond(context: ChannelHandlerContext, head: HTTPRequestHead) throws
      -> StaticResponse?
    {
      var responders = [
        self.makeStaticResourcesResponder(
          baseDirectory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".carton")
            .appendingPathComponent("static")
        )
      ]

      let buildDirectory = configuration.mainWasmPath.parentDirectory
      for directoryName in try localFileSystem.resourcesDirectoryNames(relativeTo: buildDirectory) {
        responders.append { context, uri in
          let parts = uri.split(separator: "/")
          guard let firstPart = parts.first,
            firstPart == directoryName
          else { return nil }
          let baseDir = URL(fileURLWithPath: buildDirectory.pathString).appendingPathComponent(
            directoryName
          )
          let inner = self.makeStaticResourcesResponder(baseDirectory: baseDir)
          return try inner(context, "/" + parts.dropFirst().joined(separator: "/"))
        }
      }

      // Serve resources for the main target at the root path.
      for mainResourcesPath in configuration.resourcesPaths {
        responders.append(
          self.makeStaticResourcesResponder(baseDirectory: URL(fileURLWithPath: mainResourcesPath)))
      }

      for responder in responders {
        if let response = try responder(context, head.uri) {
          return response
        }
      }
      return nil
    }

    private func makeStaticResourcesResponder(
      baseDirectory: URL
    ) -> (_ context: ChannelHandlerContext, _ uri: String) throws -> StaticResponse? {
      return { context, uri in
        assert(uri.first == "/")
        let fileURL = baseDirectory.appendingPathComponent(String(uri.dropFirst()))
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
          !isDir.boolValue
        else {
          return nil
        }
        let contentType = contentType(of: fileURL) ?? "application/octet-stream"

        return StaticResponse(
          contentType: contentType,
          body: try context.channel.allocator.buffer(bytes: Data(contentsOf: fileURL))
        )
      }
    }

    private func respondIndexPage(context: ChannelHandlerContext) throws -> StaticResponse {
      var customIndexContent: String?
      if let path = configuration.customIndexPath?.pathString {
        customIndexContent = try String(contentsOfFile: path)
      }
      let htmlContent = HTML.indexPage(
        customContent: customIndexContent,
        entrypointName: configuration.entrypoint.fileName
      )
      return StaticResponse(
        contentType: "text/html",
        body: context.channel.allocator.buffer(string: htmlContent)
      )
    }

    private func respond405(context: ChannelHandlerContext) {
      var headers = HTTPHeaders()
      headers.add(name: "Connection", value: "close")
      headers.add(name: "Content-Length", value: "0")
      let head = HTTPResponseHead(
        version: .http1_1,
        status: .methodNotAllowed,
        headers: headers)
      context.write(self.wrapOutboundOut(.head(head)), promise: nil)
      context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
        context.close(promise: nil)
      }
      context.flush()
    }

    private func respond404(context: ChannelHandlerContext) {
      var headers = HTTPHeaders()
      headers.add(name: "Connection", value: "close")
      headers.add(name: "Content-Length", value: "0")
      let head = HTTPResponseHead(
        version: .http1_1,
        status: .notFound,
        headers: headers)
      context.write(self.wrapOutboundOut(.head(head)), promise: nil)
      context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
        context.close(promise: nil)
      }
      context.flush()
    }
  }

  final class WebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    struct Configuration {
      let onText: @Sendable (String) -> Void
    }

    private var awaitingClose: Bool = false
    let configuration: Configuration

    init(configuration: Configuration) {
      self.configuration = configuration
    }

    public func handlerAdded(context: ChannelHandlerContext) {
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      let frame = self.unwrapInboundIn(data)

      switch frame.opcode {
      case .connectionClose:
        self.receivedClose(context: context, frame: frame)
      case .text:
        var data = frame.unmaskedData
        let text = data.readString(length: data.readableBytes) ?? ""
        self.configuration.onText(text)
      case .binary, .continuation, .pong:
        // We ignore these frames.
        break
      default:
        // Unknown frames are errors.
        self.closeOnError(context: context)
      }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
      context.flush()
    }

    private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
      if awaitingClose {
        context.close(promise: nil)
      } else {
        var data = frame.unmaskedData
        let closeDataCode = data.readSlice(length: 2) ?? ByteBuffer()
        let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: closeDataCode)
        _ = context.write(self.wrapOutboundOut(closeFrame)).map { () in
          context.close(promise: nil)
        }
      }
    }

    private func closeOnError(context: ChannelHandlerContext) {
      var data = context.channel.allocator.buffer(capacity: 2)
      data.write(webSocketErrorCode: .protocolError)
      let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
      context.write(self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
        context.close(mode: .output, promise: nil)
      }
      awaitingClose = true
    }
  }
}

extension ChannelHandlerContext: @unchecked Sendable {}

private func contentType(of filePath: URL) -> String? {
  // List of common MIME types derived from https://github.com/vapor/vapor/blob/4.92.5/Sources/Vapor/HTTP/Headers/HTTPMediaType.swift
  // License: MIT
  let typeByExtension = [
    "%": "application/x-trash",
    "323": "text/h323",
    "3gp": "video/3gpp",
    "7z": "application/x-7z-compressed",
    "abw": "application/x-abiword",
    "ai": "application/postscript",
    "aif": "audio/x-aiff",
    "aifc": "audio/x-aiff",
    "aiff": "audio/x-aiff",
    "alc": "chemical/x-alchemy",
    "amr": "audio/amr",
    "anx": "application/annodex",
    "apk": "application/vnd.android.package-archive",
    "appcache": "text/cache-manifest",
    "art": "image/x-jg",
    "asc": "text/plain",
    "asf": "video/x-ms-asf",
    "asn": "chemical/x-ncbi-asn1",
    "aso": "chemical/x-ncbi-asn1-binary",
    "asx": "video/x-ms-asf",
    "atom": "application/atom+xml",
    "atomcat": "application/atomcat+xml",
    "atomsrv": "application/atomserv+xml",
    "au": "audio/basic",
    "avi": "video/x-msvideo",
    "awb": "audio/amr-wb",
    "axa": "audio/annodex",
    "axv": "video/annodex",
    "b": "chemical/x-molconn-Z",
    "bak": "application/x-trash",
    "bat": "application/x-msdos-program",
    "bcpio": "application/x-bcpio",
    "bib": "text/x-bibtex",
    "bin": "application/octet-stream",
    "bmp": "image/x-ms-bmp",
    "boo": "text/x-boo",
    "book": "application/x-maker",
    "brf": "text/plain",
    "bsd": "chemical/x-crossfire",
    "c": "text/x-csrc",
    "c++": "text/x-c++src",
    "c3d": "chemical/x-chem3d",
    "cab": "application/x-cab",
    "cac": "chemical/x-cache",
    "cache": "chemical/x-cache",
    "cap": "application/vnd.tcpdump.pcap",
    "cascii": "chemical/x-cactvs-binary",
    "cat": "application/vnd.ms-pki.seccat",
    "cbin": "chemical/x-cactvs-binary",
    "cbr": "application/x-cbr",
    "cbz": "application/x-cbz",
    "cc": "text/x-c++src",
    "cda": "application/x-cdf",
    "cdf": "application/x-cdf",
    "cdr": "image/x-coreldraw",
    "cdt": "image/x-coreldrawtemplate",
    "cdx": "chemical/x-cdx",
    "cdy": "application/vnd.cinderella",
    "cef": "chemical/x-cxf",
    "cer": "chemical/x-cerius",
    "chm": "chemical/x-chemdraw",
    "chrt": "application/x-kchart",
    "cif": "chemical/x-cif",
    "class": "application/java-vm",
    "cls": "text/x-tex",
    "cmdf": "chemical/x-cmdf",
    "cml": "chemical/x-cml",
    "cod": "application/vnd.rim.cod",
    "com": "application/x-msdos-program",
    "cpa": "chemical/x-compass",
    "cpio": "application/x-cpio",
    "cpp": "text/x-c++src",
    "cpt": "application/mac-compactpro",
    "cr2": "image/x-canon-cr2",
    "crl": "application/x-pkcs7-crl",
    "crt": "application/x-x509-ca-cert",
    "crw": "image/x-canon-crw",
    "csd": "audio/csound",
    "csf": "chemical/x-cache-csf",
    "csh": "application/x-csh",
    "csm": "chemical/x-csml",
    "csml": "chemical/x-csml",
    "css": "text/css",
    "csv": "text/csv",
    "ctab": "chemical/x-cactvs-binary",
    "ctx": "chemical/x-ctx",
    "cu": "application/cu-seeme",
    "cub": "chemical/x-gaussian-cube",
    "cxf": "chemical/x-cxf",
    "cxx": "text/x-c++src",
    "d": "text/x-dsrc",
    "dat": "application/x-ns-proxy-autoconfig",
    "davmount": "application/davmount+xml",
    "dcm": "application/dicom",
    "dcr": "application/x-director",
    "deb": "application/x-debian-package",
    "dif": "video/dv",
    "diff": "text/x-diff",
    "dir": "application/x-director",
    "djv": "image/vnd.djvu",
    "djvu": "image/vnd.djvu",
    "dl": "video/dl",
    "dll": "application/x-msdos-program",
    "dmg": "application/x-apple-diskimage",
    "dms": "application/x-dms",
    "doc": "application/msword",
    "docm": "application/vnd.ms-word.document.macroEnabled.12",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "dot": "application/msword",
    "dotm": "application/vnd.ms-word.template.macroEnabled.12",
    "dotx": "application/vnd.openxmlformats-officedocument.wordprocessingml.template",
    "dv": "video/dv",
    "dvi": "application/x-dvi",
    "dx": "chemical/x-jcamp-dx",
    "dxr": "application/x-director",
    "emb": "chemical/x-embl-dl-nucleotide",
    "embl": "chemical/x-embl-dl-nucleotide",
    "eml": "message/rfc822",
    "ent": "chemical/x-ncbi-asn1-ascii",
    "eot": "application/vnd.ms-fontobject",
    "eps": "application/postscript",
    "eps2": "application/postscript",
    "eps3": "application/postscript",
    "epsf": "application/postscript",
    "epsi": "application/postscript",
    "erf": "image/x-epson-erf",
    "es": "application/ecmascript",
    "etx": "text/x-setext",
    "exe": "application/x-msdos-program",
    "ez": "application/andrew-inset",
    "fb": "application/x-maker",
    "fbdoc": "application/x-maker",
    "fch": "chemical/x-gaussian-checkpoint",
    "fchk": "chemical/x-gaussian-checkpoint",
    "fig": "application/x-xfig",
    "flac": "audio/flac",
    "fli": "video/fli",
    "flv": "video/x-flv",
    "fm": "application/x-maker",
    "frame": "application/x-maker",
    "frm": "application/x-maker",
    "gal": "chemical/x-gaussian-log",
    "gam": "chemical/x-gamess-input",
    "gamin": "chemical/x-gamess-input",
    "gan": "application/x-ganttproject",
    "gau": "chemical/x-gaussian-input",
    "gcd": "text/x-pcs-gcd",
    "gcf": "application/x-graphing-calculator",
    "gcg": "chemical/x-gcg8-sequence",
    "gen": "chemical/x-genbank",
    "gf": "application/x-tex-gf",
    "gif": "image/gif",
    "gjc": "chemical/x-gaussian-input",
    "gjf": "chemical/x-gaussian-input",
    "gl": "video/gl",
    "gnumeric": "application/x-gnumeric",
    "gpt": "chemical/x-mopac-graph",
    "gsf": "application/x-font",
    "gsm": "audio/x-gsm",
    "gtar": "application/x-gtar",
    "h": "text/x-chdr",
    "h++": "text/x-c++hdr",
    "hdf": "application/x-hdf",
    "hh": "text/x-c++hdr",
    "hin": "chemical/x-hin",
    "hpp": "text/x-c++hdr",
    "hqx": "application/mac-binhex40",
    "hs": "text/x-haskell",
    "hta": "application/hta",
    "htc": "text/x-component",
    "htm": "text/html",
    "html": "text/html",
    "hwp": "application/x-hwp",
    "hxx": "text/x-c++hdr",
    "ica": "application/x-ica",
    "ice": "x-conference/x-cooltalk",
    "ico": "image/vnd.microsoft.icon",
    "ics": "text/calendar",
    "icz": "text/calendar",
    "ief": "image/ief",
    "iges": "model/iges",
    "igs": "model/iges",
    "iii": "application/x-iphone",
    "info": "application/x-info",
    "inp": "chemical/x-gamess-input",
    "ins": "application/x-internet-signup",
    "iso": "application/x-iso9660-image",
    "isp": "application/x-internet-signup",
    "ist": "chemical/x-isostar",
    "istr": "chemical/x-isostar",
    "jad": "text/vnd.sun.j2me.app-descriptor",
    "jam": "application/x-jam",
    "jar": "application/java-archive",
    "java": "text/x-java",
    "jdx": "chemical/x-jcamp-dx",
    "jmz": "application/x-jmol",
    "jng": "image/x-jng",
    "jnlp": "application/x-java-jnlp-file",
    "jp2": "image/jp2",
    "jpe": "image/jpeg",
    "jpeg": "image/jpeg",
    "jpf": "image/jpx",
    "jpg": "image/jpeg",
    "jpg2": "image/jp2",
    "jpm": "image/jpm",
    "jpx": "image/jpx",
    "js": "application/javascript",
    "json": "application/json",
    "kar": "audio/midi",
    "key": "application/pgp-keys",
    "kil": "application/x-killustrator",
    "kin": "chemical/x-kinemage",
    "kml": "application/vnd.google-earth.kml+xml",
    "kmz": "application/vnd.google-earth.kmz",
    "kpr": "application/x-kpresenter",
    "kpt": "application/x-kpresenter",
    "ksp": "application/x-kspread",
    "kwd": "application/x-kword",
    "kwt": "application/x-kword",
    "latex": "application/x-latex",
    "lha": "application/x-lha",
    "lhs": "text/x-literate-haskell",
    "lin": "application/bbolin",
    "lsf": "video/x-la-asf",
    "lsx": "video/x-la-asf",
    "ltx": "text/x-tex",
    "ly": "text/x-lilypond",
    "lyx": "application/x-lyx",
    "lzh": "application/x-lzh",
    "lzx": "application/x-lzx",
    "m3g": "application/m3g",
    "m3u": "audio/mpegurl",
    "m3u8": "application/x-mpegURL",
    "m4a": "audio/mpeg",
    "maker": "application/x-maker",
    "man": "application/x-troff-man",
    "mbox": "application/mbox",
    "mcif": "chemical/x-mmcif",
    "mcm": "chemical/x-macmolecule",
    "md5": "application/x-md5",
    "mdb": "application/msaccess",
    "me": "application/x-troff-me",
    "mesh": "model/mesh",
    "mid": "audio/midi",
    "midi": "audio/midi",
    "mif": "application/x-mif",
    "mjs": "application/javascript",
    "mkv": "video/x-matroska",
    "mm": "application/x-freemind",
    "mmd": "chemical/x-macromodel-input",
    "mmf": "application/vnd.smaf",
    "mml": "text/mathml",
    "mmod": "chemical/x-macromodel-input",
    "mng": "video/x-mng",
    "moc": "text/x-moc",
    "mol": "chemical/x-mdl-molfile",
    "mol2": "chemical/x-mol2",
    "moo": "chemical/x-mopac-out",
    "mop": "chemical/x-mopac-input",
    "mopcrt": "chemical/x-mopac-input",
    "mov": "video/quicktime",
    "movie": "video/x-sgi-movie",
    "mp2": "audio/mpeg",
    "mp3": "audio/mpeg",
    "mp4": "video/mp4",
    "mpc": "chemical/x-mopac-input",
    "mpe": "video/mpeg",
    "mpeg": "video/mpeg",
    "mpega": "audio/mpeg",
    "mpg": "video/mpeg",
    "mpga": "audio/mpeg",
    "mph": "application/x-comsol",
    "mpv": "video/x-matroska",
    "ms": "application/x-troff-ms",
    "msh": "model/mesh",
    "msi": "application/x-msi",
    "mvb": "chemical/x-mopac-vib",
    "mxf": "application/mxf",
    "mxu": "video/vnd.mpegurl",
    "nb": "application/mathematica",
    "nbp": "application/mathematica",
    "nc": "application/x-netcdf",
    "nef": "image/x-nikon-nef",
    "nwc": "application/x-nwc",
    "o": "application/x-object",
    "oda": "application/oda",
    "odb": "application/vnd.oasis.opendocument.database",
    "odc": "application/vnd.oasis.opendocument.chart",
    "odf": "application/vnd.oasis.opendocument.formula",
    "odg": "application/vnd.oasis.opendocument.graphics",
    "odi": "application/vnd.oasis.opendocument.image",
    "odm": "application/vnd.oasis.opendocument.text-master",
    "odp": "application/vnd.oasis.opendocument.presentation",
    "ods": "application/vnd.oasis.opendocument.spreadsheet",
    "odt": "application/vnd.oasis.opendocument.text",
    "oga": "audio/ogg",
    "ogg": "audio/ogg",
    "ogv": "video/ogg",
    "ogx": "application/ogg",
    "old": "application/x-trash",
    "one": "application/onenote",
    "onepkg": "application/onenote",
    "onetmp": "application/onenote",
    "onetoc2": "application/onenote",
    "opus": "audio/ogg",
    "orc": "audio/csound",
    "orf": "image/x-olympus-orf",
    "otg": "application/vnd.oasis.opendocument.graphics-template",
    "oth": "application/vnd.oasis.opendocument.text-web",
    "otp": "application/vnd.oasis.opendocument.presentation-template",
    "ots": "application/vnd.oasis.opendocument.spreadsheet-template",
    "ott": "application/vnd.oasis.opendocument.text-template",
    "oza": "application/x-oz-application",
    "p": "text/x-pascal",
    "p7r": "application/x-pkcs7-certreqresp",
    "pac": "application/x-ns-proxy-autoconfig",
    "pas": "text/x-pascal",
    "pat": "image/x-coreldrawpattern",
    "patch": "text/x-diff",
    "pbm": "image/x-portable-bitmap",
    "pcap": "application/vnd.tcpdump.pcap",
    "pcf": "application/x-font",
    "pcf.Z": "application/x-font",
    "pcx": "image/pcx",
    "pdb": "chemical/x-pdb",
    "pdf": "application/pdf",
    "pfa": "application/x-font",
    "pfb": "application/x-font",
    "pgm": "image/x-portable-graymap",
    "pgn": "application/x-chess-pgn",
    "pgp": "application/pgp-encrypted",
    "pk": "application/x-tex-pk",
    "pl": "text/x-perl",
    "pls": "audio/x-scpls",
    "pm": "text/x-perl",
    "png": "image/png",
    "pnm": "image/x-portable-anymap",
    "pot": "text/plain",
    "potm": "application/vnd.ms-powerpoint.template.macroEnabled.12",
    "potx": "application/vnd.openxmlformats-officedocument.presentationml.template",
    "ppam": "application/vnd.ms-powerpoint.addin.macroEnabled.12",
    "ppm": "image/x-portable-pixmap",
    "pps": "application/vnd.ms-powerpoint",
    "ppsm": "application/vnd.ms-powerpoint.slideshow.macroEnabled.12",
    "ppsx": "application/vnd.openxmlformats-officedocument.presentationml.slideshow",
    "ppt": "application/vnd.ms-powerpoint",
    "pptm": "application/vnd.ms-powerpoint.presentation.macroEnabled.12",
    "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "prf": "application/pics-rules",
    "prt": "chemical/x-ncbi-asn1-ascii",
    "ps": "application/postscript",
    "psd": "image/x-photoshop",
    "py": "text/x-python",
    "pyc": "application/x-python-code",
    "pyo": "application/x-python-code",
    "qgs": "application/x-qgis",
    "qt": "video/quicktime",
    "qtl": "application/x-quicktimeplayer",
    "ra": "audio/x-pn-realaudio",
    "ram": "audio/x-pn-realaudio",
    "rar": "application/rar",
    "ras": "image/x-cmu-raster",
    "rb": "application/x-ruby",
    "rd": "chemical/x-mdl-rdfile",
    "rdf": "application/rdf+xml",
    "rdp": "application/x-rdp",
    "rgb": "image/x-rgb",
    "rm": "audio/x-pn-realaudio",
    "roff": "application/x-troff",
    "ros": "chemical/x-rosdal",
    "rpm": "application/x-redhat-package-manager",
    "rss": "application/x-rss+xml",
    "rtf": "application/rtf",
    "rtx": "text/richtext",
    "rxn": "chemical/x-mdl-rxnfile",
    "scala": "text/x-scala",
    "sce": "application/x-scilab",
    "sci": "application/x-scilab",
    "sco": "audio/csound",
    "scr": "application/x-silverlight",
    "sct": "text/scriptlet",
    "sd": "chemical/x-mdl-sdfile",
    "sd2": "audio/x-sd2",
    "sda": "application/vnd.stardivision.draw",
    "sdc": "application/vnd.stardivision.calc",
    "sdd": "application/vnd.stardivision.impress",
    "sdf": "application/vnd.stardivision.math",
    "sds": "application/vnd.stardivision.chart",
    "sdw": "application/vnd.stardivision.writer",
    "ser": "application/java-serialized-object",
    "sfv": "text/x-sfv",
    "sgf": "application/x-go-sgf",
    "sgl": "application/vnd.stardivision.writer-global",
    "sh": "application/x-sh",
    "sha1": "application/x-sha1",
    "shar": "application/x-shar",
    "shp": "application/x-qgis",
    "shtml": "text/html",
    "shx": "application/x-qgis",
    "sid": "audio/prs.sid",
    "sig": "application/pgp-signature",
    "sik": "application/x-trash",
    "silo": "model/mesh",
    "sis": "application/vnd.symbian.install",
    "sisx": "x-epoc/x-sisx-app",
    "sit": "application/x-stuffit",
    "sitx": "application/x-stuffit",
    "skd": "application/x-koan",
    "skm": "application/x-koan",
    "skp": "application/x-koan",
    "skt": "application/x-koan",
    "sldm": "application/vnd.ms-powerpoint.slide.macroEnabled.12",
    "sldx": "application/vnd.openxmlformats-officedocument.presentationml.slide",
    "smi": "application/smil+xml",
    "smil": "application/smil+xml",
    "snd": "audio/basic",
    "spc": "chemical/x-galactic-spc",
    "spl": "application/futuresplash",
    "spx": "audio/ogg",
    "sql": "application/x-sql",
    "src": "application/x-wais-source",
    "srt": "text/plain",
    "stc": "application/vnd.sun.xml.calc.template",
    "std": "application/vnd.sun.xml.draw.template",
    "sti": "application/vnd.sun.xml.impress.template",
    "stl": "application/sla",
    "stw": "application/vnd.sun.xml.writer.template",
    "sty": "text/x-tex",
    "sv4cpio": "application/x-sv4cpio",
    "sv4crc": "application/x-sv4crc",
    "svg": "image/svg+xml",
    "svgz": "image/svg+xml",
    "sw": "chemical/x-swissprot",
    "swf": "application/x-shockwave-flash",
    "swfl": "application/x-shockwave-flash",
    "sxc": "application/vnd.sun.xml.calc",
    "sxd": "application/vnd.sun.xml.draw",
    "sxg": "application/vnd.sun.xml.writer.global",
    "sxi": "application/vnd.sun.xml.impress",
    "sxm": "application/vnd.sun.xml.math",
    "sxw": "application/vnd.sun.xml.writer",
    "t": "application/x-troff",
    "tar": "application/x-tar",
    "taz": "application/x-gtar-compressed",
    "tcl": "application/x-tcl",
    "tex": "text/x-tex",
    "texi": "application/x-texinfo",
    "texinfo": "application/x-texinfo",
    "text": "text/plain",
    "tgf": "chemical/x-mdl-tgf",
    "tgz": "application/x-gtar-compressed",
    "thmx": "application/vnd.ms-officetheme",
    "tif": "image/tiff",
    "tiff": "image/tiff",
    "tk": "text/x-tcl",
    "tm": "text/texmacs",
    "torrent": "application/x-bittorrent",
    "tr": "application/x-troff",
    "ts": "video/MP2T",
    "tsp": "application/dsptype",
    "tsv": "text/tab-separated-values",
    "ttl": "text/turtle",
    "txt": "text/plain",
    "udeb": "application/x-debian-package",
    "uls": "text/iuls",
    "ustar": "application/x-ustar",
    "val": "chemical/x-ncbi-asn1-binary",
    "vcd": "application/x-cdlink",
    "vcf": "text/x-vcard",
    "vcs": "text/x-vcalendar",
    "vmd": "chemical/x-vmd",
    "vms": "chemical/x-vamas-iso14976",
    "vrm": "x-world/x-vrml",
    "vrml": "model/vrml",
    "vsd": "application/vnd.visio",
    "wad": "application/x-doom",
    "wasm": "application/wasm",
    "wav": "audio/x-wav",
    "wax": "audio/x-ms-wax",
    "wbmp": "image/vnd.wap.wbmp",
    "wbxml": "application/vnd.wap.wbxml",
    "webm": "video/webm",
    "wk": "application/x-123",
    "wm": "video/x-ms-wm",
    "wma": "audio/x-ms-wma",
    "wmd": "application/x-ms-wmd",
    "wml": "text/vnd.wap.wml",
    "wmlc": "application/vnd.wap.wmlc",
    "wmls": "text/vnd.wap.wmlscript",
    "wmlsc": "application/vnd.wap.wmlscriptc",
    "wmv": "video/x-ms-wmv",
    "wmx": "video/x-ms-wmx",
    "wmz": "application/x-ms-wmz",
    "woff": "application/x-font-woff",
    "wp5": "application/vnd.wordperfect5.1",
    "wpd": "application/vnd.wordperfect",
    "wrl": "model/vrml",
    "wsc": "text/scriptlet",
    "wvx": "video/x-ms-wvx",
    "wz": "application/x-wingz",
    "x3d": "model/x3d+xml",
    "x3db": "model/x3d+binary",
    "x3dv": "model/x3d+vrml",
    "xbm": "image/x-xbitmap",
    "xcf": "application/x-xcf",
    "xcos": "application/x-scilab-xcos",
    "xht": "application/xhtml+xml",
    "xhtml": "application/xhtml+xml",
    "xlam": "application/vnd.ms-excel.addin.macroEnabled.12",
    "xlb": "application/vnd.ms-excel",
    "xls": "application/vnd.ms-excel",
    "xlsb": "application/vnd.ms-excel.sheet.binary.macroEnabled.12",
    "xlsm": "application/vnd.ms-excel.sheet.macroEnabled.12",
    "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "xlt": "application/vnd.ms-excel",
    "xltm": "application/vnd.ms-excel.template.macroEnabled.12",
    "xltx": "application/vnd.openxmlformats-officedocument.spreadsheetml.template",
    "xml": "application/xml",
    "xpi": "application/x-xpinstall",
    "xpm": "image/x-xpixmap",
    "xsd": "application/xml",
    "xsl": "application/xslt+xml",
    "xslt": "application/xslt+xml",
    "xspf": "application/xspf+xml",
    "xtel": "chemical/x-xtel",
    "xul": "application/vnd.mozilla.xul+xml",
    "xwd": "image/x-xwindowdump",
    "xyz": "chemical/x-xyz",
    "zip": "application/zip",
    "zmt": "chemical/x-mopac-input",
    "~": "application/x-trash",
  ]
  return typeByExtension[filePath.pathExtension]
}
