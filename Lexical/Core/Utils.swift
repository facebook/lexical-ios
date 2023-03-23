/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import Foundation
import UIKit

public func getNodeByKey<N: Node>(key: NodeKey) -> N? {
  guard let editorState = getActiveEditorState(), let node = editorState.nodeMap[key] else {
    return nil
  }
  return node as? N
}

@discardableResult
public func generateKey(node: Node) throws -> NodeKey? {
  try errorOnReadOnly()

  guard let editor = getActiveEditor(), let editorState = getActiveEditorState() else {
    return nil
  }

  let key = editor.keyCounter
  editor.keyCounter += 1
  let stringKey = String(key)
  node.key = stringKey
  editorState.nodeMap[stringKey] = node
  editor.cloneNotNeeded.insert(stringKey)
  editor.dirtyType = .hasDirtyNodes
  editor.dirtyNodes[stringKey] = .editorInitiated
  return stringKey
}

private func internallyMarkParentElementsAsDirty(
  parentKey: NodeKey,
  nodeMap: [NodeKey: Node],
  editor: Editor,
  status: DirtyStatusCause = .editorInitiated) {
  var nextParentKey: NodeKey? = parentKey

  while let unwrappedParentKey = nextParentKey {
    if editor.dirtyNodes[unwrappedParentKey] != nil {
      return
    }

    let node = nodeMap[unwrappedParentKey]

    if node == nil {
      break
    }

    editor.dirtyNodes[unwrappedParentKey] = status
    nextParentKey = node?.parent
  }
} // Never use this function directly! It will break
// the cloning heuristic. Instead use node.getWritable().

internal func internallyMarkNodeAsDirty(node: Node, cause: DirtyStatusCause = .editorInitiated) {
  let latest = node.getLatest()
  guard
    let editorState = getActiveEditorState(),
    let editor = getActiveEditor()
  else {
    fatalError()
  }

  let nodeMap = editorState.nodeMap

  if let parent = latest.parent {
    internallyMarkParentElementsAsDirty(parentKey: parent, nodeMap: nodeMap, editor: editor)
  }

  editor.dirtyType = .hasDirtyNodes
  editor.dirtyNodes[latest.key] = cause
}

internal func internallyMarkSiblingsAsDirty(node: Node, status: DirtyStatusCause = .editorInitiated) {
  if let previousNode = node.getPreviousSibling() {
    internallyMarkNodeAsDirty(node: previousNode, cause: status)
  }
  if let nextNode = node.getNextSibling() {
    internallyMarkNodeAsDirty(node: nextNode, cause: status)
  }
}

// TODO: update this method when updateCaretSelectionForUnicodeCharacter is ported
// check if string contains utf-16 grapheme clusters: /[\uD800-\uDBFF][\uDC00-\uDFFF]/g
public func doesContainGrapheme(_ str: String) -> Bool {
  return false
}

public func getCompositionKey() -> NodeKey? {
  return getActiveEditor()?.compositionKey
}

public func createTextNode(text: String?) -> TextNode {
  TextNode(text: text ?? "", key: nil)
}

public func createParagraphNode() -> ParagraphNode {
  ParagraphNode()
}

public func createHeadingNode(headingTag: HeadingTagType) -> HeadingNode {
  HeadingNode(tag: headingTag)
}

public func createQuoteNode() -> QuoteNode {
  QuoteNode()
}

public func createLineBreakNode() -> LineBreakNode {
  LineBreakNode()
}

public func createCodeNode(language: String = "") -> CodeNode {
  CodeNode(language: language)
}

public func createCodeHighlightNode(text: String, highlightType: String?) -> CodeHighlightNode {
  CodeHighlightNode(text: text, highlightType: highlightType)
}

public func toggleTextFormatType(format: TextFormat, type: TextFormatType, alignWithFormat: TextFormat?) -> TextFormat {
  var activeFormat = format
  let isStateFlagPresent = format.isTypeSet(type: type)
  var flag = false

  if let alignWithFormat = alignWithFormat {
    // remove the type from format
    if isStateFlagPresent && !alignWithFormat.isTypeSet(type: type) {
      flag = false
    }

    // add the type to format
    if alignWithFormat.isTypeSet(type: type) {
      flag = true
    }
  } else {
    if isStateFlagPresent {
      flag = false
    } else {
      flag = true
    }
  }

  activeFormat.updateFormat(type: type, value: flag)

  return activeFormat
}

