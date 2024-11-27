//
//  DecoratorBlockNode.swift
//  Lexical
//
//  Created by Nemanja Kovacevic on 19.11.24..
//

import Foundation
import UIKit

open class DecoratorBlockNode: DecoratorNode {

  override public func isInline() -> Bool {
    return false
  }

}