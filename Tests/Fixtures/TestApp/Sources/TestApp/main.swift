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

import _Differentiation
import CoreFoundation
import CustomPathTarget
import Foundation
import JavaScriptKit
import TestLibrary
import WASILibc

// extension SIMD
//   where
//   Self: Differentiable,
//   TangentVector: SIMD,
//   Scalar: BinaryFloatingPoint & Differentiable,
//   Scalar.TangentVector: BinaryFloatingPoint,
//   TangentVector == Self
// {
//   @inlinable
//   @derivative(of: sum)
//   func _vjpSum() -> (
//     value: Scalar, pullback: (Scalar.TangentVector) -> TangentVector
//   ) {
//     return (sum(), { v in Self(repeating: Scalar(v)) })
//   }

//   @inlinable
//   @derivative(of: sum)
//   func _jvpSum() -> (
//     value: Scalar, differential: (TangentVector) -> Scalar.TangentVector
//   ) {
//     return (sum(), { v in Scalar.TangentVector(v.sum()) })
//   }
// }

// struct Perceptron: Differentiable {
//   var weight: SIMD2<Float> = .random(in: -1..<1)
//   var bias: Float = 0

//   func callAsFunction(_ input: SIMD2<Float>) -> Float {
//     (weight * input).sum() + bias
//   }
// }

// var model = Perceptron()
// let andGateData: [(x: SIMD2<Float>, y: Float)] = [
//   (x: [0, 0], y: 0),
//   (x: [0, 1], y: 0),
//   (x: [1, 0], y: 0),
//   (x: [1, 1], y: 1),
// ]
// for _ in 0..<100 {
//   let (loss, modelGradient) = valueWithGradient(at: model) { model -> Float in
//     var loss: Float = 0
//     for (x, y) in andGateData {
//       let prediction = model(x)
//       let error = y - prediction
//       loss = loss + error * error / 2
//     }
//     return loss
//   }
//   print(loss)
//   model.weight -= modelGradient.weight * 0.02
//   model.bias -= modelGradient.bias * 0.02
// }

// let model = Model(w: 4, b: 3)
// let input: Float = 2
// let (_model, _input) = gradient(at: model, input) { model, input in model.applied(to: input) }
// print(_model)
// print(_input)

let document = JSObject.global.document

var button = document.createElement("button")
button.innerText = .string("Crash!")
_ = document.body.appendChild(button)

print("Number of seconds since epoch: \(Date().timeIntervalSince1970)")
print("cos(Double.pi) is \(cos(Double.pi))")
print(customTargetText)

func crash() {
  let x = [Any]()
  print(x[1])
}

var buttonNode = document.getElementsByTagName("button")[0]
let handler = JSClosure { _ -> () in
  print(text)
  crash()
}

buttonNode.onclick = .function(handler)

var div = document.createElement("div")
div.innerHTML = .string(#"""
<a href=\#(Bundle.module.path(forResource: "data", ofType: "json")!)>Link to a static resource</a>
<br/>
<a href=\#(Bundle.main
  .path(forResource: "data", ofType: "json")!)>Link to a <code>Bundle.main</code> resource</a>
"""#)
_ = document.body.appendChild(div)

var timerElement = document.createElement("p")
_ = document.body.appendChild(timerElement)
let timer = JSTimer(millisecondsDelay: 1000, isRepeating: true) {
  let date = JSDate()
  timerElement.innerHTML = .string("""
  <p>Current date is \(date.toLocaleDateString())</p>
  <p>Current time is \(date.toLocaleTimeString())</p>
  <p>Current <code>Date().timeIntervalSince1970</code> is \(Date().timeIntervalSince1970)</p>
  """)
}
