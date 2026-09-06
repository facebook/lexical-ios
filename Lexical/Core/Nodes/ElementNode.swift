/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

/// A node that owns an ordered collection of child nodes.
///
/// Element nodes form the structure of an editor state. Use their traversal
/// methods to inspect descendants and their mutation methods from within an
/// ``Editor/update(_:)`` callback to change the node tree.
open class ElementNode: Node {
  enum CodingKeys: String, CodingKey {
    case children
    case direction
    case indent
    case format // text alignment. Not supported yet.
  }

  // TODO: once the various accessor methods are written, make this var private
  var children: [NodeKey] = []
  var direction: Direction?
  var indent: Int = 0

  /// Returns the text direction stored on this node.
  func getDirection() -> Direction? {
    return direction
  }

  /// Creates an element node and assigns it a generated key.
  override public init() {
    super.init()
  }

  /// Creates an element node with an optional existing key.
  ///
  /// - Parameter key: The key to use, or `nil` to generate one.
  override public init(_ key: NodeKey?) {
    super.init(key)
  }

  /// Creates an element node by decoding its properties and descendants.
  ///
  /// Child nodes are decoded using the node classes registered with the active
  /// editor. A decoded child is linked back to this node as its parent.
  ///
  /// - Parameter decoder: The decoder containing the serialized node.
  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.children = []
    var childNodes: [Node] = []

    guard let editor = getActiveEditor() else {
      throw LexicalError.internal("Could not get active editor")
    }

    do {
      let deserializationMap = editor.registeredNodes
      var childrenUnkeyedContainer = try container.nestedUnkeyedContainer(forKey: .children)

      while !childrenUnkeyedContainer.isAtEnd {
        var containerCopy = childrenUnkeyedContainer
        let unprocessedContainer = try childrenUnkeyedContainer.nestedContainer(keyedBy: PartialCodingKeys.self)
        let type = try NodeType(rawValue: unprocessedContainer.decode(String.self, forKey: .type))

        let klass = deserializationMap[type] ?? UnknownNode.self

        do {
          let decoder = try containerCopy.superDecoder()
          let decodedNode = try klass.init(from: decoder)
          childNodes.append(decodedNode)
          self.children.append(decodedNode.key)
        } catch {
          print(error)
        }
      }
    } catch {
      print(error)
    }

    self.direction = try container.decodeIfPresent(Direction.self, forKey: .direction)
    self.indent = try container.decodeIfPresent(Int.self, forKey: .indent) ?? 0
    try super.init(from: decoder)

