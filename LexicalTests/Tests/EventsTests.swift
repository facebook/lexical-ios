// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

@testable import Lexical
import XCTest

class EventsTests: XCTestCase {
  func testFormatLargeHeading() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      guard let editorState = editor.testing_getPendingEditorState(), let rootNode = editorState.getRootNode() else {
        XCTFail("Failed to get the root node.")
        return
      }

      let paragraphNode = ParagraphNode() // key 1
      let textNode = TextNode() // key 2
      let key = textNode.key
      try textNode.setText("Testing formatting paragraph style")

      try paragraphNode.append([textNode])
      try rootNode.append([paragraphNode])

      editorState.selection = RangeSelection(
        anchor: Point(key: key, offset: 0, type: .text),
        focus: Point(key: key, offset: 0, type: .text),
        format: TextFormat())
    }

    try formatLargeHeading(editor: editor)
    try editor.read {
      let editorState = editor.getEditorState()
      guard let rootNode = editorState.getRootNode() else {
        XCTFail("Failed to get the root node.")
        return
      }

      XCTAssertEqual(rootNode.children.count, 2)
      XCTAssertEqual(rootNode.children[0], "0")
      XCTAssertEqual(rootNode.children[1], "3")

      if let headingNode = getNodeByKey(key: "3") as? HeadingNode {
        XCTAssertEqual(headingNode.parent, kRootNodeKey)
        XCTAssertEqual(headingNode.children.count, 1)
        XCTAssertEqual(headingNode.children[0], "2")
        XCTAssertEqual(headingNode.getTag(), HeadingTagType.h1)
      }
    }

    try formatParagraph(editor: editor)
    try editor.read {
      let editorState = editor.getEditorState()
      guard let rootNode = editorState.getRootNode() else {
        XCTFail("Failed to get the root node.")
        return
      }

      XCTAssertEqual(rootNode.children.count, 2)
      XCTAssertEqual(rootNode.children[0], "0")
      XCTAssertEqual(rootNode.children[1], "4")

      if let paragraphNode = getNodeByKey(key: "4") as? ParagraphNode {
        XCTAssertEqual(paragraphNode.parent, kRootNodeKey)
        XCTAssertEqual(paragraphNode.children.count, 1)
        XCTAssertEqual(paragraphNode.children[0], "2")
      }
    }

    try formatSmallHeading(editor: editor)
    try editor.read {
      let editorState = editor.getEditorState()
      guard let rootNode = editorState.getRootNode() else {
        XCTFail("Failed to get the root node.")
        return
      }

      XCTAssertEqual(rootNode.children.count, 2)
      XCTAssertEqual(rootNode.children[0], "0")
      XCTAssertEqual(rootNode.children[1], "5")

      if let headingNode = getNodeByKey(key: "5") as? HeadingNode {
        XCTAssertEqual(headingNode.parent, kRootNodeKey)
        XCTAssertEqual(headingNode.children.count, 1)
        XCTAssertEqual(headingNode.children[0], "2")
        XCTAssertEqual(headingNode.getTag(), HeadingTagType.h2)
      }
    }
  }

  func testFormatQuote() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      guard let editorState = editor.testing_getPendingEditorState(), let rootNode = editorState.getRootNode() else {
        XCTFail("Failed to get the root node.")
        return
      }

      let paragraphNode = ParagraphNode() // key 1
      let textNode = TextNode() // key 2
      let key = textNode.key
      try textNode.setText("Testing formatting paragraph style")

      try paragraphNode.append([textNode])
      try rootNode.append([paragraphNode])

      editorState.selection = RangeSelection(
        anchor: Point(key: key, offset: 0, type: .text),
        focus: Point(key: key, offset: 0, type: .text),
        format: TextFormat())
    }

    try formatQuote(editor: editor)
    try editor.read {
      let editorState = editor.getEditorState()
      guard let rootNode = editorState.getRootNode() else {
        XCTFail("Failed to get the root node.")
        return
      }

      XCTAssertEqual(rootNode.children.count, 2)
      XCTAssertEqual(rootNode.children[0], "0")
      XCTAssertEqual(rootNode.children[1], "3")

      if let headingNode = getNodeByKey(key: "3") as? QuoteNode {
        XCTAssertEqual(headingNode.parent, kRootNodeKey)
        XCTAssertEqual(headingNode.children.count, 1)
        XCTAssertEqual(headingNode.children[0], "2")
      }
    }
  }
}
