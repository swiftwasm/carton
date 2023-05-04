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

public enum DestinationEnvironment {
  case other
  case safari
  case firefox
  case chrome
  case edge
}

extension String {
  public func parsedStackTrace(in environment: DestinationEnvironment) -> [StackTraceItem]? {
    switch environment {
    case .safari: return safariStackTrace
    case .firefox: return firefoxStackTrace
    case .chrome: return chromeStackTrace
    case .edge: return chromeStackTrace  // TODO: return nil if on old Edge
    default: return nil
    }
  }
}
