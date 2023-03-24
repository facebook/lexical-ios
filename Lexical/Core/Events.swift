/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import UIKit
// This function is analagous to the parts of onBeforeInput() where inputType == 'insertText'.
// However, on iOS, we are assuming that `shouldPreventDefaultAndInsertText()` has already been checked
// before calling onInsertTextFromUITextView().

internal func onInsertTextFromUITextView(text: String, editor: Editor, updateMode: UpdateBehaviourModificationMode = UpdateBehaviourModificationMode()) throws {
  try editor.updateWithCustomBehaviour(mode: updateMode) {
    guard let selection = getSelection() else {
      editor.log(.UITextView, .error, "Expected a selection here")
      return
    }

    if let markedTextOperation = updateMode.markedTextOperation, markedTextOperation.createMarkedText == true {
      // Here we special case STARTING or UPDATING a marked text operation.
      try selection.applySelectionRange(markedTextOperation.selectionRangeToReplace, affinity: .forward)
    } else if let markedRange = editor.getNativeSelection().markedRange {
      // Here we special case ENDING a marked text operation by replacing all the marked text with the incoming text.
      // This is usually used by hardware keyboards e.g. when typing e-acute. Software keyboards such as Japanese
      // do not seem to use this way of ending marked text.
      try selection.applySelectionRange(markedRange, affinity: .forward)
    }

    if text == "\n" || text == "\u{2029}" {
      try selection.insertParagraph()
    } else if text == "\u{2028}" {
      try selection.insertLineBreak(selectStart: false)
    } else {
      try selection.insertText(text)
    }
  }
}

internal func onInsertLineBreakFromUITextView(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("onDeleteBackwardsFromUITextView() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }
    try selection.insertLineBreak(selectStart: false)
  }
}

internal func onInsertParagraphFromUITextView(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("onInsertParagraphFromUITextView() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }
    try selection.insertParagraph()
  }
}

internal func onRemoveTextFromUITextView(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("onRemoveTextFromUITextView() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }
    try selection.removeText()
  }

  editor.frontend?.showPlaceholderText()
}

internal func onDeleteBackwardsFromUITextView(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("onDeleteBackwardsFromUITextView() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }

    try selection.deleteCharacter(isBackwards: true)
  }

  editor.frontend?.showPlaceholderText()
}

internal func onDeleteWordFromUITextView(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("onDeleteWordFromUITextView() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }

    try selection.deleteWord(isBackwards: true)
  }

  editor.frontend?.showPlaceholderText()
}

internal func onDeleteLineFromUITextView(editor: Editor) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("onDeleteLineFromUITextView() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }

    try selection.deleteLine(isBackwards: true)
  }

  editor.frontend?.showPlaceholderText()
}

internal func onFormatTextFromUITextView(editor: Editor, type: TextFormatType) throws {
  try updateTextFormat(type: type, editor: editor)
}

internal func onCopyFromUITextView(editor: Editor, pasteboard: UIPasteboard) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("onCopyFromUITextView() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }
    try setPasteboard(selection: selection, pasteboard: pasteboard)
  }
}

internal func onCutFromUITextView(editor: Editor, pasteboard: UIPasteboard) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("onCutFromUITextView() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }
    try setPasteboard(selection: selection, pasteboard: pasteboard)
    try selection.removeText()
  }

  editor.frontend?.showPlaceholderText()
}

internal func onPasteFromUITextView(editor: Editor, pasteboard: UIPasteboard) throws {
  guard getActiveEditor() == nil else {
    throw LexicalError.invariantViolation("onPasteFromUITextView() should not be called from inside a read/edit block")
  }

  try editor.update {
    guard let selection = getSelection() else {
      return
    }

    try insertDataTransferForRichText(selection: selection, pasteboard: pasteboard)
  }

  editor.frontend?.showPlaceholderText()
}

public func shouldInsertTextAfterOrBeforeTextNode(selection: RangeSelection, node: TextNode) -> Bool {
  var shouldInsertTextBefore = false
  var shouldInsertTextAfter = false

  if node.isSegmented() {
    return true
  }

  if !selection.isCollapsed() {
    return true
  }

  let offset = selection.anchor.offset

  shouldInsertTextBefore = offset == 0 && checkIfTokenOrCanTextBeInserted(node: node)

  shouldInsertTextAfter = node.getTextContentSize() == offset &&
    checkIfTokenOrCanTextBeInserted(node: node)

  return shouldInsertTextBefore || shouldInsertTextAfter
}

func checkIfTokenOrCanTextBeInserted(node: TextNode) -> Bool {
  let isToken = node.isToken()
  let parent = node.getParent()

  if let parent = parent {
    return !parent.canInsertTextBefore() || !node.canInsertTextBefore() || isToken
  }

  return !node.canInsertTextBefore() || isToken
}

internal func onSelectionChange(editor: Editor) {
  do {
    try editor.updateWithCustomBehaviour(mode: UpdateBehaviourModificationMode(suppressReconcilingSelection: true, suppressSanityCheck: true)) {
      let nativeSelection = editor.getNativeSelection()
      guard let lexicalSelection = getSelection() else {
        return
      }

      try lexicalSelection.applyNativeSelection(nativeSelection)

      switch lexicalSelection.anchor.type {
      case .text:
        guard let anchorNode = try lexicalSelection.anchor.getNode() as? TextNode else { break }
        lexicalSelection.format = anchorNode.getFormat()
      case .element:
        lexicalSelection.format = TextFormat()
      default:
        break
      }
      editor.dispatchCommand(type: .selectionChange, payload: nil)
    }
  } catch {
    // log error "change selection: failed to update lexical selection"
  }
}

public func registerRichText(editor: Editor) {

  _ = editor.registerCommand(type: .insertLineBreak, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      try onInsertLineBreakFromUITextView(editor: editor)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })

  _ = editor.registerCommand(type: .deleteCharacter, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      try onDeleteBackwardsFromUITextView(editor: editor)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })

  _ = editor.registerCommand(type: .deleteWord, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      try onDeleteWordFromUITextView(editor: editor)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })

  _ = editor.registerCommand(type: .deleteLine, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      try onDeleteLineFromUITextView(editor: editor)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })

  _ = editor.registerCommand(type: .insertText, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      guard let text = payload as? String else {
        editor.log(.TextView, .warning, "insertText missing payload")
        return false
      }

      try onInsertTextFromUITextView(text: text, editor: editor)
      return true
    } catch {
      editor.log(.TextView, .error, "Exception in insertText; \(String(describing: error))")
    }
    return true
  })

  _ = editor.registerCommand(type: .insertParagraph, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      try onInsertParagraphFromUITextView(editor: editor)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })

  _ = editor.registerCommand(type: .removeText, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      try onRemoveTextFromUITextView(editor: editor)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })

  _ = editor.registerCommand(type: .formatText, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      guard let text = payload as? TextFormatType else { return false }

      try onFormatTextFromUITextView(editor: editor, type: text)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })

  _ = editor.registerCommand(type: .copy, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      guard let text = payload as? UIPasteboard else { return false }

      try onCopyFromUITextView(editor: editor, pasteboard: text)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })

  _ = editor.registerCommand(type: .cut, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      guard let text = payload as? UIPasteboard else { return false }

      try onCutFromUITextView(editor: editor, pasteboard: text)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })

  _ = editor.registerCommand(type: .paste, listener: { [weak editor] payload in
    guard let editor = editor else { return false }
    do {
      guard let text = payload as? UIPasteboard else { return false }

      try onPasteFromUITextView(editor: editor, pasteboard: text)
      return true
    } catch {
      print("\(error)")
    }
    return true
  })
}
