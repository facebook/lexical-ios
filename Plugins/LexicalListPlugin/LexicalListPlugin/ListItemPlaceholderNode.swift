//
//  ListItemPlaceholderNode.swift
//
//
//  Created by Michael Hahn on 7/24/24.
//

import Foundation
import Lexical

extension NodeType {
  static let listItemPlaceholder = NodeType(rawValue: "listitemplaceholder")
}

public class ListItemPlaceholderNode: TextNode {
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
    .listItemPlaceholder
  }

  override public func remove() throws {
    let parent = getParent()
    try super.remove()

    // If this was the only child of a ListItemNode, remove the ListItemNode
    if let listItemParent = parent as? ListItemNode, listItemParent.getChildrenSize() == 0 {
      try listItemParent.remove()
    }
  }

}
