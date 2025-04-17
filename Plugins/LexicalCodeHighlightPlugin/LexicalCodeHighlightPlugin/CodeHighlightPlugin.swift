/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import UIKit

open class CodeHighlightPlugin: Plugin {
  weak var editor: Editor?
  var codeTransform: (() -> Void)?
  var textTransform: (() -> Void)?
  var highlightTransform: (() -> Void)?

  public func setUp(editor: Editor) {
    self.editor = editor
    do {
      try editor.registerNode(nodeType: NodeType.codeHighlight, class: CodeHighlightNode.self)
      codeTransform = editor.addNodeTransform(
        nodeType: NodeType.code,
        transform: { [weak self] in
          guard
            let strongSelf = self,
            let node = $0 as? CodeNode
          else { return }
          try strongSelf.codeNodeTransform(node: node)
        })
      textTransform = editor.addNodeTransform(
        nodeType: NodeType.text,
        transform: { [weak self] in
          guard
            let strongSelf = self,
            let node = $0 as? TextNode
          else { return }
          try strongSelf.textNodeTransform(node: node)
        })
      highlightTransform = editor.addNodeTransform(
        nodeType: NodeType.codeHighlight,
        transform: { [weak self] in
          guard
            let strongSelf = self,
            let node = $0 as? TextNode
          else { return }
          try strongSelf.textNodeTransform(node: node)
        })
    } catch {
    }
  }

  public func tearDown() {
  }

  public init() {}

  // Using `skipTransforms` to prevent extra transforms since reformatting the code
  // will not affect code block content itself.
  //
  // Using extra flag (`isHighlighting`) since both CodeNode and CodeHighlightNode
  // transforms might be called at the same time (e.g. new CodeHighlight node inserted) and
  // in both cases we'll rerun whole reformatting over CodeNode, which is redundant.
  // Especially when pasting code into CodeBlock.
  var isHighlighting = false
  func codeNodeTransform(node: CodeNode) throws {
    guard let editor else {
      return
    }

    if isHighlighting {
      return
    }

    isHighlighting = true

    try editor.update {

      try updateAndRetainSelection(
        node: node,
        updateFn: {
          let code = node.getTextContent()
          let highlightNodes = getHighlightNodes(text: code)
          guard let (from, to, nodesForReplacement) = getDiffRange(prevNodes: node.getChildren(), nextNodes: highlightNodes) else {
            return false
          }
          try replaceRange(node: node, from: from, to: to, nodesToInsert: nodesForReplacement)
          return true
        })
    }
  }

  func textNodeTransform(node: TextNode) throws {
    // Since CodeNode has flat children structure we only need to check
    // if node's parent is a code node and run highlighting if so
    let parentNode = node.getParent()
    if let codeNode = parentNode as? CodeNode {
      try codeNodeTransform(node: codeNode)
    } else if let node = node as? CodeHighlightNode {
      // When code block converted into paragraph or other element
      // code highlight nodes converted back to normal text
      try node.replace(replaceWith: createTextNode(text: node.getTextPart()))
    }
  }

  func getHighlightNodes(text: String) -> [Node] {
    var nodes: [Node] = []
    let attributedString = NSAttributedString(string: text)
    let partials = attributedString.splitByNewlines()
    var i = 0

    for attrStr in partials {
      if attrStr.length > 0 {
        nodes.append(createCodeHighlightNode(text: attrStr.string, highlightType: ""))
      }
      if i < partials.count - 1 {
        nodes.append(createLineBreakNode())
      }
      i += 1
    }

    return nodes
  }

