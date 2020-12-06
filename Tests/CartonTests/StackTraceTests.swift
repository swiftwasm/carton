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
//
//  Created by Max Desiatov on 08/11/2020.
//

@testable import CartonHelpers
import XCTest

final class StackTraceTests: XCTestCase {}
extension StackTraceTests {
  func testFirefoxStackTrace() {
    // swiftlint:disable line_length
    let stackTrace = """
    wasmFs.fs.writeSync@webpack:///./entrypoint/dev.js?:35:21
    a/this.wasiImport.fd_write</<@webpack:///./node_modules/@wasmer/wasi/lib/index.esm.js?:115:429
    a/this.wasiImport.fd_write<@webpack:///./node_modules/@wasmer/wasi/lib/index.esm.js?:115:372
    Z/<@webpack:///./node_modules/@wasmer/wasi/lib/index.esm.js?:102:271
    write@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[62062]:0x12af331
    swift_reportError@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[21654]:0x37c242
    _swift_stdlib_reportFatalErrorInFile@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[22950]:0x3e2996
    $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtFySRys5UInt8VGXEfU_yAMXEfU_@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[3635]:0xd717d
    $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtFySRys5UInt8VGXEfU_Tm@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[3636]:0xd7374
    $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtF@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[2752]:0xa7917
    $sSayxSicig@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[2982]:0xb34da
    $s7TestApp5crashyyF@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[1372]:0x8012c
    $s7TestAppySay13JavaScriptKit7JSValueOGcfU_@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[1367]:0x7f4e7
    $s13JavaScriptKit9JSClosureCyACySayAA7JSValueOGccfcAeFcfU_@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[787]:0x5003b
    $s13JavaScriptKit9JSClosureCyACySayAA7JSValueOGccfcAeFcfU_TA@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[786]:0x4ff96
    $sSay13JavaScriptKit7JSValueOGACIeggo_AdCIegnr_TR@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[783]:0x4fe00
    $sSay13JavaScriptKit7JSValueOGACIeggo_AdCIegnr_TRTA@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[782]:0x4fdc8
    $sSay13JavaScriptKit7JSValueOGACIegnr_AdCIeggo_TR@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[812]:0x52ddd
    $sSay13JavaScriptKit7JSValueOGACIegnr_AdCIeggo_TRTA@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[802]:0x529bc
    $s13JavaScriptKit24_call_host_function_implyys6UInt32V_SPySo10RawJSValueaGs5Int32VADtF@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[801]:0x525e8
    _call_host_function_impl@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[800]:0x52158
    _call_host_function@http://127.0.0.1:8080/dev.js line 97 > eval line 58 > WebAssembly.instantiate:wasm-function[1388]:0x814d3
    callHostFunction@webpack:///./node_modules/javascript-kit-swift/Runtime/lib/index.js?:110:21
    swjs_create_function/func_ref<@webpack:///./node_modules/javascript-kit-swift/Runtime/lib/index.js?:280:28
    """.firefoxStackTrace

    let expected: [StackTraceItem] = [
      .init(
        symbol: "wasmFs.fs.writeSync",
        location: "./entrypoint/dev.js?:35:21",
        kind: .javaScript
      ),
      .init(
        symbol: "a/this.wasiImport.fd_write</<",
        location: "./node_modules/@wasmer/wasi/lib/index.esm.js?:115:429",
        kind: .javaScript
      ),
      .init(
        symbol: "a/this.wasiImport.fd_write<",
        location: "./node_modules/@wasmer/wasi/lib/index.esm.js?:115:372",
        kind: .javaScript
      ),
      .init(
        symbol: "Z/<",
        location: "./node_modules/@wasmer/wasi/lib/index.esm.js?:102:271",
        kind: .javaScript
      ),
      .init(
        symbol: "write",
        location: "wasm-function[62062]:0x12af331",
        kind: .webAssembly
      ), .init(
        symbol: "swift_reportError",
        location: "wasm-function[21654]:0x37c242",
        kind: .webAssembly
      ), .init(
        symbol: "_swift_stdlib_reportFatalErrorInFile",
        location: "wasm-function[22950]:0x3e2996",
        kind: .webAssembly
      ), .init(
        symbol: "closure #1 (UnsafeBufferPointer<UInt8>) -> () in closure #1 (UnsafeBufferPointer<UInt8>) -> () in _assertionFailure(_: StaticString, _: StaticString, file: StaticString, line: UInt, flags: UInt32) -> Never",
        location: "wasm-function[3635]:0xd717d",
        kind: .webAssembly
      ), .init(
        symbol: "merged closure #1 (UnsafeBufferPointer<UInt8>) -> () in _assertionFailure(_: StaticString, _: StaticString, file: StaticString, line: UInt, flags: UInt32) -> Never",
        location: "wasm-function[3636]:0xd7374",
        kind: .webAssembly
      ), .init(
        symbol: "Swift._assertionFailure(_: StaticString, _: StaticString, file: StaticString, line: UInt, flags: UInt32) -> Never",
        location: "wasm-function[2752]:0xa7917",
        kind: .webAssembly
      ), .init(
        symbol: "Swift.Array.subscript.getter : (Int) -> A",
        location: "wasm-function[2982]:0xb34da",
        kind: .webAssembly
      ), .init(
        symbol: "TestApp.crash() -> ()",
        location: "wasm-function[1372]:0x8012c",
        kind: .webAssembly
      ), .init(
        symbol: "closure #1 (Array<JavaScriptKit.JSValue>) -> () in TestApp",
        location: "wasm-function[1367]:0x7f4e7",
        kind: .webAssembly
      ), .init(
        symbol: "closure #1 (Array<JavaScriptKit.JSValue>) -> JavaScriptKit.JSValue in JavaScriptKit.JSClosure.init((Array<JavaScriptKit.JSValue>) -> ()) -> JavaScriptKit.JSClosure",
        location: "wasm-function[787]:0x5003b",
        kind: .webAssembly
      ), .init(
        symbol: "partial apply forwarder for closure #1 (Array<JavaScriptKit.JSValue>) -> JavaScriptKit.JSValue in JavaScriptKit.JSClosure.init((Array<JavaScriptKit.JSValue>) -> ()) -> JavaScriptKit.JSClosure",
        location: "wasm-function[786]:0x4ff96",
        kind: .webAssembly
      ), .init(
        symbol: "reabstraction thunk helper from @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue)",
        location: "wasm-function[783]:0x4fe00",
        kind: .webAssembly
      ), .init(
        symbol: "partial apply forwarder for reabstraction thunk helper from @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue)",
        location: "wasm-function[782]:0x4fdc8",
        kind: .webAssembly
      ), .init(
        symbol: "reabstraction thunk helper from @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue)",
        location: "wasm-function[812]:0x52ddd",
        kind: .webAssembly
      ), .init(
        symbol: "partial apply forwarder for reabstraction thunk helper from @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue)",
        location: "wasm-function[802]:0x529bc",
        kind: .webAssembly
      ), .init(
        symbol: "JavaScriptKit._call_host_function_impl(UInt32, UnsafePointer<__C.RawJSValue>, Int32, UInt32) -> ()",
        location: "wasm-function[801]:0x525e8",
        kind: .webAssembly
      ), .init(
        symbol: "_call_host_function_impl",
        location: "wasm-function[800]:0x52158",
        kind: .webAssembly
      ), .init(
        symbol: "_call_host_function",
        location: "wasm-function[1388]:0x814d3",
        kind: .webAssembly
      ), .init(
        symbol: "callHostFunction",
        location: "./node_modules/javascript-kit-swift/Runtime/lib/index.js?:110:21",
        kind: .javaScript
      ), .init(
        symbol: "swjs_create_function/func_ref<",
        location: "./node_modules/javascript-kit-swift/Runtime/lib/index.js?:280:28",
        kind: .javaScript
      ),
    ]
    XCTAssertEqual(stackTrace, expected)
  }
}
extension StackTraceTests {
  func testSafariStackTrace() {
    // swiftlint:disable line_length
    let stackTrace = """
    forEach@[native code]


    wasm-stub@[wasm code]
    <?>.wasm-function[write]@[wasm code]
    <?>.wasm-function[swift_reportError]@[wasm code]
    <?>.wasm-function[_swift_stdlib_reportFatalErrorInFile]@[wasm code]
    <?>.wasm-function[$ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtFySRys5UInt8VGXEfU_yAMXEfU_]@[wasm code]
    <?>.wasm-function[$ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtFySRys5UInt8VGXEfU_Tm]@[wasm code]
    <?>.wasm-function[$ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtF]@[wasm code]
    <?>.wasm-function[$sSayxSicig]@[wasm code]
    <?>.wasm-function[$s7TestApp5crashyyF]@[wasm code]
    <?>.wasm-function[$s7TestAppySay13JavaScriptKit7JSValueOGcfU_]@[wasm code]
    <?>.wasm-function[$s13JavaScriptKit9JSClosureCyACySayAA7JSValueOGccfcAeFcfU_]@[wasm code]
    <?>.wasm-function[$s13JavaScriptKit9JSClosureCyACySayAA7JSValueOGccfcAeFcfU_TA]@[wasm code]
    <?>.wasm-function[$sSay13JavaScriptKit7JSValueOGACIeggo_AdCIegnr_TR]@[wasm code]
    <?>.wasm-function[$sSay13JavaScriptKit7JSValueOGACIeggo_AdCIegnr_TRTA]@[wasm code]
    <?>.wasm-function[$sSay13JavaScriptKit7JSValueOGACIegnr_AdCIeggo_TR]@[wasm code]
    <?>.wasm-function[$sSay13JavaScriptKit7JSValueOGACIegnr_AdCIeggo_TRTA]@[wasm code]
    <?>.wasm-function[$s13JavaScriptKit24_call_host_function_implyys6UInt32V_SPySo10RawJSValueaGs5Int32VADtF]@[wasm code]
    <?>.wasm-function[_call_host_function_impl]@[wasm code]
    <?>.wasm-function[_call_host_function]@[wasm code]
    wasm-stub@[wasm code]
    swjs_call_host_function@[native code]
    callHostFunction
    """.safariStackTrace

    let expected: [StackTraceItem] =
      [
//        .init(
//          symbol: "wasmFs.fs.writeSync",
//          location: "./entrypoint/dev.js?:35:21",
//          kind: .javaScript
//        ),
//        .init(
//          symbol: "a/this.wasiImport.fd_write</<",
//          location: "./node_modules/@wasmer/wasi/lib/index.esm.js?:115:429",
//          kind: .javaScript
//        ),
//        .init(
//          symbol: "a/this.wasiImport.fd_write<",
//          location: "./node_modules/@wasmer/wasi/lib/index.esm.js?:115:372",
//          kind: .javaScript
//        ),
//        .init(
//          symbol: "Z/<",
//          location: "./node_modules/@wasmer/wasi/lib/index.esm.js?:102:271",
//          kind: .javaScript
//        ),
//        .init(
//          symbol: "write",
//          location: "wasm-function[62062]:0x12af331",
//          kind: .webAssembly
//        ), .init(
//          symbol: "swift_reportError",
//          location: "wasm-function[21654]:0x37c242",
//          kind: .webAssembly
//        ), .init(
//          symbol: "_swift_stdlib_reportFatalErrorInFile",
//          location: "wasm-function[22950]:0x3e2996",
//          kind: .webAssembly
//        ),
        .init(
          symbol: "forEach",
          location: nil,
          kind: .javaScript
        ), .init(
          symbol: "wasm-stub",
          location: nil,
          kind: .javaScript
        ), .init(
          symbol: "write",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "swift_reportError",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "_swift_stdlib_reportFatalErrorInFile",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "closure #1 (UnsafeBufferPointer<UInt8>) -> () in closure #1 (UnsafeBufferPointer<UInt8>) -> () in _assertionFailure(_: StaticString, _: StaticString, file: StaticString, line: UInt, flags: UInt32) -> Never",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "merged closure #1 (UnsafeBufferPointer<UInt8>) -> () in _assertionFailure(_: StaticString, _: StaticString, file: StaticString, line: UInt, flags: UInt32) -> Never",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "Swift._assertionFailure(_: StaticString, _: StaticString, file: StaticString, line: UInt, flags: UInt32) -> Never",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "Swift.Array.subscript.getter : (Int) -> A",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "TestApp.crash() -> ()",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "closure #1 (Array<JavaScriptKit.JSValue>) -> () in TestApp",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "closure #1 (Array<JavaScriptKit.JSValue>) -> JavaScriptKit.JSValue in JavaScriptKit.JSClosure.init((Array<JavaScriptKit.JSValue>) -> ()) -> JavaScriptKit.JSClosure",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "partial apply forwarder for closure #1 (Array<JavaScriptKit.JSValue>) -> JavaScriptKit.JSValue in JavaScriptKit.JSClosure.init((Array<JavaScriptKit.JSValue>) -> ()) -> JavaScriptKit.JSClosure",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "reabstraction thunk helper from @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue)",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "partial apply forwarder for reabstraction thunk helper from @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue)",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "reabstraction thunk helper from @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue)",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "partial apply forwarder for reabstraction thunk helper from @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue)",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "JavaScriptKit._call_host_function_impl(UInt32, UnsafePointer<__C.RawJSValue>, Int32, UInt32) -> ()",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "_call_host_function_impl",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "_call_host_function",
          location: nil,
          kind: .webAssembly
        ), .init(
          symbol: "wasm-stub",
          location: nil,
          kind: .javaScript
        ), .init(
          symbol: "swjs_call_host_function",
          location: nil,
          kind: .javaScript
        ), .init(
          symbol: "callHostFunction",
          location: nil,
          kind: .javaScript
        ),
//        .init(
//          symbol: "swjs_create_function/func_ref<",
//          location: nil,
//          kind: .javaScript
//        ),
      ]
    XCTAssertEqual(stackTrace, expected)
  }
}
extension StackTraceTests {
  func testChromeStackTrace() {
    // swiftlint:disable line_length
    let stackTrace = """
    Error
        at Object.wasmFs.fs.writeSync (webpack:///./entrypoint/dev.js?:54:25)
        at eval (webpack:///./node_modules/@wasmer/wasi/lib/index.esm.js?:115:429)
        at Array.forEach (<anonymous>)
        at eval (webpack:///./node_modules/@wasmer/wasi/lib/index.esm.js?:115:372)
        at eval (webpack:///./node_modules/@wasmer/wasi/lib/index.esm.js?:102:271)
        at write (<anonymous>:wasm-function[62105]:0x12b19bc)
        at swift_reportError (<anonymous>:wasm-function[21697]:0x37e8aa)
        at _swift_stdlib_reportFatalErrorInFile (<anonymous>:wasm-function[22993]:0x3e4ffe)
        at $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtFySRys5UInt8VGXEfU_yAMXEfU_ (<anonymous>:wasm-function[3676]:0xd96fc)
        at $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtFySRys5UInt8VGXEfU_Tm (<anonymous>:wasm-function[3677]:0xd98f3)
        at $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtF (<anonymous>:wasm-function[2793]:0xa9f38)
        at $sSayxSicig (<anonymous>:wasm-function[3023]:0xb5afb)
        at $s7TestApp5crashyyF (<anonymous>:wasm-function[1413]:0x8274d)
        at $s7TestAppySay13JavaScriptKit7JSValueOGcfU_ (<anonymous>:wasm-function[1408]:0x81b08)
        at $s13JavaScriptKit9JSClosureCyACySayAA7JSValueOGccfcAeFcfU_ (<anonymous>:wasm-function[816]:0x51881)
        at $s13JavaScriptKit9JSClosureCyACySayAA7JSValueOGccfcAeFcfU_TA (<anonymous>:wasm-function[815]:0x517dc)
        at $sSay13JavaScriptKit7JSValueOGACIeggo_AdCIegnr_TR (<anonymous>:wasm-function[812]:0x51646)
        at $sSay13JavaScriptKit7JSValueOGACIeggo_AdCIegnr_TRTA (<anonymous>:wasm-function[811]:0x5160e)
        at $sSay13JavaScriptKit7JSValueOGACIegnr_AdCIeggo_TR (<anonymous>:wasm-function[839]:0x54566)
        at $sSay13JavaScriptKit7JSValueOGACIegnr_AdCIeggo_TRTA (<anonymous>:wasm-function[831]:0x54202)
        at $s13JavaScriptKit24_call_host_function_implyys6UInt32V_SPySo10RawJSValueaGs5Int32VADtF (<anonymous>:wasm-function[830]:0x53e2e)
        at _call_host_function_impl (<anonymous>:wasm-function[829]:0x5399e)
        at _call_host_function (<anonymous>:wasm-function[1429]:0x83af4)
        at callHostFunction (webpack:///./node_modules/javascript-kit-swift/Runtime/lib/index.js?:110:21)
        at HTMLButtonElement.eval (webpack:///./node_modules/javascript-kit-swift/Runtime/lib/index.js?:295:28)
    """.chromeStackTrace

    let expected: [StackTraceItem] =
      [
        .init(
          symbol: "Object.wasmFs.fs.writeSync",
          location: "./entrypoint/dev.js?:54:25",
          kind: .javaScript
        ),
        .init(
          symbol: "eval",
          location: "./node_modules/@wasmer/wasi/lib/index.esm.js?:115:429",
          kind: .javaScript
        ),
        .init(
          symbol: "eval",
          location: "./node_modules/@wasmer/wasi/lib/index.esm.js?:115:372",
          kind: .javaScript
        ),
        .init(
          symbol: "eval",
          location: "./node_modules/@wasmer/wasi/lib/index.esm.js?:102:271",
          kind: .javaScript
        ),
        .init(
          symbol: "write",
          location: "wasm-function[62105]:0x12b19bc",
          kind: .webAssembly
        ), .init(
          symbol: "swift_reportError",
          location: "wasm-function[21697]:0x37e8aa",
          kind: .webAssembly
        ), .init(
          symbol: "_swift_stdlib_reportFatalErrorInFile",
          location: "wasm-function[22993]:0x3e4ffe",
          kind: .webAssembly
        ), .init(
          symbol: "closure #1 (UnsafeBufferPointer<UInt8>) -> () in closure #1 (UnsafeBufferPointer<UInt8>) -> () in _assertionFailure(_: StaticString, _: StaticString, file: StaticString, line: UInt, flags: UInt32) -> Never",
          location: "wasm-function[3676]:0xd96fc",
          kind: .webAssembly
        ), .init(
          symbol: "merged closure #1 (UnsafeBufferPointer<UInt8>) -> () in _assertionFailure(_: StaticString, _: StaticString, file: StaticString, line: UInt, flags: UInt32) -> Never",
          location: "wasm-function[3677]:0xd98f3",
          kind: .webAssembly
        ), .init(
          symbol: "Swift._assertionFailure(_: StaticString, _: StaticString, file: StaticString, line: UInt, flags: UInt32) -> Never",
          location: "wasm-function[2793]:0xa9f38",
          kind: .webAssembly
        ), .init(
          symbol: "Swift.Array.subscript.getter : (Int) -> A",
          location: "wasm-function[3023]:0xb5afb",
          kind: .webAssembly
        ), .init(
          symbol: "TestApp.crash() -> ()",
          location: "wasm-function[1413]:0x8274d",
          kind: .webAssembly
        ), .init(
          symbol: "closure #1 (Array<JavaScriptKit.JSValue>) -> () in TestApp",
          location: "wasm-function[1408]:0x81b08",
          kind: .webAssembly
        ), .init(
          symbol: "closure #1 (Array<JavaScriptKit.JSValue>) -> JavaScriptKit.JSValue in JavaScriptKit.JSClosure.init((Array<JavaScriptKit.JSValue>) -> ()) -> JavaScriptKit.JSClosure",
          location: "wasm-function[816]:0x51881",
          kind: .webAssembly
        ), .init(
          symbol: "partial apply forwarder for closure #1 (Array<JavaScriptKit.JSValue>) -> JavaScriptKit.JSValue in JavaScriptKit.JSClosure.init((Array<JavaScriptKit.JSValue>) -> ()) -> JavaScriptKit.JSClosure",
          location: "wasm-function[815]:0x517dc",
          kind: .webAssembly
        ), .init(
          symbol: "reabstraction thunk helper from @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue)",
          location: "wasm-function[812]:0x51646",
          kind: .webAssembly
        ), .init(
          symbol: "partial apply forwarder for reabstraction thunk helper from @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue)",
          location: "wasm-function[811]:0x5160e",
          kind: .webAssembly
        ), .init(
          symbol: "reabstraction thunk helper from @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue)",
          location: "wasm-function[839]:0x54566",
          kind: .webAssembly
        ), .init(
          symbol: "partial apply forwarder for reabstraction thunk helper from @escaping @callee_guaranteed (@in_guaranteed Array<JavaScriptKit.JSValue>) -> (@out JavaScriptKit.JSValue) to @escaping @callee_guaranteed (@guaranteed Array<JavaScriptKit.JSValue>) -> (@owned JavaScriptKit.JSValue)",
          location: "wasm-function[831]:0x54202",
          kind: .webAssembly
        ), .init(
          symbol: "JavaScriptKit._call_host_function_impl(UInt32, UnsafePointer<__C.RawJSValue>, Int32, UInt32) -> ()",
          location: "wasm-function[830]:0x53e2e",
          kind: .webAssembly
        ), .init(
          symbol: "_call_host_function_impl",
          location: "wasm-function[829]:0x5399e",
          kind: .webAssembly
        ), .init(
          symbol: "_call_host_function",
          location: "wasm-function[1429]:0x83af4",
          kind: .webAssembly
        ), .init(
          symbol: "callHostFunction",
          location: "./node_modules/javascript-kit-swift/Runtime/lib/index.js?:110:21",
          kind: .javaScript
        ), .init(
          symbol: "HTMLButtonElement.eval",
          location: "./node_modules/javascript-kit-swift/Runtime/lib/index.js?:295:28",
          kind: .javaScript
        ),
      ]
    XCTAssertEqual(stackTrace, expected)
  }
}
