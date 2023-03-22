// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import UIKit

public class RootNode: ElementNode {

  override required init() {
    super.init(kRootNodeKey)
    self.type = NodeType.root
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
    self.type = NodeType.root
  }

  override public func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
  }

  override public func clone() -> Self {
    Self()
  }

  override public func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    if let root = theme.root {
      return root
    }

    return [.font: LexicalConstants.defaultFont]
  }

  // Root nodes cannot have a preamble. If they did, there would be no way to make a selection of the
  // beginning of the document. The same applies to postamble.
  override public final func getPreamble() -> String {
    return ""
  }

  override public func getTextContent(includeInert: Bool = false, includeDirectionless: Bool = false) -> String {
    return super.getTextContent(includeInert: includeInert, includeDirectionless: includeDirectionless)
  }

  override public final func getPostamble() -> String {
    return ""
  }

  override public func insertBefore(nodeToInsert: Node) throws -> Node {
    throw LexicalError.invariantViolation("insertBefore: cannot be called on root nodes")
  }

  override public func remove() throws {
    throw LexicalError.invariantViolation("remove: cannot be called on root nodes")
  }

  override public func replace<T: Node>(replaceWith: T) throws -> T {
    throw LexicalError.invariantViolation("replace: cannot be called on root nodes")
  }

  override public func insertAfter(nodeToInsert: Node) throws -> Node {
    throw LexicalError.invariantViolation("insertAfter: cannot be called on root nodes")
  }
}

extension RootNode: CustomDebugStringConvertible {
  public var debugDescription: String {
    return "(RootNode: key '\(key)', id \(ObjectIdentifier(self))"
  }
}
