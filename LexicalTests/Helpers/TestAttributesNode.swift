// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation
import Lexical

/// TestAttributesNode class has been added for unit tests
class TestAttributesNode: ElementNode {
  override required init() {
    super.init()
    self.type = NodeType(rawValue: "TestNode")
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
    self.type = NodeType(rawValue: "TestNode")
  }

  override open func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    var attributeDictionary = super.getAttributedStringAttributes(theme: theme)
    attributeDictionary[.fontFamily] = "Arial"
    attributeDictionary[.fontSize] = 10 as Float
    attributeDictionary[.bold] = true

    return attributeDictionary
  }

  override public func clone() -> Self {
    Self()
  }
}
