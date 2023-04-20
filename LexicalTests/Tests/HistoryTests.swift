/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import Lexical
import XCTest

class HistoryTests: XCTestCase {

  var view: LexicalView?
  var editor: Editor {
    get {
      guard let editor = view?.editor else {
        XCTFail("Editor unexpectedly nil")
        fatalError()
      }
      return editor
    }
  }

  override func setUp() {
    view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    addListeners()
  }

  private func addListeners() {
    guard let view else { XCTFail(); return }

    _ = view.editor.registerUpdateListener(listener: { (activeEditorState, previousEditorState, dirtyNodes) in
      view.editorHistory.applyChange(
        editorState: activeEditorState,
        prevEditorState: previousEditorState,
        dirtyNodes: dirtyNodes)
    })

    _ = view.editor.registerCommand(type: .undo, listener: { payload in
      view.editorHistory.applyCommand(type: .undo)
      return true
    })

    _ = view.editor.registerCommand(type: .redo, listener: { payload in
      view.editorHistory.applyCommand(type: .redo)
      return true
    })
  }

  override func tearDown() {
    view = nil
  }

  func testGetDirtyNodes() throws {
    try editor.update {
      guard let editorState = getActiveEditorState(), let rootNode = editorState.getRootNode() else {
        XCTFail("should have editor state")
        return
      }
      let textNode = TextNode()
      try textNode.setText("hello ")

      let textNode2 = TextNode()
      try textNode2.setText("world")

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])
      try paragraphNode.append([textNode2])

      try rootNode.append([paragraphNode])

      XCTAssertEqual(editor.dirtyNodes.count, 5)
      XCTAssert(editor.dirtyNodes[textNode.key] != nil)
    }
  }

  func testGetChangeType() throws {
    try editor.update {
      guard let editorState = getActiveEditorState(), let rootNode = editorState.getRootNode() else {
        XCTFail("should have editor state")
        return
      }
      guard let pendingEditorState = editor.testing_getPendingEditorState() else {
        XCTFail("should have editor state")
        return
      }

      let changeType = try getChangeType(prevEditorState: editorState, nextEditorState: pendingEditorState, dirtyLeavesSet: editor.dirtyNodes, isComposing: false)

      XCTAssertNotNil(editorState)
      XCTAssertEqual(changeType, .other)

      let textNode = TextNode()
      try textNode.setText("é")

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])
      try rootNode.append([paragraphNode])

      let changeType1 = try getChangeType(prevEditorState: editorState, nextEditorState: pendingEditorState, dirtyLeavesSet: editor.dirtyNodes, isComposing: true)
      XCTAssertEqual(changeType1, .composingCharacter)
    }
  }

  func testApplyHistory() throws {
    guard let view else { XCTFail(); return }

    XCTAssertEqual(view.textStorage.string, "", "Text storage should be empty")
    view.textView.insertText("A")
    XCTAssertEqual(view.textStorage.string, "A", "Text storage should contain A")
    view.editor.dispatchCommand(type: .undo)
    XCTAssertEqual(view.textStorage.string, "", "Text storage should be empty")
  }
}
