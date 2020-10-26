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

import CoreFoundation
import CustomPathTarget
import Foundation
import JavaScriptKit
import TestLibrary
import WASILibc

let document = JSObject.global.document.object!

let button = document.createElement!("button").object!
button.innerText = .string("Crash!")
let body = document.body.object!
_ = body.appendChild!(button)

print("Number of seconds since epoch: \(Date().timeIntervalSince1970)")
print("cos(Double.pi) is \(cos(Double.pi))")
print(customTargetText)

func crash() {
  let x = [Any]()
  print(x[1])
}

let buttonNode = document.getElementsByTagName!("button").object![0].object!
let handler = JSClosure { _ -> () in
  print(text)
  crash()
}

buttonNode.onclick = .function(handler)

let div = document.createElement!("div").object!
div.innerHTML = .string(#"""
<a href=\#(Bundle.module.path(forResource: "data", ofType: "json")!)>Link to a static resource</a>
"""#)
_ = body.appendChild!(div)

let timerElement = document.createElement!("p").object!
_ = body.appendChild!(timerElement)
let timer = JSTimer(millisecondsDelay: 1000, isRepeating: true) {
  let date = JSDate()
  timerElement.innerHTML = .string("""
  <p>Current date is \(date.toLocaleDateString())</p>
  <p>Current time is \(date.toLocaleTimeString())</p>
  <p>Current <code>Date().timeIntervalSince1970</code> is \(Date().timeIntervalSince1970)</p>
  """)
}
