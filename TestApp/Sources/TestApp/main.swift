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

import CustomPathTarget
import Foundation
import JavaScriptKit
import TestLibrary
import WASILibc

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
