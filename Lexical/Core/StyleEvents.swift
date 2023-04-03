/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

public func updateTextFormat(type: TextFormatType, editor: Editor) throws {
  guard getActiveEditor() != nil else {
    throw LexicalError.invariantViolation("Must have editor")
  }
  guard let selection = getSelection() else {
    return
  }
  
  try selection.formatText(formatType: type)
}

public func formatParagraph(editor: Editor) throws {
  guard getActiveEditor() != nil else {
    throw LexicalError.invariantViolation("Must have editor")
  }
  guard let selection = getSelection() else {
    return
  }
  
  try wrapLeafNodesInElements(selection: selection, createElement: {
    createParagraphNode()
  }, wrappingElement: nil)
}

public func formatLargeHeading(editor: Editor) throws {
  guard getActiveEditor() != nil else {
    throw LexicalError.invariantViolation("Must have editor")
  }
  guard let selection = getSelection() else {
    return
  }
  
  try wrapLeafNodesInElements(selection: selection, createElement: {
    createHeadingNode(headingTag: .h1)
  }, wrappingElement: nil)
}

public func formatSmallHeading(editor: Editor) throws {
  guard getActiveEditor() != nil else {
    throw LexicalError.invariantViolation("Must have editor")
  }
  guard let selection = getSelection() else {
    return
  }
  
  try wrapLeafNodesInElements(selection: selection, createElement: {
    createHeadingNode(headingTag: .h2)
  }, wrappingElement: nil)
}

public func formatQuote(editor: Editor) throws {
  guard getActiveEditor() != nil else {
    throw LexicalError.invariantViolation("Must have editor")
  }
  guard let selection = getSelection() else {
    return
  }
  
  try wrapLeafNodesInElements(selection: selection, createElement: {
    createQuoteNode()
  }, wrappingElement: nil)
}

public func formatCode(editor: Editor) throws {
  guard getActiveEditor() != nil else {
    throw LexicalError.invariantViolation("Must have editor")
  }
  guard let selection = getSelection() else {
    return
  }
  
  if selection.isCollapsed() {
    try wrapLeafNodesInElements(selection: selection, createElement: {
      createCodeNode()
    }, wrappingElement: nil)
  } else {
    let textContent = try selection.getTextContent()
    let codeNode = createCodeNode()
    _ = try selection.insertNodes(nodes: [codeNode], selectStart: false)
    try selection.insertRawText(text: textContent)
  }
}

