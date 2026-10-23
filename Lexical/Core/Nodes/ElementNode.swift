/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

/// A node that can contain other nodes as children.
///
/// Paragraphs, lists, quotes, headings, and the document ``RootNode`` are all
/// element nodes. Subclass ``ElementNode`` when a node should own an ordered
/// child list (as opposed to ``TextNode``, which holds a text payload, or
/// ``DecoratorNode``, which hosts a native view).
///
/// Child keys are stored on the element; use ``getChildren()`` and the
/// insert/append helpers to mutate the tree inside an ``Editor/update(_:)``.
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

  /// The writing direction of this element, if one is set.
  func getDirection() -> Direction? {
    return direction
  }

  /// Creates an element with a newly generated key.
  override public init() {
    super.init()
  }

  /// Creates an element with an explicit key, or generates one when `key` is `nil`.
  override public init(_ key: NodeKey?) {
    super.init(key)
  }

  /// Restores an element and its children from a serialized editor state.
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

  /// Encodes this element, including children, direction, and indent.
  override open func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(getChildren(), forKey: .children)
    try container.encode(direction, forKey: .direction)
    try container.encode(indent, forKey: .indent)
    try container.encode("", forKey: .format)
  }

  /// Sets the writing direction of this element and returns the writable node.
  @discardableResult
  func setDirection(direction: Direction?) throws -> ElementNode {
    try errorOnReadOnly()
    let node = try getWritable() as ElementNode
    node.direction = direction
    return node
  }

  /// Whether this element participates in indent / outdent commands.
  open func canIndent() -> Bool {
    return true
  }

  /// The current indent level of this element.
  open func getIndent() -> Int {
    let node = getLatest() as ElementNode
    return node.indent
  }

  /// Sets the indent level and returns the writable node.
  @discardableResult
  open func setIndent(_ indent: Int) throws -> ElementNode {
    try errorOnReadOnly()
    let node = try getWritable() as ElementNode
    node.indent = indent
    return node
  }

  /// Appends nodes as the last children of this element, reparenting them if needed.
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

  /// The first direct child, typed as `T` when the stored node matches.
  public func getFirstChild<T: Node>() -> T? {
    let children = getLatest().children

    if children.isEmpty {
      return nil
    }

    guard let firstChild = children.first else { return nil }

    return getNodeByKey(key: firstChild)
  }

  /// The last direct child, or `nil` if this element is empty.
  public func getLastChild() -> Node? {
    let children = getLatest().children

    if children.isEmpty {
      return nil
    }

    return getNodeByKey(key: children[children.count - 1])
  }

  /// The number of direct children.
  public func getChildrenSize() -> Int {
    let latest = getLatest() as ElementNode
    return latest.children.count
  }

  /// The direct child at `index`, or `nil` if the index is out of range.
  public func getChildAtIndex(index: Int) -> Node? {
    let children = self.children
    if index >= 0 && index < children.count {
      let key = children[index]
      return getNodeByKey(key: key)
    } else {
      return nil
    }
  }

  /// A descendant resolved from `index` in the flattened child walk.
  ///
  /// Out-of-range indexes fall back to the last descendant of the last child.
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

  /// The deepest first child in this subtree (the start of the element's content).
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

  /// The deepest last child in this subtree (the end of the element's content).
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

  /// Whether a tab character can be inserted into this element.
  func canInsertTab() -> Bool {
    return false
  }

  @discardableResult
  /// Called when a backspace would collapse this element at its start.
  ///
  /// Return `true` if the subclass handled the event.
  open func collapseAtStart(selection: RangeSelection) throws -> Bool {
    return false
  }

  /// Whether this node should be omitted when copying to `destination`.
  public func excludeFromCopy(destination: Destination? = nil) -> Bool {
    return false
  }

  /// Whether the contents of this element can be extracted (for example, cut).
  func canExtractContents() -> Bool {
    return true
  }

  /// Whether this element can be replaced by `replacement`.
  func canReplaceWith(replacement: Node) -> Bool {
    return true
  }

  /// Whether `node` may be inserted immediately after this element.
  func canInsertAfter(node: Node) -> Bool {
    return true
  }

  /// Whether this element is allowed to exist with no children.
  open func canBeEmpty() -> Bool {
    return true
  }

  /// Whether text may be inserted before the first child.
  open func canInsertTextBefore() -> Bool {
    return true
  }

  /// Whether text may be inserted after the last child.
  open func canInsertTextAfter() -> Bool {
    return true
  }

  /// Whether this element is inline (for example, a link) rather than a block.
  open func isInline() -> Bool {
    return false
  }

  /// Whether a selection delete is allowed to remove this element.
  func canSelectionRemove() -> Bool {
    return true
  }

  /// Whether this element can merge its children into `node` (or vice versa).
  public func canMergeWith(node: ElementNode) -> Bool {
    return false
  }

  /// Whether extracting `child` should also extract this parent element.
  public func extractWithChild(
    child: Node,
    selection: BaseSelection?,
    destination: Destination
  ) -> Bool {
    return false
  }

  /// Direct child nodes, in order. Missing keys are skipped.
  public func getChildren() -> [Node] {
    return getLatest().children.compactMap { nodeKey in
      getNodeByKey(key: nodeKey)
    }
  }

  /// Keys of the direct children, in order.
  public func getChildrenKeys() -> [NodeKey] {
    let latest: ElementNode = getLatest()
    return latest.children
  }

  // Element nodes can't have a text part. Making this final so subclasses are bound by that rule.
  override public final func getTextPart() -> String {
    return ""
  }

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

  /// All ``TextNode`` descendants, optionally including inert nodes.
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
  @discardableResult
  /// Places a range selection on this element.
  ///
  /// Offsets are child indexes. `nil` means “after the last child”.
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

  /// `true` when this element has no children.
  public func isEmpty() -> Bool {
    return getChildrenSize() == 0
  }

  // These are intended to be extends for specific element heuristics.
  /// Inserts a new node of an appropriate type after this element.
  ///
  /// Subclasses must implement this (for example, a paragraph inserting another paragraph).
  open func insertNewAfter(selection: RangeSelection?) throws -> Node? {
    throw LexicalError.internal("Subclasses need to implement this method")
  }

  @discardableResult
  /// Moves the selection to the start of this element's content.
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

  @discardableResult
  /// Moves the selection to the end of this element's content.
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

  @discardableResult
  /// Removes every child and returns the writable element.
  func clear() throws -> ElementNode {
    try errorOnReadOnly()

    let writableSelf = try getWritable()

    let children = writableSelf.getChildren()
    _ = try children.map({ try $0.remove() })

    return writableSelf
  }

  // Shadow root functionality not yet implemented in Lexical iOS.
  /// Whether this element is a shadow root. Always `false` on iOS today.
  public func isShadowRoot() -> Bool {
    return false
  }
}
