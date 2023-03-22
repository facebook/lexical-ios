// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

@testable import Lexical
import XCTest

class EditorStateTests: XCTestCase {

  func testReadReturnsCorrectState() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      createExampleNodeTree()

      let textNode = TextNode()
      try textNode.setText("hello world")
    }

    try editor.getEditorState().read {
      guard let activeEditorState = getActiveEditorState() else {
        XCTFail("Editor State is unexpectedly nil")
        return
      }

      guard let node = activeEditorState.getRootNode()?.getFirstChild() as? ParagraphNode else {
        XCTFail("Node is unexpectedly nil")
        return
      }

      guard let textNode = node.getFirstChild() as? TextNode else {
        XCTFail("Text node is unexpectedly nil")
        return
      }

      XCTAssertEqual(textNode.getTextPart(), "hello ")
    }
  }
}
