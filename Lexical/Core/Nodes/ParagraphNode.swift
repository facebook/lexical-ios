/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

open class ParagraphNode: ElementNode {
  override public init() {
    super.init()
  }

  public override required init(_ key: NodeKey?) {
    super.init(key)
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
  }

  override open class func getType() -> NodeType {
    return .paragraph
  }

  override public func clone() -> Self {
    Self(key)
  }

  override open func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    if let paragraph = theme.paragraph {
      return paragraph
    }

    return [:]
  }

  override open func insertNewAfter(selection: RangeSelection?) throws -> RangeSelection.InsertNewAfterResult {
    let newElement = createParagraphNode()
    let direction = getDirection()
    do {
      try newElement.setDirection(direction: direction)
      try insertAfter(nodeToInsert: newElement)
    } catch {
      throw LexicalError.internal("Error in insertNewAfter: \(error.localizedDescription)")
    }
    return .init(element: newElement)
  }

  open func createParagraphNode() -> ParagraphNode {
    return ParagraphNode()
  }
}
