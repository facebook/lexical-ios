//
//  DecoratorBlockNode.swift
//  Lexical
//
//  Created by Nemanja Kovacevic on 19.11.24..
//

import Foundation
import UIKit

extension NodeType {
  static let decoratorBlock = NodeType(rawValue: "decorator-block")
}

open class DecoratorBlockNode: ElementNode {
  override public class func getType() -> NodeType {
    return .decoratorBlock
  }

  override public required init() {
    super.init()
  }

  override public required init(_ key: NodeKey?) {
    super.init(key)
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
  }

  override public func clone() -> Self {
    Self(key)
  }

  open func createDecoratorNode() -> DecoratorNode {
    fatalError("createDecoratorNode: base method not extended")
  }

  override open func insertNewAfter(selection: RangeSelection?) throws
    -> RangeSelection.InsertNewAfterResult
  {
    let newElement = createParagraphNode()

    try newElement.setDirection(direction: getDirection())
    try insertAfter(nodeToInsert: newElement)

    return .init(element: newElement)
  }

  open func getDecoratorNode() -> DecoratorNode {
    return getChildren().first! as! DecoratorNode
  }
}

public func insertDecoratorBlock(editor: Editor, decoratorBlock: DecoratorBlockNode.Type) throws {
  try editor.update {
    if let selection = try getSelection() as? RangeSelection {
      let block = decoratorBlock.init()
      try block.append([block.createDecoratorNode()])
      _ = try selection.insertNodes(nodes: [block], selectStart: false)
    }
  }
}
