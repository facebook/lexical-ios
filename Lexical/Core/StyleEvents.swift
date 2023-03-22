// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

public func updateTextFormat(type: TextFormatType, editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("updateTextFormat() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }

    try selection.formatText(formatType: type)
  }

  try editor.update {}
}

public func formatParagraph(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("formatParagraph() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }

    try wrapLeafNodesInElements(selection: selection, createElement: {
      createParagraphNode()
    }, wrappingElement: nil)
  }
}

public func formatLargeHeading(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("formatLargeHeading() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }

    try wrapLeafNodesInElements(selection: selection, createElement: {
      createHeadingNode(headingTag: .h1)
    }, wrappingElement: nil)
  }
}

public func formatSmallHeading(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("formatSmallHeading() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }

    try wrapLeafNodesInElements(selection: selection, createElement: {
      createHeadingNode(headingTag: .h2)
    }, wrappingElement: nil)
  }
}

public func formatQuote(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("formatQuote() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }

    try wrapLeafNodesInElements(selection: selection, createElement: {
      createQuoteNode()
    }, wrappingElement: nil)
  }
}

public func formatCode(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("formatCode() should not be called from inside a read/edit block")
  }

  try editor.update {
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
}
