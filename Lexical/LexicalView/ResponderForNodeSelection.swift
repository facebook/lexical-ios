/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import UIKit

class ResponderForNodeSelection: UIResponder, UIKeyInput {

  private weak var editor: Editor?
  private weak var textStorage: TextStorage?

  init(editor: Editor, textStorage: TextStorage) {
    self.editor = editor
    self.textStorage = textStorage
  }

  var hasText: Bool {
    true // if this class is being used, _something_ is selected from a Lexical point of view!
  }

  func insertText(_ text: String) {
    guard let editor, let textStorage else {
      return
    }
    textStorage.mode = TextStorageEditingMode.controllerMode
    editor.dispatchCommand(type: .insertText, payload: text)
    textStorage.mode = TextStorageEditingMode.none
  }

  func deleteBackward() {
    editor?.dispatchCommand(type: .deleteCharacter, payload: true)
  }
}
