/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import SwiftSoup

public func generateHTMLFromNodes(editor: Editor, selection: BaseSelection?) throws -> String {
  let container = SwiftSoup.Element(Tag("div"), "")
  guard let root = getRoot() else {
    return ""
  }
  let topLevelChildren = root.getChildren()

  for topLevelNode in topLevelChildren {
    _ = try appendNodesToHTML(editor: editor, currentNode: topLevelNode, parentElement: container, selection: selection)
  }

  return try container.html()
}

private func appendNodesToHTML(editor: Editor, currentNode: Lexical.Node, parentElement: SwiftSoup.Element, selection: BaseSelection?) throws -> Bool {
  var shouldInclude = selection != nil ? try currentNode.isSelected() : true
  let shouldExclude: Bool
  if let currentNode = currentNode as? Lexical.ElementNode, currentNode.excludeFromCopy(destination: .html) {
    shouldExclude = true
  } else {
    shouldExclude = false
  }
  let target = currentNode

  if let selection {
    var clone = try cloneWithProperties(node: currentNode)
    guard let selection = selection as? RangeSelection else {
      throw LexicalError.internal("TODO: support selections that are not range selection")
    }
    if let cloneAsText = clone as? Lexical.TextNode {
      clone = try sliceSelectedTextNodeContent(selection: selection, textNode: cloneAsText)
    }
  }

  let children: [Lexical.Node]
  if let target = target as? Lexical.ElementNode {
    children = target.getChildren()
  } else {
    children = []
  }

  guard let target = target as? NodeHTMLSupport else {
    return false
  }

  let (after, element) = try target.exportDOM(editor: editor)

  guard let element else { return false }

  let fragmentElement = SwiftSoup.Element(Tag("div"), "")
  for childNode in children {
    let shouldIncludeChild = try appendNodesToHTML(editor: editor, currentNode: childNode, parentElement: fragmentElement, selection: selection)
    if !shouldInclude, let currentNode = currentNode as? Lexical.ElementNode, shouldIncludeChild, currentNode.extractWithChild(child: childNode, selection: selection, destination: .html) {
      shouldInclude = true
    }
  }

  if shouldInclude && !shouldExclude {
    for fragmentChild in fragmentElement.children() {
      try element.appendChild(fragmentChild)
    }
    try parentElement.appendChild(element)

    if let after {
      if let newElement = try after(target, element) {
        try element.replaceWith(newElement)
      }
    }
  } else {
    for fragmentChild in fragmentElement.children() {
      try parentElement.appendChild(fragmentChild)
    }
  }

  return shouldInclude
}
