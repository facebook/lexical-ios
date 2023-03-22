// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import UIKit

public typealias NodeKey = String

open class Node: Codable {
  enum CodingKeys: String, CodingKey {
    case type
    case version
  }

  public var key: NodeKey
  var parent: NodeKey?
  public var type: NodeType
  public var version: Int

  public init() {
    self.type = Node.getType()
    self.version = 1
    self.key = LexicalConstants.uninitializedNodeKey

    _ = try? generateKey(node: self)
  }

  public init(_ key: NodeKey?) {
    self.type = Node.getType()
    self.version = 1

    if let key = key, key != LexicalConstants.uninitializedNodeKey {
      self.key = key
    } else {
      self.key = LexicalConstants.uninitializedNodeKey
      _ = try? generateKey(node: self)
    }
  }

  public required init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    key = LexicalConstants.uninitializedNodeKey
    type = try NodeType(rawValue: values.decode(String.self, forKey: .type))
    version = try values.decode(Int.self, forKey: .version)

    _ = try? generateKey(node: self)
  }

  open func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.type.rawValue, forKey: .type)
    try container.encode(self.version, forKey: .version)
  }

  /**
   Called whenever the node is moved to a new editor, e.g. when initialising an editor
   with an existing editor state.
   */
  open func didMoveTo(newEditor editor: Editor) {}

  // This is an initial value for `type`.
  // static methods cannot be overridden in swift so,
  // each subclass needs to assign the type property in their init method
  static func getType() -> NodeType {
    NodeType.unknown
  }

  public func getPreamble() -> String {
    return ""
  }

  public func getPostamble() -> String {
    return ""
  }

  // Note that on JS, getTextContent() returns the text content of this node and all children.
  // On iOS we need a way of getting just the text of the current node (not including children), so
  // I called it getTextPart().
  public func getTextPart() -> String {
    return ""
  }

  func getTextPartSize() -> Int {
    return getTextPart().lengthAsNSString()
  }

  func isDirty() -> Bool {
    guard let editor = getActiveEditor() else {
      fatalError()
    }
    return editor.dirtyNodes[key] != nil
  }

  public func getLatest() -> Self {
    guard let latest: Self = getNodeByKey(key: key) else {
      fatalError()
    }
    return latest
  }

  // All subclasses of Node should have clone method.
  // We define clone here so we can call it on any  Node, and we throw this error
  // by default since the subclass should provide their own implementation.
  // The subclass implementation should not copy superclass properties
  open func clone() -> Self {
    fatalError("LexicalNode: Node \(String(describing: self)) does not implement .clone().")
  }

  /// Lets the node provide attributes for TextKit to use to render the node's content.
  open func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    [:]
  }

  /**
   Attributes that apply to an entire block.

   This is conceptually not a thing in TextKit, so we had to build our own solution. Note that a block
   is an element or decorator that is not inline. The values of the block level attributes are applied
   to the relevant paragraph style for the first or last paragraph within the node. (Paragraph is here
   used to refer to a TextKit paragraph, i.e. some text separated by newlines. It's nothing to do with
   Lexical's paragraph nodes!)
   */
  open func getBlockLevelAttributes(theme: Theme) -> BlockLevelAttributes? {
    return theme.getBlockLevelAttributes(self.type)
  }

  public func getWritable() throws -> Self {
    try errorOnReadOnly()

    guard let editor = getActiveEditor(), let editorState = getActiveEditorState() else {
      throw LexicalError.invariantViolation("LexicalNode: Could not get active editor for \(String(describing: self)).")
    }

    let latestNode = getLatest()

    if editor.cloneNotNeeded.contains(key) {
      // Transforms clear the dirty node set on each iteration to keep track on newly dirty nodes
      internallyMarkNodeAsDirty(node: latestNode, cause: .userInitiated)
      return latestNode
    }

    let mutableNode = getLatest().clone()

    mutableNode.parent = latestNode.parent
    if let latestNode = latestNode as? ElementNode, let mutableNode = mutableNode as? ElementNode {
      mutableNode.children = latestNode.children
    } else if let latestNode = latestNode as? TextNode, let mutableNode = mutableNode as? TextNode {
      mutableNode.format = latestNode.format
      mutableNode.mode = latestNode.mode
    }

    editor.cloneNotNeeded.insert(key)
    mutableNode.key = key
    internallyMarkNodeAsDirty(node: mutableNode, cause: .userInitiated)

    editorState.nodeMap[key] = mutableNode
    return mutableNode
  }

  public func getIndexWithinParent() -> Int? {
    guard let parent = self.getParent() else {
      return nil
    }

    return parent.children.firstIndex(of: self.key)
  }

  public func getParent() -> ElementNode? {
    guard let parent = getLatest().parent else { return nil }

    return getNodeByKey(key: parent)
  }

  func getParentKeys() -> [NodeKey] {
    var parents: [NodeKey] = []
    var node = self.getParent()

    while let unwrappedNode = node {
      parents.append(unwrappedNode.key)
      node = unwrappedNode.getParent()
    }

    return parents
  }

  // this method returns the child of the top level element
  // i.e. root _> paragraph -> text would return paragraph
  public func getTopLevelElement() -> ElementNode? {
    var node = getNodeByKey(key: key)

    while node != nil {
      let parent = node?.getParent()
      if isRootNode(node: parent) && isElementNode(node: node) {
        return node as? ElementNode
      }

      node = parent
    }

    return nil
  }

  public func getTopLevelElementOrThrow() -> ElementNode {
    guard let parent = getTopLevelElement() else {
      fatalError("Expected node \(key) to have a top parent element.")
    }

    return parent
  }

  public func getParents() -> [ElementNode] {
    var parents: [ElementNode] = []
    var node = self.getParent()
    while let unwrappedNode = node {
      parents.append(unwrappedNode)
      node = unwrappedNode.getParent()
    }

    return parents
  }

  public func getCommonAncestor(node: Node) -> ElementNode? {
    var a = getParents()
    var b = node.getParents()

    if isElementNode(node: self) {
      if let elementNode = self as? ElementNode {
        a.insert(elementNode, at: 0)
      }
    }

    if isElementNode(node: node) {
      if let elementNode = node as? ElementNode {
        b.insert(elementNode, at: 0)
      }
    }

    if a.count == 0 || b.count == 0 || a.last !== b.last {
      return nil
    }

    let bSet = Set(b)
    for (index, _) in a.enumerated() {
      let ancestor = a[index]
      if bSet.contains(ancestor) {
        return ancestor
      }
    }
    return nil
  }

  public func getPreviousSibling() -> Node? {
    guard let parent = self.getParent() else { return nil }

    guard let index = parent.children.firstIndex(of: self.key) else {
      return nil
    }

    let childrenIndex = index - 1

    if childrenIndex < 0 {
      return nil
    }

    return getNodeByKey(key: parent.children[childrenIndex])
  }

  public func getNextSibling() -> Node? {
    guard let parent = self.getParent() else { return nil }

    guard let index = parent.children.firstIndex(of: self.key) else {
      return nil
    }

    if index >= parent.children.count - 1 {
      return nil
    }

    let childrenIndex = index + 1

    return getNodeByKey(key: parent.children[childrenIndex])
  }

  public func getPreviousSiblings() -> [Node] {
    guard let parent = getParent() else { return [] }

    let children = parent.children
    guard let index = children.firstIndex(of: key) else { return [] }

    let siblings = children[0..<index]
    return siblings.compactMap({ childKey in
      getNodeByKey(key: childKey)
    })
  }

  public func getNextSiblings() -> [Node] {
    guard let parent = getParent() else { return [] }

    let children = parent.children
    if children.count == 1 {
      return []
    }

    guard let index = children.firstIndex(of: key) else { return [] }

    let siblings = children[(index + 1)...]
    return siblings.compactMap { childKey in
      getNodeByKey(key: childKey)
    }
  }

  public func getNodesBetween(targetNode: Node) -> [Node] {
    let isBefore = isBefore(targetNode)
    var nodes = [Node]()
    var visited = Set<NodeKey>()
    var node = self
    var dfsAncestor: Node?

    while true {
      if !visited.contains(node.key) {
        visited.insert(node.key)
        nodes.append(node)
      }

      if node === targetNode {
        break
      }

      let elementNode = node as? ElementNode
      let child = isElementNode(node: node)
        ? isBefore
        ? elementNode?.getFirstChild()
        : elementNode?.getLastChild()
        : nil

      if child != nil {
        if dfsAncestor == nil {
          dfsAncestor = node
        }

        if let child = child {
          node = child
        }

        continue
      }

      let nextSibling = isBefore ? node.getNextSibling() : node.getPreviousSibling()

      if let nextSibling = nextSibling {
        node = nextSibling
        continue
      }

      let parent = node.getParent()

      if let parent = parent {
        if !visited.contains(parent.key) {
          nodes.append(parent)
        }
      }

      if parent == targetNode {
        break
      }

      var parentSibling: Node?
      var ancestor = parent

      if let parent = parent {
        if parent.isSameKey(dfsAncestor) {
          dfsAncestor = nil
        }
      }

      repeat {
        if ancestor == nil {
          fatalError("getNodesBetween: ancestor is nil")
        }

        parentSibling = isBefore ? ancestor?.getNextSibling() : ancestor?.getPreviousSibling()
        ancestor = ancestor?.getParent()

        if ancestor != nil {
          if let ancestor = ancestor {
            if ancestor.isSameKey(dfsAncestor) {
              dfsAncestor = nil
            }

            if parentSibling == nil && !visited.contains(ancestor.key) {
              nodes.append(ancestor)
            }
          }
        }
      } while parentSibling == nil

      if let parentSibling = parentSibling {
        node = parentSibling
      }
    }

    if !isBefore {
      nodes.reverse()
    }

    return nodes
  }

  func isSameKey(_ object: Node?) -> Bool {
    guard let object = object else { return false }

    return getKey() == object.getKey()
  }

  func getKey() -> NodeKey {
    return key
  }

  func isBefore(_ targetNode: Node) -> Bool {
    if targetNode.isParentOf(self) {
      return true
    }

    if isParentOf(targetNode) {
      return false
    }

    let commonAncestor = getCommonAncestor(node: targetNode)

    return getChildIndex(commonAncestor: commonAncestor, node: self) <
      getChildIndex(commonAncestor: commonAncestor, node: targetNode)
  }

  func getChildIndex(commonAncestor: ElementNode?, node: Node) -> Int {
    var index = 0
    var nodeTemp = node

    while true {
      if let parent = nodeTemp.getParent() {
        if parent == commonAncestor, let childIndex = parent.children.firstIndex(of: nodeTemp.key) {
          index = childIndex
          break
        }

        nodeTemp = parent
      }
    }

    return index
  }

  func isParentOf(_ targetNode: Node) -> Bool {
    var node: Node?

    if key == targetNode.key {
      return false
    }

    node = targetNode

    while node != nil {
      if node?.key == key {
        return true
      }

      node = node?.getParent()
    }

    return false
  }

  public func getParentOrThrow() throws -> ElementNode {
    guard let parent = getParent() else {
      throw LexicalError.invariantViolation("Expected node \(key) to have a parent.")
    }

    return parent
  }

  public func getTextContent(includeInert: Bool = false, includeDirectionless: Bool = false) -> String {
    return ""
  }

  public func getTextContentSize(includeInert: Bool = false, includeDirectionless: Bool = false) -> Int {
    return getTextContent(
      includeInert: includeInert,
      includeDirectionless: includeDirectionless
    ).lengthAsNSString()
  }

  public func remove() throws {
    try errorOnReadOnly()
    try Node.removeNode(nodeToRemove: self, restoreSelection: true)
  }

  public static func removeNode(nodeToRemove: Node, restoreSelection: Bool) throws {
    try errorOnReadOnly()
    let key = nodeToRemove.key
    guard let parent = nodeToRemove.getParent() else {
      return
    }

    let selection = getSelection()

    var selectionMoved = false
    if let selection = selection, restoreSelection {
      let anchor = selection.anchor
      let focus = selection.focus
      if anchor.key == key {
        moveSelectionPointToSibling(point: anchor, node: nodeToRemove, parent: parent)
        selectionMoved = true
      }
      if focus.key == key {
        moveSelectionPointToSibling(point: focus, node: nodeToRemove, parent: parent)
        selectionMoved = true
      }
    }

    let writeableParent = try parent.getWritable()
    guard let index = writeableParent.children.firstIndex(of: key) else {
      throw LexicalError.invariantViolation("Node is not a child of its parent")
    }

    internallyMarkNodeAsDirty(node: nodeToRemove, cause: .userInitiated)
    writeableParent.children.remove(at: index)
    let writableNodeToRemove = try nodeToRemove.getWritable()
    writableNodeToRemove.parent = nil

    if let selection = selection, restoreSelection && !selectionMoved {
      try updateElementSelectionOnCreateDeleteNode(
        selection: selection,
        parentNode: parent,
        nodeOffset: index,
        times: -1)
    }

    if !isRootNode(node: parent) && !parent.canBeEmpty() && parent.getChildrenSize() == 0 {
      try removeNode(nodeToRemove: parent, restoreSelection: restoreSelection)
    }
  }

  @discardableResult
  public func insertAfter(nodeToInsert: Node) throws -> Node {
    try errorOnReadOnly()

    let writableSelf = try getWritable()
    let writableNodeToInsert = try nodeToInsert.getWritable()
    let oldParent = writableNodeToInsert.getParent()
    let selection = getSelection()

    var elementAnchorSelectionOnNode = false
    var elementFocusSelectionOnNode = false

    if let oldParent = oldParent {
      let writableParent = try oldParent.getWritable()

      guard let index = writableParent.children.firstIndex(where: { $0 == writableNodeToInsert.key }) else {
        throw LexicalError.invariantViolation("Node is not a child of its parent")
      }

      internallyMarkSiblingsAsDirty(node: writableNodeToInsert, status: .userInitiated)

      if let selection = selection,
         let oldIndex = nodeToInsert.getIndexWithinParent() {
        let oldParentKey = oldParent.key
        elementAnchorSelectionOnNode = selection.anchor.type == .element &&
          selection.anchor.key == oldParentKey &&
          selection.anchor.offset == oldIndex + 1
        elementFocusSelectionOnNode = selection.focus.type == .element &&
          selection.focus.key == oldParentKey &&
          selection.focus.offset == oldIndex + 1
      }

      writableParent.children.remove(at: index)
    }

    let writableParent = try getParentOrThrow().getWritable()
    let insertKey = writableNodeToInsert.key
    writableNodeToInsert.parent = writableSelf.parent

    guard let index = writableParent.children.firstIndex(where: { $0 == writableSelf.key }) else {
      throw LexicalError.invariantViolation("Node is not a child of its parent")
    }

    writableParent.children.insert(insertKey, at: index + 1)
    internallyMarkSiblingsAsDirty(node: writableNodeToInsert, status: .userInitiated)

    if let selection = selection {
      try updateElementSelectionOnCreateDeleteNode(
        selection: selection,
        parentNode: writableParent,
        nodeOffset: index + 1)
      let writableParentKey = writableParent.key

      if elementAnchorSelectionOnNode {
        selection.anchor.updatePoint(key: writableParentKey, offset: index + 2, type: .element)
      }

      if elementFocusSelectionOnNode {
        selection.focus.updatePoint(key: writableParentKey, offset: index + 2, type: .element)
      }
    }

    return nodeToInsert
  }

  @discardableResult
  public func insertBefore(nodeToInsert: Node) throws -> Node {
    try errorOnReadOnly()
    let writableSelf = try getWritable()
    let writableNodeToInsert = try nodeToInsert.getWritable()

    if let oldParent = writableNodeToInsert.getParent() {
      let writableParent = try oldParent.getWritable() as ElementNode
      let children = writableParent.children
      let index = children.firstIndex(of: writableNodeToInsert.key)

      if let index = index {
        writableParent.children.remove(at: index)
      } else {
        throw LexicalError.invariantViolation("Node is not a child of its parent")
      }

      internallyMarkSiblingsAsDirty(node: writableNodeToInsert, status: .userInitiated)
    }

    let writableParent = try getParentOrThrow().getWritable() as ElementNode
    let insertKey = writableNodeToInsert.key
    writableNodeToInsert.parent = writableSelf.parent
    let children = writableParent.children
    let index = children.firstIndex(of: writableSelf.key)

    if let index = index {
      writableParent.children.insert(insertKey, at: index)
    } else {
      throw LexicalError.invariantViolation("Node is not a child of its parent")
    }

    internallyMarkSiblingsAsDirty(node: writableNodeToInsert, status: .userInitiated)

    if let selection = getSelection(), let index = index {
      try updateElementSelectionOnCreateDeleteNode(
        selection: selection,
        parentNode: writableParent,
        nodeOffset: index
      )
    }

    return nodeToInsert
  }

  @discardableResult
  public func replace<T: Node>(replaceWith: T) throws -> T {
    try errorOnReadOnly()
    let toReplaceKey = key
    let writableReplaceWith = try replaceWith.getWritable() as T

    if let oldParent = writableReplaceWith.getParent() {
      let writableParent = try oldParent.getWritable() as ElementNode
      var children = writableParent.children
      let index = children.firstIndex(of: writableReplaceWith.key)

      internallyMarkSiblingsAsDirty(node: writableReplaceWith, status: .userInitiated)

      if let index = index {
        children.remove(at: index)
      } else {
        throw LexicalError.invariantViolation("Node is not a child of its parent")
      }
    }

    let newParent = try getParentOrThrow()
    let writableParent = try newParent.getWritable() as ElementNode
    let index = writableParent.children.firstIndex(of: key)
    let newKey = writableReplaceWith.key

    if let index = index {
      writableParent.children.insert(newKey, at: index)
    } else {
      throw LexicalError.invariantViolation("Node is not a child of its parent")
    }

    writableReplaceWith.parent = newParent.key
    try Node.removeNode(nodeToRemove: self, restoreSelection: false)
    internallyMarkSiblingsAsDirty(node: writableReplaceWith, status: .userInitiated)

    if let selection = getSelection() {
      let anchor = selection.anchor
      let focus = selection.focus

      if anchor.key == toReplaceKey {
        moveSelectionPointToEnd(point: anchor, node: writableReplaceWith)
      }

      if focus.key == toReplaceKey {
        moveSelectionPointToEnd(point: focus, node: writableReplaceWith)
      }
    }

    return writableReplaceWith
  }

  @discardableResult
  func selectPrevious(anchorOffset: Int?, focusOffset: Int?) throws -> RangeSelection {
    try errorOnReadOnly()
    let parent = try getParentOrThrow()
    let previousSibling = getPreviousSibling()

    if previousSibling == nil {
      return try parent.select(anchorOffset: 0, focusOffset: 0)
    }

    if let previousSibling = previousSibling as? ElementNode {
      return try previousSibling.select(anchorOffset: nil, focusOffset: nil)
    } else if let previousSibling = previousSibling as? TextNode {
      return try previousSibling.select(anchorOffset: anchorOffset, focusOffset: focusOffset)
    } else {
      var index = previousSibling?.getIndexWithinParent()
      index = index ?? 0 + 1
      return try parent.select(anchorOffset: index, focusOffset: index)
    }
  }

  func selectNext(anchorOffset: Int?, focusOffset: Int?) throws -> RangeSelection {
    try errorOnReadOnly()
    let nextSibling = getNextSibling()
    let parent = try getParentOrThrow()

    if nextSibling == nil {
      return try parent.select(anchorOffset: nil, focusOffset: nil)
    }

    if let nextSibling = nextSibling as? ElementNode {
      return try nextSibling.select(anchorOffset: 0, focusOffset: 0)
    } else if let nextSibling = nextSibling as? TextNode {
      return try nextSibling.select(anchorOffset: anchorOffset, focusOffset: focusOffset)
    } else {
      let index = nextSibling?.getIndexWithinParent()
      return try parent.select(anchorOffset: index, focusOffset: index)
    }
  }
}

extension Node: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

extension Node: Equatable {
  public static func ==(lhs: Node, rhs: Node) -> Bool {
    //    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    return lhs.isSameKey(rhs)
  }

  public func isAttached() -> Bool {
    var nodeKey: NodeKey? = key

    while nodeKey != nil {
      if nodeKey == kRootNodeKey {
        return true
      }

      guard let key = nodeKey, let node = getNodeByKey(key: key) else { break }

      nodeKey = node.parent
    }

    return false
  }

  public func isSelected() throws -> Bool {
    guard let selection = getSelection() else {
      return false
    }

    let isSelected = try selection.getNodes().contains(where: { $0.key == self.key })

    if isTextNode(self) {
      return isSelected
    }
    // For inline images inside of element nodes.
    // Without this change the image will be selected if the cursor is before or after it.
    if // selection is RangeSelection &&
      selection.anchor.type == .element &&
        selection.focus.type == .element &&
        selection.anchor.key == selection.focus.key &&
        selection.anchor.offset == selection.focus.offset {
      return false
    }
    return isSelected
  }
}
