// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

@objc public extension Editor {
  func registerCommandObjC(_ commandName: String, priority: CommandPriority, block: @escaping ((_ payload: Any?) -> Bool)) -> () -> Void {

    return self.registerCommand(type: CommandType(rawValue: commandName), listener: {payload in
      return block(payload)
    }, priority: priority)
  }

  func getTextContentObjC() -> String {
    var text: String = ""
    try? self.read {
      text = getRoot()?.getTextContent() ?? ""
    }
    return text
  }
}