  // Wrapping update function into selection retainer, that tries to keep cursor at the same
  // position as before.
  func updateAndRetainSelection(node: CodeNode, updateFn: () throws -> Bool) throws {
    guard let selection = try getSelection() as? RangeSelection else {
      return
    }

    let anchor = selection.anchor
    let anchorOffset = anchor.offset
    let isNewLineAnchor = anchor.type == .element && isLineBreakNode(node.getChildAtIndex(index: anchor.offset - 1))
    var textOffset = 0

    // Calculating previous text offset (all text node prior to anchor + anchor own text offset)
    if !isNewLineAnchor {
      let anchorNode = try anchor.getNode()
      textOffset =
        anchorOffset
        + anchorNode.getPreviousSiblings().reduce(
          0,
          { offset, node in
            return offset + (isLineBreakNode(node) ? 0 : node.getTextContentSize(includeInert: false, includeDirectionless: false))
          })
    }

    let hasChanges = try updateFn()
    if !hasChanges {
      return
    }

    // Non-text anchors only happen for line breaks, otherwise
    // selection will be within text node (code highlight node)
    if isNewLineAnchor {
      try (anchor.getNode() as? ElementNode)?.select(anchorOffset: anchorOffset, focusOffset: anchorOffset)
      return
    }

    // If it was non-element anchor then we walk through child nodes
    // and looking for a position of original text offset
    _ = try node.getChildren().contains { node in
      if let node = node as? TextNode {
        let textContentSize = node.getTextContentSize()
        if textContentSize >= textOffset {
          try node.select(anchorOffset: textOffset, focusOffset: textOffset)
          return true
        }
        textOffset -= textContentSize
      }
      return false
    }
  }

  // Inserts notes into specific range of node's children. Works for replacement (from != to && nodesToInsert not empty),
  // insertion (from == to && nodesToInsert not empty) and deletion (from != to && nodesToInsert is empty)
  func replaceRange(node: ElementNode, from: Int, to: Int, nodesToInsert: [Node]) throws {
    var children = node.getChildren()
    for i in from..<to {
      try children[i].remove()
    }

    children = node.getChildren()
    if children.count == 0 {
      try node.append(nodesToInsert)
      return
    }

    if from == 0 {
      let firstChild = children[0]
      for node in nodesToInsert {
        try firstChild.insertBefore(nodeToInsert: node)
      }
    } else {
      var currentNode = children.count < from - 1 ? children[from - 1] : children[children.count - 1]
      for node in nodesToInsert {
        try currentNode.insertAfter(nodeToInsert: node)
        currentNode = node
      }
    }
  }

  // Finds minimal diff range between two nodes lists. It returns from/to range boundaries of prevNodes
  // that needs to be replaced with `nodes` (subset of nextNodes) to make prevNodes equal to nextNodes.
  func getDiffRange(prevNodes: [Node], nextNodes: [Node]) -> (from: Int, to: Int, nodesForReplacement: [Node])? {
    var leadingMatch = 0
    while leadingMatch < prevNodes.count {
      if !isEqual(nodeA: prevNodes[leadingMatch], nodeB: nextNodes[leadingMatch]) {
        break
      }
      leadingMatch += 1
    }

    let prevNodesLength = prevNodes.count
    let nextNodesLength = nextNodes.count
    let maxTrailingMatch = min(prevNodesLength, nextNodesLength) - leadingMatch

    var trailingMatch = 0
    while trailingMatch < maxTrailingMatch {
      trailingMatch += 1
      if !isEqual(nodeA: prevNodes[prevNodesLength - trailingMatch], nodeB: nextNodes[nextNodesLength - trailingMatch]) {
        trailingMatch -= 1
        break
      }
    }

    let from = leadingMatch
    let to = prevNodesLength - trailingMatch
    let nodesForReplacement = nextNodes[leadingMatch..<(nextNodesLength - trailingMatch)]

    let hasChanges = from != to || nodesForReplacement.count > 0
    return hasChanges ? (from, to, Array(nodesForReplacement)) : nil
  }

  func isEqual(nodeA: Node, nodeB: Node) -> Bool {
    // Only checking for code higlight nodes and linebreaks. If it's regular text node
    // returning false so that it's transformed into code highlight node
    if let nodeACodeHighlight = nodeA as? CodeHighlightNode,
       let nodeBCodeHighlight = nodeB as? CodeHighlightNode {
      return nodeACodeHighlight.getTextPart() == nodeBCodeHighlight.getTextPart() && nodeACodeHighlight.highlightType == nodeBCodeHighlight.highlightType
    }

    if isLineBreakNode(nodeA) && isLineBreakNode(nodeB) {
      return true
    }

    return false
  }
}
