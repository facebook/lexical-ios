/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import LexicalLinkPlugin
import UIKit

struct LinkMatcherResult {
  let index: Int
  let length: Int
  let text: String
  let url: String
}

struct LinkMatcher {
  var index: Int
  var text: String
  var url: String
  var range: NSRange
}

open class AutoLinkPlugin: Plugin {

  public init() {}

  var editor: Editor?

  public func setUp(editor: Editor) {
    self.editor = editor
    do {
      try editor.registerNode(nodeType: NodeType.autoLink, class: AutoLinkNode.self)
      _ = editor.addNodeTransform(nodeType: NodeType.text, transform: { [weak self] in
        guard let strongSelf = self else { return }

        try strongSelf.transform($0)
      })

      _ = editor.addNodeTransform(nodeType: NodeType.autoLink, transform: { [weak self] linkNode in
        guard let strongSelf = self, let linkNode = linkNode as? AutoLinkNode else { return }

        try strongSelf.handleLinkEdit(linkNode: linkNode)
      })
    } catch {
      print("\(error)")
    }
  }

  public func tearDown() {
  }

  public func isAutoLinkNode(_ node: Node?) -> Bool {
    node is AutoLinkNode
  }

  public func createAutoLinkNode(url: String) -> AutoLinkNode {
    AutoLinkNode(url: url, key: nil)
  }

  func isPreviousNodeValid(node: Node) -> Bool {
    var previousNode = node.getPreviousSibling()

    if let elementNode = previousNode as? ElementNode {
      previousNode = elementNode.getLastDescendant()
    }

    if let textNode = previousNode as? TextNode {
      let text = textNode.getTextContent()
      let endIndex = text.index(before: text.endIndex)
      if String(text[endIndex]) == " " {
        return true
      }
    }

    return previousNode == nil || isLineBreakNode(previousNode)
  }

  func isNextNodeValid(node: Node) -> Bool {
    var nextNode = node.getNextSibling()

    if let elementNode = nextNode as? ElementNode {
      nextNode = elementNode.getFirstDescendant()
    }

    if let textNode = nextNode as? TextNode {
      let text = textNode.getTextContent()
      if String(text[text.startIndex]) == " " {
        return true
      }
    }

    return nextNode == nil || isLineBreakNode(nextNode)
  }

  @discardableResult
  func replaceWithChildren(node: ElementNode) throws -> [Node] {
    let children = node.getChildren()

    for child in children.reversed() {
      try node.insertAfter(nodeToInsert: child)
    }

    try node.remove()
    return children.map { child in
      child.getLatest()
    }
  }

  // MARK: - Private

  private func transform(_ node: Node) throws {
    guard
      let node = node as? TextNode,
      let parent = node.getParent()
    else { return }

    if let parent = parent as? AutoLinkNode {
      try handleLinkEdit(linkNode: parent)
    } else if !(parent is LinkNode) {
      if node.isSimpleText() {
        try handleLinkCreation(node: node)
      }

      try handleBadNeighbors(textNode: node)
    }
  }

  private func findFirstMatch(text: String) -> [LinkMatcher] {
    let emailMatcher = #"^\S+@\S+\.\S+$"#
    let urlMatcher = "((?:http|https)://)?(?:www\\.)?[\\w\\d\\-_]+\\.\\w{2,3}(\\.\\w{2})?(/(?<=/)(?:[\\w\\d\\-./_]+)?)?"
    var linkMatcher = [LinkMatcher]()

    let splitArray = text.split(separator: " ")
    // find url
    for (index, subString) in splitArray.enumerated() {
      let predicate = NSPredicate(format: "SELF MATCHES %@", argumentArray: [urlMatcher])
      if predicate.evaluate(with: String(subString)) {
        var newURLString = String(subString)
        if !newURLString.hasPrefix("https://") || !newURLString.hasPrefix("http://") {
          newURLString = "https://" + newURLString
        }

        let newNSRange = (text as NSString).range(of: String(subString))

        linkMatcher.append(LinkMatcher(index: index, text: String(subString), url: newURLString, range: newNSRange))
      }

      // find email
      let result = subString.range(of: emailMatcher, options: [.regularExpression], range: nil, locale: nil)
      if result != nil {
        let urlString = "mailto:" + String(subString)
        let newNSRange = (text as NSString).range(of: String(subString))

        linkMatcher.append(LinkMatcher(index: index, text: String(subString), url: urlString, range: newNSRange))
      }
    }

    return linkMatcher
  }

