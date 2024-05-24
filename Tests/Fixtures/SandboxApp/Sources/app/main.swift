#if os(WASI)
import WASILibc
typealias FILEPointer = OpaquePointer
#else
import Darwin
typealias FILEPointer = UnsafeMutablePointer<FILE>
#endif

import JavaScriptKit

func fputs(_ string: String, file: FILEPointer) {
    _ = string.withCString { (cstr) in
        fputs(cstr, file)
    }
}

fputs("hello stdout\n", file: stdout)
fputs("hello stderr\n", file: stderr)

fatalError("hello fatalError")

let document = JSObject.global.document

let button = document.createElement("button")
_ = button.appendChild(
  document.createTextNode("click to crash")
)

_ = button.addEventListener("click", JSClosure { (e) in
  fatalError("crash")
})

_ = document.body.appendChild(button)
