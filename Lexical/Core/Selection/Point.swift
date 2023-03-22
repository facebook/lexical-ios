// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

public enum SelectionType: String {
  case text = "text"
  case element = "element"
  case range = "range"
  case node = "node"
  case grid = "grid"
}

public class Point {
  var key: NodeKey
  public var offset: Int
  public var type: SelectionType

  public init(key: NodeKey, offset: Int, type: SelectionType) {
    self.key = key
    self.offset = offset
    self.type = type
  }

  func isBefore(point b: Point) throws -> Bool {
    var aNode = try getNode()
    var bNode = try b.getNode()
    let aOffset = offset
    let bOffset = b.offset

    if let elementNode = aNode as? ElementNode {
      aNode = elementNode.getDescendantByIndex(index: aOffset)
    }

    if let elementNode = bNode as? ElementNode {
      bNode = elementNode.getDescendantByIndex(index: bOffset)
    }

    if aNode == bNode {
      return aOffset < bOffset
    }

    return aNode.isBefore(bNode)
  }

  public func getNode() throws -> Node {
    guard let node = getNodeByKey(key: key) else {
      throw LexicalError.internal("Point.getNode: node not found")
    }

    return node
  }

  public func getOffset() -> Int {
    return offset
  }

  public func getType() -> SelectionType {
    return type
  }

  func updatePoint(key: NodeKey, offset: Int, type: SelectionType) {
    self.key = key
    self.offset = offset
    self.type = type

    if !isReadOnlyMode() {
      // Must allow invalid positions, as the selection is only being fetched
      // to possibly mark it as dirty: we don't want to force regenerate this selection
      // during this operation.
      guard let selection = getSelection(allowInvalidPositions: true)
      else { return }

      if selection.anchor == self || selection.focus == self {
        selection.dirty = true
      }
    }
  }

  func getCharacterOffset() -> Int {
    type == .text ? offset : 0
  }

  public func isAtNodeEnd() throws -> Bool {
    switch type {
    case .element:
      if let elementNode = try getNode() as? ElementNode {
        return offset == elementNode.children.count
      }

    case .text:
      if let textNode = try getNode() as? TextNode {
        return offset == textNode.getTextPart().lengthAsNSString()
      }
    case .range:
      throw LexicalError.invariantViolation("Need range selection")
    case .node:
      throw LexicalError.invariantViolation("Need node selection")
    case .grid:
      throw LexicalError.invariantViolation("Need grid selection")
    }

    return false
  }
}

extension Point: Equatable {
  public static func == (lhs: Point, rhs: Point) -> Bool {
    return lhs.key == rhs.key &&
      lhs.offset == rhs.offset &&
      lhs.type == rhs.type
  }
}

extension Point: CustomDebugStringConvertible {
  public var debugDescription: String {
    return "key: \(key), offset: \(offset), type: \(type) }"
  }
}