public func isElementNode(node: Node?) -> Bool {
  node is ElementNode
}

public func isTextNode(_ node: Node?) -> Bool {
  node is TextNode
}

public func isRootNode(node: Node?) -> Bool {
  node is RootNode
}

public func isHeadingNode(_ node: Node?) -> Bool {
  node is HeadingNode
}

public func isQuoteNode(_ node: Node?) -> Bool {
  node is QuoteNode
}

public func isCodeNode(_ node: Node?) -> Bool {
  node is CodeNode
}

public func isCodeHighlightNode(_ node: Node?) -> Bool {
  node is CodeHighlightNode
}

public func isLineBreakNode(_ node: Node?) -> Bool {
  node is LineBreakNode
}

public func isDecoratorNode(_ node: Node?) -> Bool {
  node is DecoratorNode
}

// TODO: - update function when we add LineBreakNode and DecoratorNode
public func isLeafNode(_ node: Node?) -> Bool {
  node is TextNode || node is LineBreakNode
}

public func isTokenOrInert(_ node: TextNode?) -> Bool {
  guard let node = node else { return false }
  return node.isToken() || node.isInert()
}

public func isTokenOrInertOrSegmented(_ node: TextNode?) -> Bool {
  guard let node = node else { return false }
  return isTokenOrInert(node) || node.isSegmented()
}

public func getRoot() -> RootNode? {
  guard let editorState = getActiveEditorState(),
        let rootNode = editorState.nodeMap[kRootNodeKey] as? RootNode
  else { return nil }

  return rootNode
}

func getEditorStateTextContent(editorState: EditorState) throws -> String {
  var textContent: String = ""

  try editorState.read {
    if let rootNode = getRoot() {
      textContent += rootNode.getTextContent()
    }
  }

  return textContent
}