    for node in childNodes {
      node.parent = self.key
    }
  }

  /// Encodes this node, including its children, direction, and indentation.
  ///
  /// - Parameter encoder: The encoder that receives the serialized node.
  override open func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(getChildren(), forKey: .children)
    try container.encode(direction, forKey: .direction)
    try container.encode(indent, forKey: .indent)
    try container.encode("", forKey: .format)
  }

  /// Sets the text direction for this node.
  ///
  /// Call this method from within an ``Editor/update(_:)`` callback.
  ///
  /// - Parameter direction: The new direction, or `nil` to clear it.
  /// - Returns: The writable version of this node.
  @discardableResult
  func setDirection(direction: Direction?) throws -> ElementNode {
    try errorOnReadOnly()
    let node = try getWritable() as ElementNode
    node.direction = direction
    return node
  }

  /// Returns whether this node supports indentation.
  ///
  /// Subclasses can override this method to prevent indentation.
  open func canIndent() -> Bool {
    return true
  }

  /// Returns the indentation level from the latest version of this node.
  open func getIndent() -> Int {
    let node = getLatest() as ElementNode
    return node.indent
  }

  /// Sets the indentation level for this node.
  ///
  /// Call this method from within an ``Editor/update(_:)`` callback.
  ///
  /// - Parameter indent: The new indentation level.
  /// - Returns: The writable version of this node.
  @discardableResult
  open func setIndent(_ indent: Int) throws -> ElementNode {
    try errorOnReadOnly()
    let node = try getWritable() as ElementNode
    node.indent = indent
    return node
  }

  /// Appends nodes as the last children of this node.
  ///
  /// Nodes are removed from their previous parents before they are appended.
  /// Call this method from within an ``Editor/update(_:)`` callback.
  ///
  /// - Parameter nodesToAppend: The nodes to append, in order.
  open func append(_ nodesToAppend: [Node]) throws {
    try errorOnReadOnly()
    let writeableSelf: ElementNode = try getWritable()
    let writeableSelfKey = writeableSelf.key
    var writeableSelfChildren = writeableSelf.children
    if let lastChild = getLastChild() {
      internallyMarkNodeAsDirty(node: lastChild, cause: .userInitiated)
    }

    for node in nodesToAppend {
      let writeableNodeToAppend = try node.getWritable()

      // Remove node from previous parent
      if let oldParent = writeableNodeToAppend.getParent() {
        let writeableParent = try oldParent.getWritable()
        guard let index = writeableParent.children.firstIndex(of: writeableNodeToAppend.key) else {
          throw LexicalError.invariantViolation("Node is not a child of its parent")
        }

        writeableParent.children.remove(at: index)
      }

      // Set child parent to self
      writeableNodeToAppend.parent = writeableSelfKey

      // Append children.
      let newKey = writeableNodeToAppend.key
      writeableSelfChildren.append(newKey)
    }

    writeableSelf.children = writeableSelfChildren
  }

  /// Returns the first child as the requested node type, or `nil` when this
  /// node has no children or the child does not match that type.
  public func getFirstChild<T: Node>() -> T? {
    let children = getLatest().children

    if children.isEmpty {
      return nil
    }

    guard let firstChild = children.first else { return nil }

    return getNodeByKey(key: firstChild)
  }

  /// Returns the last child of this node, or `nil` when it has no children.
  public func getLastChild() -> Node? {
    let children = getLatest().children

    if children.isEmpty {
      return nil
    }

    return getNodeByKey(key: children[children.count - 1])
  }

  /// Returns the number of direct children owned by this node.
  public func getChildrenSize() -> Int {
    let latest = getLatest() as ElementNode
    return latest.children.count
  }

  /// Returns the direct child at a zero-based index.
  ///
  /// - Parameter index: The position of the child to retrieve.
  /// - Returns: The child at `index`, or `nil` when the index is out of bounds.
  public func getChildAtIndex(index: Int) -> Node? {
    let children = self.children
    if index >= 0 && index < children.count {
      let key = children[index]
      return getNodeByKey(key: key)
    } else {
      return nil
    }
  }

  /// Returns the deepest descendant associated with a direct-child index.
  ///
  /// For an in-range index, traversal follows the first-child chain. An index
  /// at or beyond the end follows the last-child chain instead.
  ///
  /// - Parameter index: The direct-child index from which traversal begins.
  /// - Returns: The resolved descendant, or `nil` when this node has no children.
  public func getDescendantByIndex(index: Int) -> Node? {
    let children = getChildren()

    if index >= children.count {
      if let resolvedNode = children.last as? ElementNode,
        let lastDescendant = resolvedNode.getLastDescendant()
      {
        return lastDescendant
      }

      return children.last
    }

    if let node = children[index] as? ElementNode, let firstDescendant = node.getFirstDescendant() {
      return firstDescendant
    }

    return children[index]
  }

  /// Returns the deepest first descendant, or `nil` when this node has no children.
  public func getFirstDescendant() -> Node? {
    var node: Node? = getFirstChild()
    while let unwrappedNode = node {
      if let child = (unwrappedNode as? ElementNode)?.getFirstChild() {
        node = child
      } else {
        break
      }
    }

    return node
  }

  /// Returns the deepest last descendant, or `nil` when this node has no children.
  public func getLastDescendant() -> Node? {
    var node = getLastChild()
    while let unwrappedNode = node {
      if let child = (unwrappedNode as? ElementNode)?.getLastChild() {
        node = child
      } else {
        break
      }
    }

    return node
  }

  /// Returns whether pressing Tab can insert a tab character in this node.
  func canInsertTab() -> Bool {
    return false
  }

  /// Handles backward deletion when the selection is at the start of this node.
  ///
  /// Subclasses can override this method to replace the node or change its
  /// state. Returning `true` stops the collapse operation.
  ///
  /// - Parameter selection: The active range selection.
  /// - Returns: `true` when the collapse was handled by this node.
  @discardableResult
  open func collapseAtStart(selection: RangeSelection) throws -> Bool {
    return false
  }

  /// Returns whether this node should be omitted from copied or exported content.
  ///
  /// - Parameter destination: The copy destination, or `nil` for a general copy.
  public func excludeFromCopy(destination: Destination? = nil) -> Bool {
    return false
  }

  /// Returns whether selection extraction may remove this node's contents.
  func canExtractContents() -> Bool {
    return true
  }

  /// Returns whether this node can be replaced by another node.
  ///
  /// - Parameter replacement: The proposed replacement node.
  func canReplaceWith(replacement: Node) -> Bool {
    return true
  }

  /// Returns whether a node can be inserted after this node.
  ///
  /// - Parameter node: The node proposed for insertion.
  func canInsertAfter(node: Node) -> Bool {
    return true
  }

  /// Returns whether this node may remain in the tree without children.
  open func canBeEmpty() -> Bool {
    return true
  }

  /// Returns whether text can be inserted immediately before this node.
  open func canInsertTextBefore() -> Bool {
    return true
  }

  /// Returns whether text can be inserted immediately after this node.
  open func canInsertTextAfter() -> Bool {
    return true
  }

  /// Returns whether this node participates in inline layout.
  open func isInline() -> Bool {
    return false
  }

  /// Returns whether selection operations may remove this node.
  func canSelectionRemove() -> Bool {
    return true
  }

  /// Returns whether this node can merge with another element node.
  ///
  /// - Parameter node: The element node proposed for merging.
  public func canMergeWith(node: ElementNode) -> Bool {
    return false
  }

  /// Returns whether this node should be extracted when one of its children is selected.
  ///
  /// - Parameters:
  ///   - child: The selected child being extracted.
  ///   - selection: The selection driving the extraction, if one exists.
  ///   - destination: The destination for the extracted content.
  public func extractWithChild(
    child: Node,
    selection: BaseSelection?,
    destination: Destination
  ) -> Bool {
    return false
  }

  /// Returns the direct children of this node in document order.
  public func getChildren() -> [Node] {
    return getLatest().children.compactMap { nodeKey in
      getNodeByKey(key: nodeKey)
    }
  }

  /// Returns the keys of this node's direct children in document order.
  public func getChildrenKeys() -> [NodeKey] {
    let latest: ElementNode = getLatest()
    return latest.children
  }

  /// Returns an empty string because element nodes do not provide a text part.
  ///
  /// Text content for an element is derived from its children, preamble, and
  /// postamble. This method is final so subclasses preserve that rule.
  override public final func getTextPart() -> String {
    return ""
  }

  /// Returns the text inserted before this node's child content.
  ///
  /// A block element contributes a newline before its content when its
  /// previous sibling is not an element node.
  override public func getPreamble() -> String {
    if isInline() {
      return ""
    }

    guard let prevSibling = getPreviousSibling() else {
      return ""
    }

    guard prevSibling is ElementNode else {
      // prev is not an element node. Treat it as inline (TODO: inline handling in decorators)
      // Since prev is inline but not an element node, and we're not inline, return a newline
      return "\n"
    }

    // note that if prev is an element node (inline or not), it'll handle the newline.
    return ""
  }

  /// Returns the text inserted after this node's child content.
  ///
  /// A block element contributes a newline when it has a following sibling.
  /// An inline element contributes one only when followed by a block element.
  override public func getPostamble() -> String {
    let nextSibling = getNextSibling()

    if nextSibling == nil {
      // we have no next sibling, return "" no matter whether we're inline or not
      return ""
    } else if isInline() {
      if let nextSiblingAsElement = nextSibling as? ElementNode, !nextSiblingAsElement.isInline() {
        // we're inline but the next sibling is an element but is not inline
        return "\n"
      } else {
        // we're inline, next sibling is either a text node or inline
        return ""
      }
    } else {
      // we're not inline
      return "\n"
    }
  }

  /// Returns all descendant text nodes in document order.
  ///
  /// - Parameter includeInert: Whether to include inert text nodes.
  public func getAllTextNodes(includeInert: Bool = false) -> [TextNode] {
    var textNodes = [TextNode]()
    let node = getLatest() as ElementNode

    for child in node.children {
      guard let childNode = getNodeByKey(key: child) else { return textNodes }

      if let childNode = childNode as? TextNode {
        if includeInert || !childNode.isInert() {
          textNodes.append(childNode)
        }
      } else if let childNode = childNode as? ElementNode {
        let subChildrenNodes = childNode.getAllTextNodes(includeInert: includeInert)
        textNodes.append(contentsOf: subChildrenNodes)
      }
    }

    return textNodes
  }

  /// Returns this node's preamble, descendant text content, and postamble.
  ///
  /// - Parameters:
  ///   - includeInert: Whether to include content from inert nodes.
  ///   - includeDirectionless: Whether to include content from directionless nodes.
  override public func getTextContent(includeInert: Bool = false, includeDirectionless: Bool = false) -> String {
    let children = getChildren()
    let preamble = getPreamble()
    let postamble = getPostamble()
    var textContent = ""

    textContent += preamble

    for child in children {
      textContent += child.getTextContent(includeInert: includeInert, includeDirectionless: includeDirectionless)
      if child is LineBreakNode {
        textContent += child.getPostamble()
      }
    }

    textContent += postamble

    return textContent
  }

  // MARK: - Mutators
  /// Places the range selection at offsets within this element.
  ///
  /// Omitted offsets default to the position after the last child. Call this
  /// method from within an ``Editor/update(_:)`` callback.
  ///
  /// - Parameters:
  ///   - anchorOffset: The anchor's child offset, or `nil` for the end.
  ///   - focusOffset: The focus's child offset, or `nil` for the end.
  /// - Returns: The updated or newly created range selection.
  @discardableResult
  public func select(anchorOffset: Int?, focusOffset: Int?) throws -> RangeSelection {
    try errorOnReadOnly()

    let selection = try getSelection()
    let childrenCount = getChildrenSize()
    var updatedAnchorOffset = childrenCount
    var updatedFocusOffset = childrenCount

    if let anchorOffset {
      updatedAnchorOffset = anchorOffset
    }

    if let focusOffset {
      updatedFocusOffset = focusOffset
    }

    guard let selection = selection as? RangeSelection else {
      return try makeRangeSelection(
        anchorKey: key,
        anchorOffset: updatedAnchorOffset,
        focusKey: key,
        focusOffset: updatedFocusOffset,
        anchorType: .element,
        focusType: .element)
    }

    selection.anchor.updatePoint(key: key, offset: updatedAnchorOffset, type: .element)
    selection.focus.updatePoint(key: key, offset: updatedFocusOffset, type: .element)
    selection.dirty = true

    return selection
  }

  /// Returns whether this node has no children.
  public func isEmpty() -> Bool {
    return getChildrenSize() == 0
  }

  /// Creates the node that should follow this node after inserting a new block.
  ///
  /// Subclasses must override this method when they support block insertion.
  ///
  /// - Parameter selection: The selection that initiated insertion, if available.
  /// - Returns: The inserted node, or `nil` when no node is created.
  open func insertNewAfter(selection: RangeSelection?) throws -> Node? {
    throw LexicalError.internal("Subclasses need to implement this method")
  }

  /// Moves the selection to the beginning of this node's first descendant.
  ///
  /// Empty elements are selected at offset zero.
  ///
  /// - Returns: The resulting range selection.
  @discardableResult
  public func selectStart() throws -> RangeSelection {
    let firstNode = getFirstDescendant()
    if let node = firstNode as? ElementNode {
      return try node.select(anchorOffset: 0, focusOffset: 0)
    }

    if let node = firstNode as? TextNode {
      return try node.select(anchorOffset: 0, focusOffset: 0)
    }
    if let firstNode {
      return try firstNode.selectPrevious(anchorOffset: nil, focusOffset: nil)
    }
    return try select(anchorOffset: 0, focusOffset: 0)
  }

  /// Moves the selection to the end of this node's last descendant.
  ///
  /// Empty elements are selected after their final child position.
  ///
  /// - Returns: The resulting range selection.
  @discardableResult
  public func selectEnd() throws -> RangeSelection {
    if let lastNode = getLastDescendant() {
      if let elementNode = lastNode as? ElementNode {
        return try elementNode.select(anchorOffset: nil, focusOffset: nil)
      }

      if let textNode = lastNode as? TextNode {
        return try textNode.select(anchorOffset: nil, focusOffset: nil)
      }

      // Decorator or LineBreak
      // selectNext()
    }

    return try select(anchorOffset: nil, focusOffset: nil)
  }

  /// Removes every child from this node.
  ///
  /// Call this method from within an ``Editor/update(_:)`` callback.
  ///
  /// - Returns: The writable version of this node.
  @discardableResult
  func clear() throws -> ElementNode {
    try errorOnReadOnly()

    let writableSelf = try getWritable()

    let children = writableSelf.getChildren()
    _ = try children.map({ try $0.remove() })

    return writableSelf
  }

  /// Returns whether this node acts as a shadow root boundary.
  ///
  /// Shadow roots are not currently implemented in Lexical iOS.
  public func isShadowRoot() -> Bool {
    return false
  }
}
