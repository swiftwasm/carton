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

final class StackTraceTests: XCTestCase {
  func testFirefoxStackTrace() {
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

    XCTAssertEqual(
      stackTrace,
      [
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
    )
  }
}