public func getNodeHierarchy(editorState: EditorState?) throws -> String {
  var hierarchyString = ""
  var cacheString = ""
  var formatString = ""

  try editorState?.read {
    guard let editorState = getActiveEditorState(), let rootNode = editorState.getRootNode() else {
      throw LexicalError.invariantViolation("Need editor and state")
    }

    let sortedNodeMap = editorState.nodeMap.sorted(
      by: { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    )

    var currentNodes: [(Node, Int)] = [(rootNode, 0)]
    var description: [String] = []

    repeat {
      let (node, depth) = currentNodes.removeLast()

      let indentation = (0..<depth).map({ _ in "\t " }).joined(separator: "")

      if let textNode = node as? TextNode {
        if textNode.format.debugDescription != "" {
          formatString = "{ format: \(textNode.format.debugDescription) }"
        } else {
          formatString = ""
        }
        description.append("\(indentation)(\(node.key)) \(node.type.rawValue) \"\(textNode.getTextPart())\" \(formatString)")
      } else {
        description.append("\(indentation)(\(node.key)) \(node.type.rawValue)")
      }

      if let elementNode = node as? ElementNode {
        let childNodes = elementNode.children.map({ (getNodeByKey(key: $0) ?? Node(), depth + 1) }).reversed()
        currentNodes.append(contentsOf: childNodes)
      }
    } while !currentNodes.isEmpty

    hierarchyString = description.joined(separator: "\n")
    cacheString = sortedNodeMap.map({ node in "\(node.key): \(node.value.type)" }).joined(separator: ", ")
  }

  return "Tree:\n\(hierarchyString)\nCache:\n\(cacheString)"
}

public func getSelectionData(editorState: EditorState?) throws -> String {
  var selectionString = "selection: range\n"

  guard let debugDescription = editorState?.selection?.debugDescription else {
    throw LexicalError.invariantViolation("Need selection")
  }

  selectionString += debugDescription

  return selectionString
}

public func removeParentEmptyElements(startingNode: ElementNode?) throws {
  guard var node = startingNode else { return }

  while !(node is RootNode) {
    let latest = node.getLatest()

    let parentNode = try latest.getParentOrThrow()

    if latest.children.isEmpty {
      try node.remove()
    }

    node = parentNode
  }
}

func checkSelectionIsOnlyLinebreak(selection: RangeSelection) throws -> Bool {
  let nodes = try selection.getNodes()
  return nodes.count == 1 && nodes.contains(where: { $0 is LineBreakNode })
}

public func wrapLeafNodesInElements(
  selection: RangeSelection,
  createElement: () -> ElementNode,
  wrappingElement: ElementNode?) throws {

  let nodes = try selection.getNodes()

  // Check to see if selection is only a linebreak node (for changing paragraph style post-linebreak)
  // This is a divergence from lexical web when changing paragraph styles at a linebreak.
  // Lexical web will go to the parent ElementNode and change all children, while
  // Lexical iOS removes the removes the trailing linebreak and inserts a new parent ElementNode of the
  // chosen type.
  let linebreakPresent = try checkSelectionIsOnlyLinebreak(selection: selection)

  if linebreakPresent {
    // Get node and create new node of selected paragraph type, insert new node,
    // then remove linebreak node, and update selection
    let node = try selection.focus.getNode()
    let element = createElement()
    try node.insertAfter(nodeToInsert: element)
    try (node as? ElementNode)?.getLastChild()?.remove()
    selection.anchor.updatePoint(key: element.key, offset: 0, type: .element)
    selection.focus.updatePoint(key: element.key, offset: 0, type: .element)
  } else {
    if nodes.isEmpty {
      let anchorNode = try selection.anchor.getNode()
      let target = selection.anchor.type == .text ? try anchorNode.getParentOrThrow() : anchorNode
      guard let target = target as? ElementNode else { return }

      let children = target.getChildren()
      var element = createElement()
      try children.forEach({ try element.append([$0]) })

      if wrappingElement != nil {
        try wrappingElement?.append([element])
        if let wrappingElement = wrappingElement {
          element = wrappingElement
        }
      }

      try target.replace(replaceWith: element)

      return
    }

    let firstNode = nodes[0]
    var elementMapping = [NodeKey: ElementNode]()
    var elements = [ElementNode]()

    // The below logic is to find the right target for us to either insertAfter/insertBefore/append
    // the corresponding elements to. This is made more complicated due to nested structures.
    var target: Node? = isElementNode(node: firstNode) ? firstNode : try firstNode.getParentOrThrow()
    while target != nil {
      if let prevSibling = target?.getPreviousSibling() {
        target = prevSibling
        break
      }

      target = try target?.getParentOrThrow()
      if isRootNode(node: target) {
        break
      }
    }

    var emptyElements = [NodeKey]()
    // Find any top level empty elements
    nodes.forEach { node in
      if let node = node as? ElementNode, node.children.isEmpty {
        emptyElements.append(node.key)
      }
    }

    var movedLeafNodes = Set<NodeKey>()
    // Move out all leaf nodes into our elements array. If we find a top level empty element, also
    // move make an element for that.
    try nodes.forEach { node in
      if let parent = node.getParent(), isLeafNode(node), !movedLeafNodes.contains(node.key) {
        let parentKey = parent.key

        if elementMapping[parentKey] == nil {
          let targetElement = createElement()
          elements.append(targetElement)
          elementMapping[parentKey] = targetElement

          // Move node and its siblings to the new element
          try parent.getChildren().forEach { child in
            try targetElement.append([child])
            movedLeafNodes.insert(child.key)
          }

          try removeParentEmptyElements(startingNode: parent)
        }
      } else if emptyElements.contains(node.key) {
        elements.append(createElement())
        try node.remove()
      }
    }

    if let wrappingElement = wrappingElement {
      try elements.forEach({ try wrappingElement.append([$0]) })
    }

    // If our target is the root, let's see if we can re-adjust so that the target is the first child instead.
    if isRootNode(node: target) {
      guard var target = target as? ElementNode else { return }

      let firstChild = target.getFirstChild()

      if let firstChild = firstChild {
        if let elementNode = firstChild as? ElementNode {
          target = elementNode
        }

        if let wrappingElement = wrappingElement {
          try firstChild.insertBefore(nodeToInsert: wrappingElement)
        } else {
          for element in elements {
            try firstChild.insertBefore(nodeToInsert: element)
          }
        }
      } else {
        if let wrappingElement = wrappingElement {
          try target.append([wrappingElement])
        } else {
          try elements.forEach({ try target.append([$0]) })
        }
      }
    } else {
      guard let target = target else {
        return
      }

      if let wrappingElement = wrappingElement {
        try target.insertAfter(nodeToInsert: wrappingElement)
      } else {
        elements.reverse()
        try elements.forEach({ try target.insertAfter(nodeToInsert: $0) })
      }
    }
  }

  selection.dirty = true
}

public func sliceSelectedTextNodeContent(selection: RangeSelection, textNode: TextNode) throws -> TextNode {
  if try textNode.isSelected() && !textNode.isSegmented() && !textNode.isToken() {
    // && ($isRangeSelection(selection) || $isGridSelection(selection)){
    let anchorNode = try selection.anchor.getNode()
    let focusNode = try selection.focus.getNode()
    let isAnchor = textNode == anchorNode
    let isFocus = textNode == focusNode

    if isAnchor || isFocus {
      let isBackward = try selection.isBackward()
      let (anchorOffset, focusOffset) = selection.getCharacterOffsets(selection: selection)
      let isSame = anchorNode == focusNode
      let isFirst = textNode == (isBackward ? focusNode : anchorNode)
      let isLast = textNode == (isBackward ? anchorNode : focusNode)
      var startOffset = 0
      var endOffset: Int?

      if isSame {
        startOffset = anchorOffset > focusOffset ? focusOffset : anchorOffset
        endOffset = anchorOffset > focusOffset ? anchorOffset : focusOffset
      } else if isFirst {
        let offset = isBackward ? focusOffset : anchorOffset
        startOffset = offset
        endOffset = nil
      } else if isLast {
        let offset = isBackward ? anchorOffset : focusOffset
        startOffset = 0
        endOffset = offset
      }

      let text = textNode.getText_dangerousPropertyAccess() as NSString
      let length = text.length - startOffset - (text.length - (endOffset ?? text.length))

      let range = NSRange(location: startOffset, length: length)
      let subString = text.substring(with: range)
      textNode.setText_dangerousPropertyAccess(String(subString))
      return textNode
    }
  }
  return textNode
}

public func decoratorView(forKey key: NodeKey, createIfNecessary: Bool) -> UIView? {
  guard let editor = getActiveEditor() else {
    return nil
  }

  guard let cacheItem = editor.decoratorCache[key] else {
    editor.log(.editor, .warning, "Requested decorator view for a node not in the cache")
    return nil
  }

  switch cacheItem {
  case .needsCreation:
    guard let node = getNodeByKey(key: key) as? DecoratorNode else {
      editor.log(.editor, .warning, "Requested decorator view for a node that is not a decorator node")
      return nil
    }
    let newView = node.createView()
    node.decorate(view: newView)
    editor.decoratorCache[key] = DecoratorCacheItem.unmountedCachedView(newView)
    editor.log(.editor, .verbose, "Creating view (and setting to unmounted): key \(key)")
    return newView
  case .cachedView(let view):
    editor.log(.editor, .verbose, "Returning cached view: key \(key)")
    return view
  case .unmountedCachedView(let view):
    editor.log(.editor, .verbose, "Returning unmounted cached view: key \(key)")
    return view
  case .needsDecorating(let view):
    editor.log(.editor, .verbose, "Returning needs decorating cached view: key \(key)")
    return view
  }
}

internal func destroyCachedDecoratorView(forKey key: NodeKey) {
  guard let editor = getActiveEditor() else {
    return
  }
  editor.decoratorCache.removeValue(forKey: key)
}
