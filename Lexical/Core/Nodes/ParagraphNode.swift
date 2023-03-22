// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import UIKit

public class ParagraphNode: ElementNode {
  override public init() {
    super.init()
    self.type = NodeType.paragraph
  }

  override required init(_ key: NodeKey?) {
    super.init(key)
    self.type = NodeType.paragraph
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
    self.type = NodeType.paragraph
  }

  override public func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
  }

  override public func clone() -> Self {
    Self(key)
  }

  override public func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    if let paragraph = theme.paragraph {
      return paragraph
    }

    return [:]
  }

  override open func insertNewAfter(selection: RangeSelection?) throws -> ParagraphNode? {
    let newElement = createParagraphNode()
    let direction = getDirection()
    do {
      try newElement.setDirection(direction: direction)
      try insertAfter(nodeToInsert: newElement)
    } catch {
      throw LexicalError.internal("Error in insertNewAfter: \(error.localizedDescription)")
    }
    return newElement
  }

  public func createParagraphNode() -> ParagraphNode {
    return ParagraphNode()
  }
}
