//
//  PlaceholderNode.swift
//
//
//  Created by Michael Hahn on 9/3/24.
//

import Foundation

public class PlaceholderNode: TextNode {
  private static let placeholderCharacter = "\u{200B}"

  public override init() {
    super.init()
    try? self.setText(Self.placeholderCharacter)
    self.mode = .token
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
  }

  public required init(text: String, key: NodeKey?) {
    super.init(text: text, key: key)
  }

  override public class func getType() -> NodeType {
    .placeholder
  }

  override public func remove() throws {
    let parent = getParent()
    try super.remove()

    if let parent,
       parent.getChildrenSize() == 0 {
      if let previousSibling = parent.getPreviousSibling() as? ElementNode,
         let lastChild = previousSibling.getLastChild() as? ElementNode {
        try lastChild.selectEnd()
      }

      try parent.remove()
    }
  }

  // Support removing from the parent without also attempting to remove the parent.
  public func removeFromParent() throws {
      try super.remove()
  }

}

