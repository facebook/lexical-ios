/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

/// A class representing container nodes that can contain other nodes as children.
///
/// ElementNode serves as the base class for all container nodes in Lexical (such as ParagraphNode, RootNode, HeadingNode, etc.).
/// It manages child node relationships, text direction, indentation, and child node traversal.
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

  /// Returns the text direction of the element node.
  ///
  /// - Returns: The current `Direction` if set, or `nil` if unspecified.
  func getDirection() -> Direction? {
    return direction
  }

  /// Initializes a new instance of `ElementNode`.
  override public init() {
    super.init()
  }

  /// Initializes a new instance of `ElementNode` with a specific node key.
  ///
  /// - Parameter key: The optional `NodeKey` to associate with this node.
  override public init(_ key: NodeKey?) {
    super.init(key)
  }

  /// Decodes an `ElementNode` instance from a decoder.
  ///
  /// - Parameter decoder: The decoder to read data from.
  /// - Throws: An error if decoding fails or if the active editor cannot be retrieved.
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

  /// Encodes this `ElementNode` instance to an encoder.
  ///
  /// - Parameter encoder: The encoder to write data to.
  /// - Throws: An error if encoding fails.
  override open func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(getChildren(), forKey: .children)
    try container.encode(direction, forKey: .direction)
    try container.encode(indent, forKey: .indent)
    try container.encode("", forKey: .format)
  }

  /// Sets the text direction for this element node.
  ///
  /// - Parameter direction: The `Direction` to set.
  /// - Returns: The updated writable `ElementNode`.
  /// - Throws: An error if called during read-only mode.
  @discardableResult
  func setDirection(direction: Direction?) throws -> ElementNode {
    try errorOnReadOnly()
    let node = try getWritable() as ElementNode
    node.direction = direction
    return node
  }

  /// Indicates whether the element node supports indentation.
  ///
  /// - Returns: `true` if the node can be indented; otherwise, `false`. Defaults to `true`.
  open func canIndent() -> Bool {
    return true
  }

  /// Returns the current indentation level of the element node.
  ///
  /// - Returns: An `Int` representing the indentation level.
  open func getIndent() -> Int {
    let node = getLatest() as ElementNode
    return node.indent
  }

  /// Sets the indentation level for this element node.
  ///
  /// - Parameter indent: An integer representing the indentation level to set.
  /// - Returns: The updated writable `ElementNode`.
  /// - Throws: An error if called during read-only mode.
  @discardableResult
  open func setIndent(_ indent: Int) throws -> ElementNode {
    try errorOnReadOnly()
    let node = try getWritable() as ElementNode
    node.indent = indent
    return node
  }

  /// Appends an array of nodes as children to this element node.
  ///
  /// - Parameter nodesToAppend: An array of `Node` instances to append.
  /// - Throws: An error if called in read-only mode or if node invariants are violated.
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

  /// Retrieves the first child node cast to a specific node type `T`.
  ///
  /// - Returns: The first child node as type `T`, or `nil` if there are no children or type mismatch occurs.
  public func getFirstChild<T: Node>() -> T? {
    let children = getLatest().children

    if children.isEmpty {
      return nil
    }

    guard let firstChild = children.first else { return nil }

    return getNodeByKey(key: firstChild)
  }

  /// Retrieves the last child node of this element node.
  ///
  /// - Returns: The last child `Node`, or `nil` if there are no children.
  public func getLastChild() -> Node? {
    let children = getLatest().children

    if children.isEmpty {
      return nil
    }

    return getNodeByKey(key: children[children.count - 1])
  }

  /// Returns the number of immediate child nodes.
  ///
  /// - Returns: An integer representing the count of children.
  public func getChildrenSize() -> Int {
    let latest = getLatest() as ElementNode
    return latest.children.count
  }

  /// Retrieves a child node at a specific index.
  ///
  /// - Parameter index: The zero-based index of the child node.
  /// - Returns: The child `Node` at the specified index, or `nil` if out of bounds.
  public func getChildAtIndex(index: Int) -> Node? {
    let children = self.children
    if index >= 0 && index < children.count {
      let key = children[index]
      return getNodeByKey(key: key)
    } else {
      return nil
    }
  }

  /// Retrieves a descendant node at a given index.
  ///
  /// - Parameter index: The zero-based index of the descendant.
  /// - Returns: The descendant `Node`, or `nil` if index is out of range.
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

  /// Traverses down the node hierarchy to return the very first descendant node.
  ///
  /// - Returns: The first descendant `Node`, or `nil` if the element has no children.
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

  /// Traverses down the node hierarchy to return the very last descendant node.
  ///
  /// - Returns: The last descendant `Node`, or `nil` if the element has no children.
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

  /// Determines whether a Tab key action can be performed on this node.
  ///
  /// - Returns: `false` by default for `ElementNode`.
  func canInsertTab() -> Bool {
    return false
  }

  /// Collapses selection at the start of the element node.
  ///
  /// - Parameter selection: The current selection.
  /// - Returns: `true` if handled, `false` otherwise.
  /// - Throws: An error if read-only violation occurs.
  @discardableResult
  open func collapseAtStart(selection: RangeSelection) throws -> Bool {
    return false
  }

  /// Determines whether this element node should be excluded when copying selection content.
  ///
  /// - Parameter destination: The target destination for copy.
  /// - Returns: `false` by default.
  public func excludeFromCopy(destination: Destination? = nil) -> Bool {
    return false
  }

  /// Indicates whether the content of this element node can be extracted.
  ///
  /// - Returns: `true` by default.
  func canExtractContents() -> Bool {
    return true
  }

  /// Indicates whether this element node can be replaced with another node.
  ///
  /// - Parameter replacement: The proposed replacement `Node`.
  /// - Returns: `true` by default.
  func canReplaceWith(replacement: Node) -> Bool {
    return true
  }

  /// Indicates whether a node can be inserted after this element node.
  ///
  /// - Parameter node: The node to insert.
  /// - Returns: `true` by default.
  func canInsertAfter(node: Node) -> Bool {
    return true
  }

  /// Indicates whether this element node is allowed to be empty.
  ///
  /// - Returns: `true` by default.
  open func canBeEmpty() -> Bool {
    return true
  }

  /// Indicates whether text can be inserted before this element node.
  ///
  /// - Returns: `true` by default.
  open func canInsertTextBefore() -> Bool {
    return true
  }

  /// Indicates whether text can be inserted after this element node.
  ///
  /// - Returns: `true` by default.
  open func canInsertTextAfter() -> Bool {
    return true
  }

  /// Indicates whether this element node is an inline element.
  ///
  /// - Returns: `false` by default for element nodes. Subclasses can override this.
  open func isInline() -> Bool {
    return false
  }

  /// Indicates whether the selection can remove this element node.
  ///
  /// - Returns: `true` by default.
  func canSelectionRemove() -> Bool {
    return true
  }

  /// Determines if this element node can be merged with another element node.
  ///
  /// - Parameter node: The other `ElementNode` to merge with.
  /// - Returns: `false` by default.
  public func canMergeWith(node: ElementNode) -> Bool {
    return false
  }

  /// Extracts content with a specific child node during selection handling.
  ///
  /// - Parameters:
  ///   - child: The child node involved.
  ///   - selection: The active selection.
  ///   - destination: The target destination.
  /// - Returns: `false` by default.
  public func extractWithChild(
    child: Node,
    selection: BaseSelection?,
    destination: Destination
  ) -> Bool {
    return false
  }

  /// Retrieves an array of child `Node` objects for this element node.
  ///
  /// - Returns: An array containing the child nodes.
  public func getChildren() -> [Node] {
    return getLatest().children.compactMap { nodeKey in
      getNodeByKey(key: nodeKey)
    }
  }

  /// Retrieves an array of `NodeKey` identifiers for all child nodes.
  ///
  /// - Returns: An array of child `NodeKey`s.
  public func getChildrenKeys() -> [NodeKey] {
    let latest: ElementNode = getLatest()
    return latest.children
  }

  /// Element nodes cannot have text content directly. Returns an empty string.
  ///
  /// - Returns: An empty `String`.
  override public final func getTextPart() -> String {
    return ""
  }

  /// Returns the preamble string for string representation / text extraction.
  ///
  /// - Returns: A preamble string (e.g., newline or empty string).
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

  /// Returns the postamble string for string representation / text extraction.
  ///
  /// - Returns: A postamble string (e.g., newline or empty string).
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

  /// Retrieves all descendant `TextNode` instances inside this element.
  ///
  /// - Parameter includeInert: A boolean indicating whether to include inert text nodes.
  /// - Returns: An array of `TextNode` objects found within children.
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

  /// Returns the complete text content string of this element node and all its children.
  ///
  /// - Parameters:
  ///   - includeInert: Whether to include inert text nodes.
  ///   - includeDirectionless: Whether to include directionless content.
  /// - Returns: The aggregated text content string.
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

  /// Selects content within this element node using offsets.
  ///
  /// - Parameters:
  ///   - anchorOffset: The offset index for anchor point.
  ///   - focusOffset: The offset index for focus point.
  /// - Returns: A `RangeSelection` instance.
  /// - Throws: An error if called in read-only mode or selection creation fails.
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

  /// Checks if the element node has no children.
  ///
  /// - Returns: `true` if child count is zero; otherwise `false`.
  public func isEmpty() -> Bool {
    return getChildrenSize() == 0
  }

  /// Inserts a new node after this element node during specific selection heuristics.
  ///
  /// - Parameter selection: The current selection.
  /// - Returns: The newly created `Node` instance.
  /// - Throws: An error if subclasses haven't overridden this implementation.
  open func insertNewAfter(selection: RangeSelection?) throws -> Node? {
    throw LexicalError.internal("Subclasses need to implement this method")
  }

  /// Selects the start of this element node or its first descendant.
  ///
  /// - Returns: The resulting `RangeSelection`.
  /// - Throws: An error if selection update fails.
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

  /// Selects the end of this element node or its last descendant.
  ///
  /// - Returns: The resulting `RangeSelection`.
  /// - Throws: An error if selection update fails.
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

  /// Removes all child nodes from this element node.
  ///
  /// - Returns: The updated writable `ElementNode`.
  /// - Throws: An error if called in read-only mode or child removal fails.
  @discardableResult
  func clear() throws -> ElementNode {
    try errorOnReadOnly()

    let writableSelf = try getWritable()

    let children = writableSelf.getChildren()
    _ = try children.map({ try $0.remove() })

    return writableSelf
  }

  /// Checks if this node is a shadow root node.
  ///
  /// - Returns: `false` by default.
  public func isShadowRoot() -> Bool {
    return false
  }
}