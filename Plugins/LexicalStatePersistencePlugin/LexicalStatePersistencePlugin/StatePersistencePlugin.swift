/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical

open class StatePersistencePlugin: Plugin {
  weak var editor: Editor?
  private var unregister: (() -> Void)?

  public func setUp(editor: Editor) {
    self.editor = editor
  }

  public func tearDown() {
    unregister?()
  }

  public init() {}

  public func generateStateJsonString() throws -> String {
    guard let editor = getActiveEditor() else {
      throw LexicalError.invariantViolation("Could not get editor")
    }

    guard let rootNode = editor.getEditorState().getRootNode() else {
      throw LexicalError.invariantViolation("Could not get RootNode")
    }

    let persistedEditorState = SerializedEditorState(rootNode: rootNode)
    let encodedData = try JSONEncoder().encode(persistedEditorState)
    guard let jsonString = String(data: encodedData, encoding: .utf8) else { return "" }
    return jsonString
  }

  public func replaceTextWithJsonState(state: String) throws {
    guard let stateData = state.data(using: .utf8) else {
      throw LexicalError.internal("Could not generate data from string JSON state")
    }
    do {
      let decodedEditorState = try JSONDecoder().decode(SerializedEditorState.self, from: stateData)

      guard let rootNode = decodedEditorState.rootNode else {
        throw LexicalError.internal("Failed to decode RootNode")
      }

      guard let editor = getActiveEditor() else {
        throw LexicalError.internal("Could not get editor")
      }

      if !editor.isTextViewEmpty() {
        try editor.clearEditor()
      }

      guard let selection = try getSelection() as? RangeSelection else {
        throw LexicalError.internal("Could not get selection; TODO: support non-range-selections here")
      }

      _ = try insertGeneratedNodes(editor: editor, nodes: rootNode.getChildren(), selection: selection)
    } catch {
      throw LexicalError.internal("Error restoring text. Protecting selection")
    }
  }
}
