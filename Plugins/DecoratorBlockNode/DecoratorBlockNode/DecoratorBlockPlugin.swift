//
//  DecoratorBlockPlugin.swift
//  Lexical
//
//  Created by Nemanja Kovacevic on 19.11.24..
//

import Foundation
import Lexical
import UIKit

open class BlockPlugin: Plugin {
  
  public init() {}

  weak var editor: Editor?
  public weak var lexicalView: LexicalView?

  public func setUp(editor: Editor) {
    self.editor = editor
    do {
      try editor.registerNode(nodeType: DecoratorBlockNode.getType(), class: DecoratorBlockNode.self)
    } catch {
      print("\(error)")
    }
  }
  
  public func tearDown() {
  }

  public func isBlockNode(_ node: Node?) -> Bool {
    node is DecoratorBlockNode
  }

}

