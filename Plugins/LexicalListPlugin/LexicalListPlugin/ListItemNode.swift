/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import Foundation
import Lexical
import UIKit

extension NodeType {
  static let listItem = NodeType(rawValue: "listItem")
}

public class ListItemNode: ElementNode {
  override public init() {
    super.init()
    self.type = NodeType.listItem
  }

  override public required init(_ key: NodeKey?) {
    super.init(key)
    self.type = NodeType.listItem
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
    self.type = NodeType.listItem
  }

  override open func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
  }

  override public func clone() -> Self {
    Self(key)
  }

  override public func getIndent() -> Int {
    guard let parent = getParent() as? ListNode else {
      // If we don't have a parent, we are likely serializing
      return super.getIndent()
    }
    // ListItemNode should always have a ListNode for a parent.
    var listNodeParent = parent.getParent()
    var indentLevel = 1 // different to web; on iOS, need indent 1 for outer list
    while listNodeParent is ListItemNode {
      listNodeParent = listNodeParent?.getParent()?.getParent()
      indentLevel += 1
    }
    return indentLevel
  }

  // TODO: support other types of list. Correctly derive the item number in this method.
  override public func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    let node: ListItemNode = getLatest()
    let listNode = node.getParent() as? ListNode

    var attributes: [NSAttributedString.Key: Any] = theme.listItem ?? [:]

    if node.getChildren().first is ListNode {
      // Don't apply styles for this list item, because there's another list inside it (don't want to draw two bullets!)
      return attributes
    }

    var character = ""

    if listNode?.getListType() == .bullet {
      character = "\u{2022}"
    } else {
      // list is numbered; count previous siblings
      if let listNode {
        let start = listNode.getStart()
        let prevItems = getPreviousSiblings().filter { $0 is ListItemNode }.count
        character = String("\(start + prevItems).")
      }
    }

    // the magic number is to horizontally position the bullet further left than the indent size, but not so far as to hit the previous indent stop.
    attributes[.listItem] = ListItemAttribute(itemNodeKey: node.key, listItemCharacter: character, characterIndentationPixels: (CGFloat(getIndent()) - 0.8) * theme.indentSize)

    return attributes
  }
}