  private func handleLinkCreation(node: TextNode) throws {
    let nodeText = node.getTextContent()
    let nodeTextLength = nodeText.lengthAsNSString()
    let text = nodeText
    var textOffset = 0
    var lastNode = node
    let matches = findFirstMatch(text: text)
    if matches.count == 0 {
      return
    }

    for match in matches {
      let matchOffset = match.range.location
      let offset = textOffset + matchOffset
      let matchLength = match.range.length

      // Previous node is valid if any of:
      // 1. Space before same node
      // 2. Space in previous simple text node
      // 3. Previous node is LineBreakNode
      let contentBeforeMatchIsValid: Bool

      if offset > 0 {
        let index = nodeText.index(nodeText.startIndex, offsetBy: offset)
        let beforeIndex = nodeText.index(before: index)
        contentBeforeMatchIsValid = nodeText[beforeIndex..<index] == " "
      } else {
        contentBeforeMatchIsValid = isPreviousNodeValid(node: node)
      }

      // Next node is valid if any of:
      // 1. Space after same node
      // 2. Space in next simple text node
      // 3. Next node is LineBreakNode
      let contentAfterMatchIsValid: Bool

      if offset + matchLength < nodeTextLength {
        let index = nodeText.index(nodeText.startIndex, offsetBy: offset + matchLength)
        let afterIndex = nodeText.index(after: index)
        contentAfterMatchIsValid = nodeText[index..<afterIndex] == " "
      } else {
        contentAfterMatchIsValid = isNextNodeValid(node: node)
      }

      if contentAfterMatchIsValid && contentBeforeMatchIsValid {
        var middleNode: Node?

        if matchOffset == 0 {
          let nodes = try lastNode.splitText(splitOffsets: [matchLength])
          if nodes.count > 1 {
            middleNode = nodes[0]
            lastNode = nodes.count == 2 ? nodes[1] : lastNode
          }
        } else {
          let nodes = try lastNode.splitText(splitOffsets: [matchOffset, matchOffset + matchLength])
          if nodes.count >= 2 {
            // ignore the first node
            middleNode = nodes[1]
            lastNode = nodes.count == 3 ? nodes[2] : lastNode
          }
        }

        let linkNode = createAutoLinkNode(url: match.url)
        try linkNode.append([createTextNode(text: match.text)])
        try middleNode?.replace(replaceWith: linkNode)
      }

      textOffset += (matchOffset + matchLength)
    }
  }

  private func handleLinkEdit(linkNode: AutoLinkNode) throws {
    // Check children are simple text
    let children = linkNode.getChildren()

    for child in children {
      if !(child is TextNode) {
        try replaceWithChildren(node: linkNode)
        return
      }

      if let child = child as? TextNode, !child.isSimpleText() {
        try replaceWithChildren(node: linkNode)
        return
      }
    }

    // Check text content fully matches
    let text = linkNode.getTextContent()
    let matches = findFirstMatch(text: text)

    if matches.count == 0 || (matches.count >= 1 && matches[0].text != text) {
      try replaceWithChildren(node: linkNode)
      return
    }

    // Check neighbors
    if !isPreviousNodeValid(node: linkNode) || !isNextNodeValid(node: linkNode) {
      try replaceWithChildren(node: linkNode)
      return
    }

    let url = linkNode.getURL()

    if matches.count >= 1, matches[0].url != url {
      try linkNode.setURL(matches[0].url)
    }
  }

  // Bad neighbours are edits in neighbor nodes that make AutoLinks incompatible.
  // Given the creation preconditions, these can only be simple text nodes.
  private func handleBadNeighbors(textNode: TextNode) throws {
    let previousSibling = textNode.getPreviousSibling()
    let nextSibling = textNode.getNextSibling()
    let text = textNode.getTextContent()

    let startChar = String(text[text.startIndex])
    if let previousSibling = previousSibling as? AutoLinkNode, startChar != " " {
      try replaceWithChildren(node: previousSibling)
    }

    let endIndex = text.index(before: text.endIndex)
    let lastChar = String(text[endIndex])
    if let nextSibling = nextSibling as? AutoLinkNode, lastChar != " " {
      try replaceWithChildren(node: nextSibling)
    }
  }
}
